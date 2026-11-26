import SwiftUI

struct PlanView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    let planID: UUID

    enum Tab: String, CaseIterable {
        case combos = "Combos"
        case cooking = "Cooking order"
        case groceries = "Groceries"
    }

    @State private var tab: Tab = .combos
    @State private var showingTweak = false
    @State private var showingSettings = false
    @State private var showingShop = false
    @State private var swapTarget: SwapTarget?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let saved = store.plan(planID) {
                content(saved)
            } else {
                StateMessage(illustration: .planDeleted, title: "This plan was deleted")
            }
            if store.isRevising {
                ZStack {
                    Theme.background.ignoresSafeArea()
                    GeneratingView(title: "Updating your plan")
                }
                .transition(.opacity)
            }
        }
        .animation(.default, value: store.isRevising)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let saved = store.plan(planID) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.toggleFavorite(planID)
                    } label: {
                        Image(systemName: saved.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(saved.isFavorite ? Theme.accent : Theme.ink)
                    }
                    .sensoryFeedback(.selection, trigger: saved.isFavorite)
                    .accessibilityLabel(saved.isFavorite ? "Remove from favourites" : "Add to favourites")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Change something", systemImage: "wand.and.stars") { showingTweak = true }
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .sheet(isPresented: $showingTweak) { TweakSheet(planID: planID) }
        .sheet(isPresented: $showingSettings) { SettingsSheet(currentPlanID: planID) }
        .navigationDestination(isPresented: $showingShop) { ShopView(planID: planID) }
        .sheet(item: $swapTarget) { target in
            AlternativesSheet(planID: planID, target: target)
        }
        .alert(
            "Couldn't update the plan",
            isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
        ) {
            if ClaudePlanner.isInvalidKeyMessage(store.errorMessage ?? "") {
                Button("API key settings") { openURL(ClaudePlanner.keysURL) }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private func content(_ saved: SavedPlan) -> some View {
        let plan = saved.plan
        return PageScroll {
            VStack(alignment: .leading, spacing: 26) {
                header(plan)
                TabSwitcher(selection: $tab)
                switch tab {
                case .combos: CombosSection(plan: plan) { swapTarget = SwapTarget(name: $0.name, kind: $0.category.kindLabel, food: $0.food) }
                case .cooking: CookingSection(plan: plan)
                case .groceries: GroceriesSection(planID: planID, plan: plan, edits: saved.groceryEdits ?? []) {
                    swapTarget = SwapTarget(name: $0.name, kind: "ingredient", food: $0.food)
                }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Order groceries on Picnic") { showingShop = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 6)
                .background(Theme.background.opacity(0.96))
                .overlay(alignment: .top) { Hairline() }
        }
    }

    private func header(_ plan: GeneratedPlan) -> some View {
        var featured: [Food] = []
        for component in plan.components where !featured.contains(component.food) && featured.count < 4 {
            featured.append(component.food)
        }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: -10) {
                ForEach(Array(featured.enumerated()), id: \.offset) { index, food in
                    Art(food: food, size: 72, tilt: [-8, 6, -4, 10][index % 4])
                }
            }
            TitleText(plan.title, size: 36)
                .fixedSize(horizontal: false, vertical: true)
            if let kitchen = plan.fromKitchen, !kitchen.isEmpty {
                Pill(text: "Zero waste · uses \(kitchen.count) thing\(kitchen.count == 1 ? "" : "s") you have",
                     systemImage: "leaf", fill: Theme.success.opacity(0.12), foreground: Theme.success)
            }
            HStack(spacing: 0) {
                Stat(value: "\(plan.components.count)", label: "modules")
                Divider().frame(height: 34)
                Stat(value: "\(plan.combinations.count)", label: "combos")
                Divider().frame(height: 34)
                Stat(value: "\(plan.mixAndMatchCount)", label: "mixes")
                Divider().frame(height: 34)
                Stat(value: Duration.text(plan.totalMinutes), label: "cooking")
            }
            .padding(.vertical, 12)
            .card()
            .padding(.top, 4)
        }
    }
}

private struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .titleFont(22)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(.sans(12)).foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tabs

private struct TabSwitcher: View {
    @Binding var selection: PlanView.Tab
    @Namespace private var underline

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 22) {
                ForEach(PlanView.Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { selection = tab }
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.sans(15, selection == tab ? .semibold : .regular))
                                .foregroundStyle(selection == tab ? Theme.ink : Theme.secondary)
                            ZStack {
                                Rectangle().fill(.clear).frame(height: 2)
                                if selection == tab {
                                    Rectangle().fill(Theme.ink).frame(height: 2)
                                        .matchedGeometryEffect(id: "underline", in: underline)
                                }
                            }
                        }
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            Hairline()
        }
    }
}

private struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TitleText(title, size: 26)
            if let subtitle {
                Text(subtitle).font(.sans(14)).foregroundStyle(Theme.secondary)
            }
        }
    }
}

// MARK: - Combos

private struct CombosSection: View {
    let plan: GeneratedPlan
    let onSwap: (PrepComponent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionTitle(title: "Your prep")

            ForEach(ComponentCategory.allCases, id: \.self) { category in
                let items = plan.components.filter { $0.category == category }
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(category.label)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                                  alignment: .leading, spacing: 12) {
                            ForEach(items) { component in
                                ModuleCard(component: component) { onSwap(component) }
                            }
                        }
                    }
                }
            }

            MixBanner(plan: plan)

            SectionTitle(title: "Suggested combos")
            ForEach(plan.combinations) { combo in
                ComboCard(combo: combo, plan: plan)
            }
        }
    }
}

private struct ModuleCard: View {
    let component: PrepComponent
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Art(food: component.food, size: 56, tilt: -6)
                Spacer(minLength: 4)
                RefreshButton(label: "Alternatives for \(component.name)", action: onRefresh)
                    .offset(x: 6, y: -6)
            }
            Text(component.name)
                .font(.sans(15, .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(component.flavor)
                .font(.sans(12))
                .foregroundStyle(Theme.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Text("\(component.portions) portions · \(component.fridgeDays) days")
                .font(.sans(11, .semibold))
                .foregroundStyle(Theme.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(14)
        .card()
    }
}

private struct MixBanner: View {
    let plan: GeneratedPlan

    var body: some View {
        let groups = [ComponentCategory.protein, .carb, .vegetable, .sauce]
            .map { category in plan.components.filter { $0.category == category }.count }
            .filter { $0 > 0 }
        HStack(alignment: .center, spacing: 16) {
            Text("\(plan.mixAndMatchCount)")
                .titleFont(52)
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 4) {
                Text("ways to mix and match")
                    .font(.sans(16, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(groups.map(String.init).joined(separator: " × ") + ": any protein, carb, vegetable and sauce work together.")
                    .font(.sans(13))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(Theme.subtle, stroke: .clear)
    }
}

private struct ComboCard: View {
    let combo: Combination
    let plan: GeneratedPlan

    var body: some View {
        let parts = combo.componentIds.compactMap(plan.component)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(combo.vibe, color: Theme.accent)
                    TitleText(combo.name, size: 24)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                HStack(spacing: -16) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                        Art(food: part.food, size: 42, tilt: index.isMultiple(of: 2) ? -6 : 6)
                    }
                }
            }
            Text(parts.map(\.name).joined(separator: " · "))
                .font(.sans(13, .semibold))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(combo.assembly)
                .font(.sans(15))
                .foregroundStyle(Theme.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Pill(text: "\(combo.kcal) kcal")
                Pill(text: "\(combo.proteinG) g protein")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .card()
    }
}

// MARK: - Cooking order

private struct CookingSection: View {
    let plan: GeneratedPlan

    var body: some View {
        let steps = plan.orderedSteps
        VStack(alignment: .leading, spacing: 22) {
            SectionTitle(title: "One session, \(Duration.text(plan.totalMinutes))")

            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    TimelineRow(
                        number: index + 1,
                        step: step,
                        plan: plan,
                        isLast: index == steps.count - 1,
                        parallel: index > 0 && step.startMinute < steps[..<index].map(\.endMinute).max() ?? 0
                    )
                }
            }
        }
    }
}

private struct TimelineRow: View {
    let number: Int
    let step: CookingStep
    let plan: GeneratedPlan
    let isLast: Bool
    let parallel: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 6) {
                Text(Duration.clock(step.startMinute))
                    .font(.sans(13, .semibold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Circle()
                    .fill(parallel ? Theme.accent : Theme.ink)
                    .frame(width: 7, height: 7)
                if !isLast {
                    Rectangle()
                        .fill(Theme.line)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 8) {
                if parallel {
                    Eyebrow("Meanwhile", color: Theme.accent)
                }
                Text("\(number). \(step.title)")
                    .font(.sans(17, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(RecipeText.highlighted(step.instruction))
                    .font(.sans(15))
                    .foregroundStyle(Theme.ink.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                FlowLayout(spacing: 6) {
                    Pill(text: step.station.label, art: step.station.image)
                    Pill(text: "\(step.minutes) min", systemImage: "timer")
                    ForEach(step.componentIds.compactMap(plan.component)) { component in
                        HStack(spacing: 4) {
                            Art(food: component.food, size: 18)
                            Text(component.name).font(.sans(12, .semibold)).lineLimit(1)
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(.leading, 5)
                        .padding(.trailing, 10)
                        .padding(.vertical, 3)
                        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 26)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Groceries

private struct GroceriesSection: View {
    @Environment(AppStore.self) private var store
    let planID: UUID
    let plan: GeneratedPlan
    let edits: [String]
    let onSwap: (GroceryItem) -> Void

    @State private var editing: GroceryItem?
    @State private var confirmRegenerate = false

    var body: some View {
        let sections = plan.groceries.reduce(into: [String]()) { if !$0.contains($1.section) { $0.append($1.section) } }
        VStack(alignment: .leading, spacing: 22) {
            SectionTitle(title: "Shopping list",
                         subtitle: "\(plan.groceries.count) items")

            if let kitchen = plan.fromKitchen, !kitchen.isEmpty {
                FromKitchenCard(items: kitchen)
            }

            if !edits.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil.and.list.clipboard").font(.system(size: 18))
                        Text("You changed \(edits.count) ingredient\(edits.count == 1 ? "" : "s")")
                            .font(.sans(15, .semibold))
                    }
                    .foregroundStyle(Theme.ink)
                    Text(edits.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: "\n"))
                        .font(.sans(13))
                        .foregroundStyle(Theme.secondary)
                    Text("Update the recipes and combos to match?")
                        .font(.sans(13))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button("Update recipes") { Task { await store.applyGroceryEdits(planID) } }
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Keep as is") { store.discardGroceryEdits(planID) }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(18)
                .card(Theme.subtle, stroke: .clear)
            }

            ForEach(sections, id: \.self) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(section)
                    VStack(spacing: 0) {
                        let items = plan.groceries.filter { $0.section == section }
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Hairline() }
                            HStack(spacing: 8) {
                                Button { editing = item } label: {
                                    HStack(spacing: 12) {
                                        Art(food: item.food, size: 34)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.name).font(.sans(15, .semibold)).foregroundStyle(Theme.ink)
                                            Text(item.amount + (item.pantryStaple ? " · in your pantry" : ""))
                                                .font(.sans(12)).foregroundStyle(Theme.secondary)
                                        }
                                        Spacer(minLength: 4)
                                    }
                                    .padding(.vertical, 11)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                RefreshButton(label: "Alternatives for \(item.name)") { onSwap(item) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .card()
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Art(food: .pasta, size: 44, tilt: -8)
                    Text("Not feeling it?").font(.sans(15, .semibold)).foregroundStyle(Theme.ink)
                }
                Button("Make a new plan") { confirmRegenerate = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(18)
            .card()
        }
        .sheet(item: $editing) { item in
            GroceryEditSheet(planID: planID, item: item)
        }
        .sheet(isPresented: $confirmRegenerate) { NewPlanSheet(planID: planID) }
    }
}

private struct GroceryEditSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let planID: UUID
    let item: GroceryItem

    @State private var name = ""
    @State private var amount = ""
    @State private var haveIt = false
    @State private var confirmRemove = false

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Art(food: item.food, size: 64, tilt: -6)
                    VStack(alignment: .leading, spacing: 2) {
                        Eyebrow(item.section)
                        TitleText(item.name, size: 30)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Ingredient")
                    InputField(placeholder: "Ingredient", text: $name, plain: true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Amount")
                    InputField(placeholder: "e.g. 500 g", text: $amount, plain: true)
                }
                Toggle(isOn: $haveIt) {
                    Text("I already have this").font(.sans(15, .semibold)).foregroundStyle(Theme.ink)
                }
                .tint(Theme.ink)
                .padding(14)
                .card()

                Button("Save changes") {
                    var updated = item
                    updated.name = name.trimmingCharacters(in: .whitespaces)
                    updated.amount = amount.trimmingCharacters(in: .whitespaces)
                    updated.pantryStaple = haveIt
                    if !updated.name.isEmpty { store.updateGrocery(planID, updated) }
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Remove from list") { confirmRemove = true }
                    .font(.sans(14, .semibold))
                    .foregroundStyle(Theme.accent)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(22)
        }
        .pageBackground()
        .scrollDismissesKeyboard(.interactively)
        .presentationDragIndicator(.visible)
        .onAppear {
            name = item.name
            amount = item.amount
            haveIt = item.pantryStaple
        }
        .confirmationDialog("Remove \(item.name)?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                store.removeGrocery(planID, item.id)
                dismiss()
            }
        }
    }
}

/// Makes quantities, temperatures and times bold in recipe steps.
enum RecipeText {
    static func highlighted(_ raw: String) -> AttributedString {
        // New plans mark them with **…**; older plans get them found by pattern.
        if raw.contains("**") {
            var result = AttributedString()
            for (index, part) in raw.components(separatedBy: "**").enumerated() {
                var piece = AttributedString(part)
                if index % 2 == 1 { emphasize(&piece) }
                result += piece
            }
            return result
        }
        var result = AttributedString(raw)
        let pattern = #"\d+(?:[.,/–-]\d+)?\s?(?:°\s?[CF]?|%|kg|g|ml|cl|dl|l|tbsp|tsp|cups?|pcs|cloves?|cm|minutes?|mins?|hours?|hrs?|h|seconds?|sec)\b|\d+(?:[.,/–-]\d+)?\s?°[CF]?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let ns = raw as NSString
        for match in regex.matches(in: raw, range: NSRange(location: 0, length: ns.length)) {
            guard let range = Range(match.range, in: raw) else { continue }
            let start = raw.distance(from: raw.startIndex, to: range.lowerBound)
            let length = raw.distance(from: range.lowerBound, to: range.upperBound)
            let lower = result.characters.index(result.startIndex, offsetBy: start)
            let upper = result.characters.index(lower, offsetBy: length)
            emphasize(&result[lower..<upper])
        }
        return result
    }

    private static func emphasize(_ piece: inout AttributedString) {
        piece.font = .sans(15, .semibold)
        piece.foregroundColor = Theme.ink
    }

    private static func emphasize(_ piece: inout AttributedSubstring) {
        piece.font = .sans(15, .semibold)
        piece.foregroundColor = Theme.ink
    }
}

// MARK: - New plan

/// "Not feeling it?": what the cook didn't like, so the next plan avoids it.
private struct NewPlanSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let planID: UUID
    @State private var reasons: [String] = []
    @State private var text = ""

    private let ideas = ["Too repetitive", "Don't like the flavours", "Too much cooking", "Too expensive",
                         "Too heavy", "Too bland", "Not filling enough", "Ingredients I don't like"]

    private var feedback: String {
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (reasons + (typed.isEmpty ? [] : [typed])).joined(separator: "; ")
    }

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 22) {
                StepHeader(art: Illustration.planFailed.image,
                           title: "What didn't you like?",
                           subtitle: "The new plan will steer clear of it. This plan and its groceries are replaced.")
                FlowLayout(spacing: 8) {
                    ForEach(ideas, id: \.self) { idea in
                        Chip(text: idea, selected: reasons.contains(idea)) {
                            if let index = reasons.firstIndex(of: idea) { reasons.remove(at: index) } else { reasons.append(idea) }
                        }
                    }
                }
                InputField(placeholder: "For example: no more chickpeas", text: $text)
                Button("Make a new plan") {
                    let feedback = feedback
                    dismiss()
                    Task { await store.regenerate(planID, feedback: feedback) }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
        }
        .pageBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Tweak

private struct TweakSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let planID: UUID
    @State private var text = ""

    private let ideas = ["Make it spicier", "Cheaper", "More vegetables", "Less cooking time", "More protein", "No oven"]

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 22) {
                StepHeader(art: Illustration.tweak.image,
                           title: "Change something?")
                FlowLayout(spacing: 8) {
                    ForEach(ideas, id: \.self) { idea in
                        Chip(text: idea, selected: text == idea) { text = idea }
                    }
                }
                InputField(placeholder: "For example: swap rice for quinoa", text: $text)
                Button("Update my plan") {
                    let instruction = text
                    dismiss()
                    Task { await store.revise(planID, instruction: instruction) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            }
            .padding(24)
        }
        .pageBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Alternatives

struct SwapTarget: Identifiable {
    let name: String
    let kind: String
    let food: Food
    var id: String { kind + name }
}

extension ComponentCategory {
    var kindLabel: String {
        switch self {
        case .protein: "protein"
        case .carb: "carb"
        case .vegetable: "vegetable"
        case .sauce: "sauce"
        case .topping: "topping"
        }
    }
}

/// Small round ↻ button that opens alternatives.
struct RefreshButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 34, height: 34)
                .background(Theme.subtle, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Step 1: Claude suggests a few alternatives. Step 2: pick one, and the plan is rebuilt around it.
private struct AlternativesSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let planID: UUID
    let target: SwapTarget

    @State private var options: [ClaudePlanner.Alternative] = []
    @State private var seen: [String] = []
    @State private var selected: ClaudePlanner.Alternative?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            PageScroll {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Art(food: target.food, size: 60, tilt: -6)
                        VStack(alignment: .leading, spacing: 2) {
                            Eyebrow("Instead of")
                            TitleText(target.name, size: 28)
                        }
                    }

                    if loading {
                        VStack(spacing: 6) {
                            Art(.swap, size: 110, tilt: -4)
                                .phaseAnimator([false, true]) { art, flip in
                                    art.rotationEffect(.degrees(flip ? 6 : -6))
                                } animation: { _ in .easeInOut(duration: 0.9) }
                            Text("Finding alternatives that fit your plan…")
                                .font(.sans(14)).foregroundStyle(Theme.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    } else if let error {
                        Text(error: error).font(.sans(14)).foregroundStyle(Theme.accent).tint(Theme.ink)
                        Button("Try again") { load() }.buttonStyle(SecondaryButtonStyle())
                    } else {
                        VStack(spacing: 10) {
                            ForEach(options) { option in
                                Button { selected = option } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: selected == option ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20, weight: .light))
                                            .foregroundStyle(selected == option ? Theme.ink : Theme.tertiary)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(option.name).font(.sans(16, .semibold)).foregroundStyle(Theme.ink)
                                            Text(option.why).font(.sans(13)).foregroundStyle(Theme.secondary)
                                                .multilineTextAlignment(.leading)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .card(selected == option ? Theme.subtle : Theme.surface,
                                          stroke: selected == option ? Theme.ink : Theme.line,
                                          lineWidth: selected == option ? 1.5 : 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Button {
                            load()
                        } label: {
                            Label("Show other options", systemImage: "arrow.triangle.2.circlepath")
                                .font(.sans(14, .semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                }
                .padding(22)
            }

            VStack(spacing: 6) {
                Button(selected.map { "Use \($0.name.lowercased())" } ?? "Pick an alternative") {
                    guard let choice = selected else { return }
                    dismiss()
                    Task { await store.replace(planID, target.name, kind: target.kind, with: choice.name) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selected == nil)
                .opacity(selected == nil ? 0.4 : 1)
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Theme.background)
            .overlay(alignment: .top) { Hairline() }
        }
        .pageBackground()
        .presentationDragIndicator(.visible)
        .task { if options.isEmpty { load() } }
    }

    private func load() {
        loading = true
        error = nil
        selected = nil
        Task {
            do {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-PreviewAlternatives") {
                    try? await Task.sleep(for: .seconds(2))
                    options = [
                        .init(name: "Chicken thighs", why: "Juicy, cheap and roasts on the same tray."),
                        .init(name: "Firm tofu", why: "Soaks up the marinade and crisps up in the oven."),
                        .init(name: "Prawns", why: "Cooks in minutes and loves lemon and garlic."),
                        .init(name: "Chickpeas", why: "Crunchy when roasted, great in bowls."),
                    ]
                    loading = false
                    return
                }
                #endif
                let fresh = try await store.alternatives(planID, for: target.name, kind: target.kind, exclude: seen)
                options = fresh
                seen += fresh.map(\.name)
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}

/// Zero-waste mode: what the plan uses from the cook's own kitchen.
private struct FromKitchenCard: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "leaf").font(.system(size: 16)).foregroundStyle(Theme.success)
                Text("From your kitchen").font(.sans(15, .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text("not on the list").font(.sans(12)).foregroundStyle(Theme.tertiary)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(Theme.success).frame(width: 5, height: 5).offset(y: -2)
                        Text(item).font(.sans(14)).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(Theme.success.opacity(0.07), stroke: Theme.success.opacity(0.25))
    }
}
