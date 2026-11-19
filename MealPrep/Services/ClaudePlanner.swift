import Foundation

/// Generates and revises modular meal-prep plans with the Claude API.
/// Swift has no official Anthropic SDK, so this calls the Messages API over HTTP,
/// streams the reply (so the app can show real progress) and uses structured outputs
/// so the result always decodes into `GeneratedPlan`.
struct ClaudePlanner {
    var apiKey: String

    static let model = "claude-opus-5-5"

    enum PlannerError: LocalizedError {
        case missingKey
        case invalidKey
        case http(Int, String)
        case refusal
        case truncated
        case empty
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case .missingKey: "Add your Anthropic API key in Settings first."
            case .invalidKey: "That key wasn't accepted. Check it and try again."
            case let .http(code, message): "Claude API error \(code): \(message)"
            case .refusal: "Claude declined to make this plan. Try rewording your notes."
            case .truncated: "The plan was too long and got cut off. Try fewer meals or modules."
            case .empty: "Claude returned an empty response."
            case let .decoding(detail): "Couldn't read the plan: \(detail)"
            }
        }
    }

    typealias ProgressHandler = @MainActor (PlanProgress) -> Void

    /// Checks a key without spending tokens: listing models is free.
    static func validate(key: String) async throws {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models?limit=1")!)
        request.timeoutInterval = 20
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: return
        case 401, 403: throw PlannerError.invalidKey
        default:
            let apiError = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            throw PlannerError.http(status, apiError?.error.message ?? "Couldn't reach Anthropic.")
        }
    }

    func generate(_ prefs: Preferences, onProgress: @escaping ProgressHandler) async throws -> GeneratedPlan {
        let expected = PlanProgress.Expected(
            components: prefs.proteins + prefs.carbs + prefs.vegetables + prefs.sauces,
            combinations: 7, steps: 8, groceries: 16)
        return try await send(userText: PlanPrompt.request(for: prefs), expected: expected, onProgress: onProgress)
    }

    /// Modular edit: keep the plan, change only what the instruction asks for.
    func revise(_ plan: GeneratedPlan, prefs: Preferences, instruction: String,
                onProgress: @escaping ProgressHandler) async throws -> GeneratedPlan {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let current = String(decoding: try encoder.encode(plan), as: UTF8.self)
        let text = """
        \(PlanPrompt.request(for: prefs))

        Here is the current plan:
        <current_plan>
        \(current)
        </current_plan>

        Revise it according to this request: \(instruction)

        Keep every component, combination and cooking step that the request does not affect. \
        Update combinations, cooking steps and groceries so they stay consistent with any changed components.
        """
        let expected = PlanProgress.Expected(
            components: max(1, plan.components.count), combinations: max(1, plan.combinations.count),
            steps: max(1, plan.cookingSteps.count), groceries: max(1, plan.groceries.count))
        return try await send(userText: text, expected: expected, onProgress: onProgress)
    }

    // MARK: Alternatives for one item

    struct Alternative: Decodable, Identifiable, Hashable {
        let name: String
        let why: String
        var id: String { name }
    }

    /// Suggests swaps for one ingredient or module without changing the plan.
    func alternatives(for itemName: String, kind: String, plan: GeneratedPlan, prefs: Preferences,
                      exclude: [String]) async throws -> [Alternative] {
        guard !apiKey.isEmpty else { throw PlannerError.missingKey }
        let others = plan.components.map { "\($0.name) (\($0.category.rawValue))" }.joined(separator: ", ")
        var lines = [
            "A home cook is meal prepping this plan: \(plan.title).",
            "Its modules: \(others).",
            "Diet: \(prefs.diet).",
            "They don't feel like the \(kind) \"\(itemName)\". Suggest 4 alternatives that fit the rest of the plan, are easy to buy at a Dutch supermarket and cook similarly.",
            "`name` is short (2 to 4 words, English). `why` is one short sentence on why it works (taste, texture or prep).",
        ]
        let avoid = (prefs.avoidTags + [prefs.avoid]).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !avoid.isEmpty { lines.append("Never suggest: \(avoid.joined(separator: ", ")).") }
        if !exclude.isEmpty { lines.append("Don't repeat these: \(exclude.joined(separator: ", ")).") }

        let schema = JSON.object([
            ("type", .string("object")),
            ("properties", .object([("alternatives", .object([
                ("type", .string("array")),
                ("items", .object([
                    ("type", .string("object")),
                    ("properties", .object([("name", .object([("type", .string("string"))])),
                                            ("why", .object([("type", .string("string"))]))])),
                    ("required", .array([.string("name"), .string("why")])),
                    ("additionalProperties", .bool(false)),
                ])),
            ]))])),
            ("required", .array([.string("alternatives")])),
            ("additionalProperties", .bool(false)),
        ])
        let body = JSON.object([
            ("model", .string(Self.model)),
            ("max_tokens", .int(4000)),
            ("messages", .array([.object([("role", .string("user")), ("content", .string(lines.joined(separator: "\n")))])])),
            ("output_config", .object([("effort", .string("low")),
                                       ("format", .object([("type", .string("json_schema")), ("schema", schema)]))])),
            ("fallbacks", .string("default")),
        ])

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = Data(body.rendered.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            if status == 401 { throw PlannerError.invalidKey }
            let apiError = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            throw PlannerError.http(status, apiError?.error.message ?? String(decoding: data, as: UTF8.self))
        }
        struct Reply: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
            let stop_reason: String?
        }
        struct Wrapper: Decodable { let alternatives: [Alternative] }
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        if reply.stop_reason == "refusal" { throw PlannerError.refusal }
        let json = reply.content.filter { $0.type == "text" }.compactMap(\.text).joined()
        guard let parsed = try? JSONDecoder().decode(Wrapper.self, from: Data(json.utf8)), !parsed.alternatives.isEmpty else {
            throw PlannerError.empty
        }
        return parsed.alternatives
    }

    // MARK: Streaming request

    private func send(userText: String, expected: PlanProgress.Expected,
                      onProgress: @escaping ProgressHandler) async throws -> GeneratedPlan {
        guard !apiKey.isEmpty else { throw PlannerError.missingKey }

        // Built as ordered JSON so the schema's property order (and so the order Claude
        // writes the plan in) is title → summary → components → combinations → steps → groceries.
        let body = JSON.object([
            ("model", .string(Self.model)),
            ("max_tokens", .int(32000)),
            ("stream", .bool(true)),
            ("system", .string(PlanPrompt.system)),
            ("messages", .array([.object([("role", .string("user")), ("content", .string(userText))])])),
            ("output_config", .object([
                ("effort", .string("medium")),
                ("format", .object([("type", .string("json_schema")), ("schema", PlanSchema.plan)])),
            ])),
            // If a safety classifier declines, the API retries on a fallback model in the same call.
            ("fallbacks", .string("default")),
        ])

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = Data(body.rendered.utf8)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            if status == 401 { throw PlannerError.invalidKey }
            let apiError = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            throw PlannerError.http(status, apiError?.error.message ?? String(decoding: data, as: UTF8.self))
        }

        let tracker = await MainActor.run { PlanProgress.Tracker(expected: expected) }
        await MainActor.run { onProgress(tracker.progress) }

        var text = ""
        var stopReason: String?
        var lastReported = 0

        // A heartbeat keeps the "thinking" phase moving while no text has arrived yet.
        let heartbeat = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                if Task.isCancelled { break }
                tracker.tick()
                onProgress(tracker.progress)
            }
        }
        defer { heartbeat.cancel() }

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let data = payload.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String else { continue }

            switch type {
            case "content_block_start":
                // On a server-side fallback, the fallback model starts the answer over.
                if (event["content_block"] as? [String: Any])?["type"] as? String == "fallback" {
                    text = ""
                }
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let piece = delta["text"] as? String {
                    text += piece
                    if text.count - lastReported > 120 {
                        lastReported = text.count
                        heartbeat.cancel()
                        let snapshot = text
                        await MainActor.run {
                            tracker.update(text: snapshot)
                            onProgress(tracker.progress)
                        }
                    }
                }
            case "message_delta":
                if let delta = event["delta"] as? [String: Any], let reason = delta["stop_reason"] as? String {
                    stopReason = reason
                }
            case "error":
                let message = ((event["error"] as? [String: Any])?["message"] as? String) ?? "Stream error"
                throw PlannerError.http(0, message)
            default:
                break
            }
        }

        switch stopReason {
        case "refusal": throw PlannerError.refusal
        case "max_tokens": throw PlannerError.truncated
        default: break
        }
        guard !text.isEmpty else { throw PlannerError.empty }

        await MainActor.run {
            tracker.finish()
            onProgress(tracker.progress)
        }

        do {
            return try JSONDecoder().decode(GeneratedPlan.self, from: Data(text.utf8))
        } catch {
            throw PlannerError.decoding(error.localizedDescription)
        }
    }

    private struct APIErrorBody: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }
}

