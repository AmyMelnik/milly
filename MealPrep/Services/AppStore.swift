import Foundation
import Observation

/// App state: preferences, saved plans, and the services.
@MainActor
@Observable
final class AppStore {
    var preferences = Preferences()
    var plans: [SavedPlan] = []

    /// True while Claude is revising or regenerating an existing plan.
    var isRevising = false
    /// Live progress of the current Claude request (new plan, revision or regeneration).
    var progress: PlanProgress?
    var errorMessage: String?

    private(set) var anthropicKey = Keychain.get(.anthropicKey) ?? ""

    let picnic = PicnicSession()
    let shopping = ShoppingList()

    var latestPlan: SavedPlan? { plans.first }

    /// The plan to feature on home: the one whose groceries were ordered most recently,
    /// or the newest plan if nothing has been ordered yet.
    var featuredPlan: SavedPlan? {
        plans.filter { $0.orderedAt != nil }.max { $0.orderedAt! < $1.orderedAt! } ?? plans.first
    }

    func markOrdered(_ id: UUID) {
        guard let index = plans.firstIndex(where: { $0.id == id }) else { return }
        plans[index].orderedAt = .now
        save()
    }
    var hasAnthropicKey: Bool { !anthropicKey.isEmpty }

    /// Onboarding shows until it's finished, and again if the Claude key is removed.
    private(set) var onboardingComplete = UserDefaults.standard.bool(forKey: "onboarding.complete")
    var needsOnboarding: Bool {
        #if DEBUG
        // Lets the Simulator preview screens without real credentials. Not in release builds.
        if ProcessInfo.processInfo.arguments.contains("-PreviewSkipOnboarding") { return false }
        #endif
        return !onboardingComplete || !hasAnthropicKey
    }

    func completeOnboarding() {
        onboardingComplete = true
        UserDefaults.standard.set(true, forKey: "onboarding.complete")
    }

    init() { load() }

    func plan(_ id: UUID) -> SavedPlan? { plans.first { $0.id == id } }

    func setAnthropicKey(_ key: String) {
        anthropicKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        Keychain.set(anthropicKey, for: .anthropicKey)
    }

    private var planner: ClaudePlanner { ClaudePlanner(apiKey: anthropicKey) }

    private func report(_ p: PlanProgress) { progress = p }

    // MARK: Planning

    /// Generates a plan from `preferences`, saves it, and returns its id.
    func generate() async throws -> UUID {
        save()
        progress = PlanProgress()
        defer { progress = nil }
        let plan = try await planner.generate(preferences) { [weak self] in self?.report($0) }
        let saved = SavedPlan(preferences: preferences, plan: plan)
        plans.insert(saved, at: 0)
        save()
        return saved.id
    }

    /// Asks Claude to change part of a plan; everything else stays.
    func revise(_ id: UUID, instruction: String) async {
        guard let saved = plan(id) else { return }
        await run(id) { planner, report in
            try await planner.revise(saved.plan, prefs: saved.preferences, instruction: instruction, onProgress: report)
        }
    }

    /// A completely new plan from the same answers, replacing this one.
    func regenerate(_ id: UUID) async {
        guard let saved = plan(id) else { return }
        await run(id) { planner, report in
            try await planner.generate(saved.preferences, onProgress: report)
        }
    }

    /// Sends the cook's grocery edits to Claude so recipes and combos match the list again.
    func applyGroceryEdits(_ id: UUID) async {
        guard let saved = plan(id), let edits = saved.groceryEdits, !edits.isEmpty else { return }
        let instruction = """
        The cook edited the grocery list: \(edits.joined(separator: "; ")). \
        Update the components, combinations and cooking steps so they only use what's on the list now. \
        Where an ingredient was removed, replace it with something similar that fits the plan, and add that to the groceries.
        """
        await revise(id, instruction: instruction)
    }

    /// Asks Claude for swaps for one ingredient or module. Doesn't change the plan.
    func alternatives(_ id: UUID, for name: String, kind: String, exclude: [String]) async throws -> [ClaudePlanner.Alternative] {
        guard let saved = plan(id) else { return [] }
        return try await planner.alternatives(for: name, kind: kind, plan: saved.plan, prefs: saved.preferences, exclude: exclude)
    }

    /// Rebuilds the plan around the chosen swap.
    func replace(_ id: UUID, _ old: String, kind: String, with new: String) async {
        let instruction = "Replace the \(kind) \"\(old)\" with \"\(new)\". Update the components, combinations, cooking steps and groceries so everything uses \(new) instead, and keep the rest of the plan."
        await revise(id, instruction: instruction)
    }

    private func run(_ id: UUID,
                     _ work: (ClaudePlanner, @escaping ClaudePlanner.ProgressHandler) async throws -> GeneratedPlan) async {
        isRevising = true
        errorMessage = nil
        progress = PlanProgress()
        defer {
            isRevising = false
            progress = nil
        }
        do {
            let updated = try await work(planner) { [weak self] in self?.report($0) }
            guard let index = plans.firstIndex(where: { $0.id == id }) else { return }
            plans[index].plan = updated
            plans[index].revision = UUID()
            plans[index].groceryEdits = nil
            save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ id: UUID) {
        plans.removeAll { $0.id == id }
        save()
    }

    // MARK: Grocery edits (local, no Claude call)

    func updateGrocery(_ planID: UUID, _ item: GroceryItem) {
        guard let p = plans.firstIndex(where: { $0.id == planID }),
              let g = plans[p].plan.groceries.firstIndex(where: { $0.id == item.id }) else { return }
        let old = plans[p].plan.groceries[g]
        guard old != item else { return }
        plans[p].plan.groceries[g] = item
        if old.name.caseInsensitiveCompare(item.name) != .orderedSame {
            // A different ingredient changes the recipes, so remember it for "Update recipes".
            if item.picnicSearchTerm == old.picnicSearchTerm { plans[p].plan.groceries[g].picnicSearchTerm = item.name }
            recordEdit(p, "replaced \(old.name) with \(item.name)")
        } else if old.amount != item.amount {
            recordEdit(p, "changed \(item.name) to \(item.amount)")
        }
        plans[p].revision = UUID()
        save()
    }

    func removeGrocery(_ planID: UUID, _ itemID: String) {
        guard let p = plans.firstIndex(where: { $0.id == planID }),
              let g = plans[p].plan.groceries.firstIndex(where: { $0.id == itemID }) else { return }
        let removed = plans[p].plan.groceries.remove(at: g)
        recordEdit(p, "removed \(removed.name)")
        plans[p].revision = UUID()
        save()
    }

    func discardGroceryEdits(_ planID: UUID) {
        guard let p = plans.firstIndex(where: { $0.id == planID }) else { return }
        plans[p].groceryEdits = nil
        save()
    }

    private func recordEdit(_ planIndex: Int, _ edit: String) {
        var edits = plans[planIndex].groceryEdits ?? []
        edits.append(edit)
        plans[planIndex].groceryEdits = edits
    }

    // MARK: Persistence (a JSON file in Application Support)

    private struct Persisted: Codable {
        var preferences: Preferences
        var plans: [SavedPlan]
    }

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("mealprep-v2.json")
    }

    func save() {
        let state = Persisted(preferences: preferences, plans: plans)
        if let data = try? JSONEncoder().encode(state) {
            // Encrypted at rest whenever the iPhone is locked.
            try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
        preferences = state.preferences
        plans = state.plans
    }
}