// MARK: - Progress

/// What Claude is doing right now, in plain words, plus a 0…1 fraction for the bar.
struct PlanProgress: Equatable {
    enum Stage: Int, CaseIterable {
        case thinking, components, combinations, cooking, groceries, finishing

        var label: String {
            switch self {
            case .thinking: "Reading your answers"
            case .components: "Choosing what to batch-cook"
            case .combinations: "Pairing it into meals"
            case .cooking: "Planning the cooking order"
            case .groceries: "Writing your shopping list"
            case .finishing: "Plating up"
            }
        }
    }

    struct Expected {
        var components: Int
        var combinations: Int
        var steps: Int
        var groceries: Int
    }

    var stage: Stage = .thinking
    var fraction: Double = 0
    var detail = "Thinking about what works well together"

    /// Turns the partial JSON Claude has written so far into a stage and fraction.
    @MainActor
    final class Tracker {
        let expected: Expected
        private(set) var progress = PlanProgress()
        private let started = Date()

        init(expected: Expected) { self.expected = expected }

        /// Before any text arrives, Claude is thinking; creep slowly towards 15%.
        func tick() {
            guard progress.stage == .thinking else { return }
            let t = Date().timeIntervalSince(started)
            progress.fraction = 0.15 * (1 - exp(-t / 20))
            progress.detail = t < 8 ? "Thinking about what works well together" : "Balancing flavours, protein and prep time"
        }

        func update(text: String) {
            func count(_ needle: String, after key: String) -> Int {
                guard let range = text.range(of: key) else { return 0 }
                return text[range.upperBound...].components(separatedBy: needle).count - 1
            }
            func ramp(_ from: Double, _ to: Double, _ done: Int, _ total: Int) -> Double {
                from + (to - from) * min(1, Double(done) / Double(max(1, total)))
            }
            var p = PlanProgress()
            if text.contains("\"groceries\"") {
                let n = count("\"picnicSearchTerm\"", after: "\"groceries\"")
                p.stage = .groceries
                p.fraction = ramp(0.82, 0.97, n, expected.groceries)
                p.detail = n == 0 ? "Turning it into a Picnic list" : "\(n) item\(n == 1 ? "" : "s") on the list"
            } else if text.contains("\"cookingSteps\"") {
                let n = count("\"startMinute\"", after: "\"cookingSteps\"")
                p.stage = .cooking
                p.fraction = ramp(0.62, 0.82, n, expected.steps)
                p.detail = n == 0 ? "Figuring out what goes in the oven first" : "Step \(n) of the session"
            } else if text.contains("\"combinations\"") {
                let n = count("\"vibe\"", after: "\"combinations\"")
                p.stage = .combinations
                p.fraction = ramp(0.42, 0.62, n, expected.combinations)
                p.detail = n == 0 ? "Mixing and matching" : "\(n) meal idea\(n == 1 ? "" : "s") so far"
            } else if text.contains("\"components\"") {
                let n = count("\"category\"", after: "\"components\"")
                p.stage = .components
                p.fraction = ramp(0.18, 0.42, n, expected.components)
                p.detail = "\(n) of \(expected.components) modules picked"
            } else {
                p.stage = .components
                p.fraction = 0.17
                p.detail = "Naming your plan"
            }
            // Never move backwards.
            if p.fraction >= progress.fraction { progress = p }
        }

        func finish() {
            progress = PlanProgress(stage: .finishing, fraction: 1, detail: "Almost ready")
        }
    }
}

// MARK: - Ordered JSON

/// A tiny JSON value that keeps object keys in the order they're written.
/// (Dictionaries don't, and the schema's key order decides the order Claude writes in.)
indirect enum JSON {
    case string(String)
    case int(Int)
    case bool(Bool)
    case array([JSON])
    case object([(String, JSON)])

    var rendered: String {
        switch self {
        case let .string(s): Self.quote(s)
        case let .int(i): String(i)
        case let .bool(b): b ? "true" : "false"
        case let .array(items): "[" + items.map(\.rendered).joined(separator: ",") + "]"
        case let .object(pairs): "{" + pairs.map { Self.quote($0.0) + ":" + $0.1.rendered }.joined(separator: ",") + "}"
        }
    }

    private static func quote(_ s: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: s, options: .fragmentsAllowed)) ?? Data("\"\"".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - Prompt

enum PlanPrompt {
    static let system = """
    You plan modular meal prep for a home cook in the Netherlands who orders groceries from Picnic, \
    a Dutch online supermarket.

    Modular means: a small set of components (proteins, carbs, vegetables, sauces, optional toppings) \
    is batch-cooked in one session, then mixed and matched into different meals. The plan is not \
    tied to days of the week: show which combinations work well, and how to cook everything efficiently.

    Components:
    - Use exactly the requested number of proteins, carbs, vegetables and sauces. Toppings are optional, at most 2.
    - Pick components that work with each other, so almost any protein + carb + vegetable + sauce pairing tastes good.
    - `flavor` is a short hint of how it's seasoned, 2 to 4 words joined by " · " (e.g. "lemon · oregano · garlic").
    - `portions` is the total portions to cook. Within each category, portions add up to meals × people.
    - `fridgeDays` is how long it keeps in the fridge.
    - Component ids are short and kebab-case, like "p-chicken" or "s-tahini".

    Combinations:
    - Suggest 6 to 8 combinations. Each uses 3 or 4 component ids, usually one protein, one carb, \
    one or two vegetables and a sauce. Together they use every component, and no two are the same.
    - `vibe` is a 1 to 3 word label for the kind of meal: "Warm bowl", "Lunchbox salad", "Wrap", "Stir-fry", "Soup".
    - `assembly` says in one or two sentences how to put it together when eating (reheat, add fresh bits).
    - `kcal` and `proteinG` are per portion for one person; aim close to the per-meal targets.

    Cooking steps (one recipe for the whole session, in the optimal order):
    - Start with what takes longest (oven trays, simmering grains), do the chopping, sauces and \
    stovetop work while those cook, and finish with cooling and portioning into containers.
    - `startMinute` is when the step starts, counted from 0. Steps may overlap when they run in parallel \
    (e.g. chopping while a tray roasts); `minutes` is how long the step takes.
    - `title` is short (2 to 5 words). `instruction` is a recipe step with quantities, temperatures and times.
    - In `instruction`, wrap every quantity, temperature and time in double asterisks so they stand out, \
    e.g. "Toss **600 g** chicken with **2 tbsp** oil and roast at **220°C** for **25 min**."
    - `station` is where it happens: oven, stove, board (chopping), bowl (mixing, sauces), fridge (cooling, portioning).
    - `componentIds` lists the components the step works on (can be empty for general steps).
    - The last step ends within the requested time limit.

    Groceries:
    - Aggregate the raw ingredients of all components into one list, one row per product.
    - `amount` is the total needed, in metric units ("1.2 kg", "500 g", "3 pcs").
    - `picnicSearchTerm` is a short, generic Dutch search term as a Dutch supermarket would name the product, \
    with no brand or quantity: e.g. "kipfilet", "zoete aardappel", "griekse yoghurt", "basmati rijst", "broccoli".
    - `packages` is how many typical Dutch supermarket packages to buy to cover `amount`.
    - `section` is the store section in English: Produce, Meat & fish, Dairy & eggs, Bread, Pantry, Frozen, Spices.
    - Set `pantryStaple` to true for things most kitchens already have: oil, salt, pepper, dried herbs and spices, \
    vinegar, soy sauce, stock cubes.

    Write names and instructions in English.
    """

    static func request(for p: Preferences) -> String {
        var lines = [
            "Make a modular meal-prep plan for \(p.meals) meals for \(p.people) \(p.people == 1 ? "person" : "people").",
            "Diet: \(p.diet).",
            "Per meal per person: about \(p.kcalPerMeal) kcal and \(p.proteinPerMeal) g protein.",
            "Components: \(p.proteins) proteins, \(p.carbs) carbs, \(p.vegetables) vegetables, \(p.sauces) sauces.",
            "Cooking session time limit: \(p.maxPrepMinutes) minutes.",
        ]
        let avoid = (p.avoidTags + [p.avoid]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !avoid.isEmpty { lines.append("Do not use: \(avoid.joined(separator: ", ")).") }
        let wishes = (p.wishTags + [p.notes]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !wishes.isEmpty { lines.append("Wishes: \(wishes.joined(separator: "; ")).") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - JSON schema for structured outputs (ordered)

enum PlanSchema {
    private static let string = JSON.object([("type", .string("string"))])
    private static let integer = JSON.object([("type", .string("integer"))])
    private static let boolean = JSON.object([("type", .string("boolean"))])

    private static func array(_ items: JSON) -> JSON {
        .object([("type", .string("array")), ("items", items)])
    }

    private static func oneOf(_ values: [String]) -> JSON {
        .object([("type", .string("string")), ("enum", .array(values.map { .string($0) }))])
    }

    /// Properties in the order Claude should write them; all required, no extras.
    private static func object(_ properties: [(String, JSON)]) -> JSON {
        .object([
            ("type", .string("object")),
            ("properties", .object(properties)),
            ("required", .array(properties.map { .string($0.0) })),
            ("additionalProperties", .bool(false)),
        ])
    }

    static var plan: JSON {
        object([
            ("title", string),
            ("summary", string),
            ("components", array(object([
                ("id", string),
                ("name", string),
                ("category", oneOf(ComponentCategory.allCases.map(\.rawValue))),
                ("flavor", string),
                ("portions", integer),
                ("fridgeDays", integer),
            ]))),
            ("combinations", array(object([
                ("name", string),
                ("vibe", string),
                ("componentIds", array(string)),
                ("assembly", string),
                ("kcal", integer),
                ("proteinG", integer),
            ]))),
            ("cookingSteps", array(object([
                ("startMinute", integer),
                ("minutes", integer),
                ("title", string),
                ("instruction", string),
                ("station", oneOf(Station.allCases.map(\.rawValue))),
                ("componentIds", array(string)),
            ]))),
            ("groceries", array(object([
                ("id", string),
                ("name", string),
                ("amount", string),
                ("picnicSearchTerm", string),
                ("packages", integer),
                ("section", string),
                ("pantryStaple", boolean),
            ]))),
        ])
    }
}
