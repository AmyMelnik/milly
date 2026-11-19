import SwiftUI

/// One question per screen (two when they're tiny), then Claude makes the plan.
struct WizardView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onFinished: (UUID) -> Void

    enum Step: Int, CaseIterable {
        case meals, diet, hunger, base, color, time, avoid, wishes, review
    }

    enum Phase: Equatable {
        case asking, generating
        case failed(String)
    }

    @State private var step: Step = .meals
    @State private var draft = Preferences()
    @State private var phase: Phase = .asking
    @State private var loaded = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch phase {
            case .asking:
                asking
            case .generating:
                GeneratingView()
                    .transition(.opacity)
            case let .failed(message):
                FailedView(message: message, retry: generate) {
                    withAnimation { phase = .asking }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            guard !loaded else { return }
            draft = store.preferences
            loaded = true
        }
    }

    // MARK: Layout

    private var asking: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 36, height: 36)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.line)
                        Capsule().fill(Theme.ink)
                            .frame(width: geo.size.width * CGFloat(step.rawValue + 1) / CGFloat(Step.allCases.count))
                    }
                }
                .frame(height: 3)
                .animation(.easeOut, value: step)
                Text("\(step.rawValue + 1) of \(Step.allCases.count)")
                    .font(.sans(13))
                    .foregroundStyle(Theme.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            PageScroll {
                content
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 30)
                    .id(step)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
            .scrollDismissesKeyboard(.interactively)

            HStack(spacing: 12) {
                if step != .meals {
                    CircleIconButton(systemImage: "arrow.left", size: 54) { go(-1) }
                }
                Button(nextTitle) {
                    if step == .review { generate() } else { go(1) }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
            .padding(.top, 8)
        }
    }

    private var nextTitle: String {
        switch step {
        case .review: "Make my plan"
        case .avoid: draft.avoidTags.isEmpty && draft.avoid.isEmpty ? "Nothing to leave out" : "Next"
        case .wishes: draft.wishTags.isEmpty && draft.notes.isEmpty ? "Skip" : "Next"
        default: "Next"
        }
    }

    private func go(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        withAnimation(.easeOut(duration: 0.25)) { step = next }
    }

    private func generate() {
        store.preferences = draft
        withAnimation { phase = .generating }
        Task {
            do {
                let id = try await store.generate()
                onFinished(id)
            } catch {
                withAnimation { phase = .failed(error.localizedDescription) }
            }
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .meals:
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(food: .basket,
                           title: "How many meals are you prepping?",
                           subtitle: "Count every lunch and dinner you want ready in the fridge.")
                Counter(label: "Meals", value: $draft.meals, range: 2...21, unit: "meals")
                Counter(label: "People", value: $draft.people, range: 1...6,
                        unit: draft.people == 1 ? "person" : "people", compact: true)
            }

        case .diet:
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(food: nil,
                           title: "What's your eating style?",
                           subtitle: "Pick the one that fits best.")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(DietOption.all) { option in
                        OptionTile(food: option.food, title: option.name, subtitle: option.blurb,
                                   selected: draft.diet == option.name) {
                            withAnimation(.easeOut(duration: 0.15)) { draft.diet = option.name }
                        }
                    }
                }
            }

        case .hunger:
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(food: .salmon,
                           title: "How big is one meal?",
                           subtitle: "Per person. A typical lunch is 500 to 700 kcal.")
                Counter(label: "Energy", value: $draft.kcalPerMeal, range: 300...1200, step: 50, unit: "kcal", compact: true)
                Counter(label: "Protein", value: $draft.proteinPerMeal, range: 10...90, step: 5, unit: "grams", compact: true)
            }

        case .base:
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(food: .chickensoup,
                           title: "Pick your base",
                           subtitle: "How many different proteins and carbs should you cook?")
                Counter(label: "Proteins", value: $draft.proteins, range: 1...4, unit: draft.proteins == 1 ? "protein" : "proteins", compact: true)
                Counter(label: "Carbs", value: $draft.carbs, range: 1...4, unit: draft.carbs == 1 ? "carb" : "carbs", compact: true)
            }

        case .color:
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(food: .broccoli,
                           title: "Add colour and flavour",
                           subtitle: "More of each means more combinations, and a bit more chopping.")
                Counter(label: "Vegetables", value: $draft.vegetables, range: 1...5, unit: draft.vegetables == 1 ? "vegetable" : "vegetables", compact: true)
                Counter(label: "Sauces", value: $draft.sauces, range: 0...4, unit: draft.sauces == 1 ? "sauce" : "sauces", compact: true)
            }

        case .time:
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(food: .tomatoes,
                           title: "How long can you cook?",
                           subtitle: "One session, start to finish, dishes included.")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(TimeOption.all) { option in
                        TimeTile(option: option, selected: draft.maxPrepMinutes == option.minutes) {
                            withAnimation(.easeOut(duration: 0.15)) { draft.maxPrepMinutes = option.minutes }
                        }
                    }
                }
            }

        case .avoid:
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(food: .prawnchips,
                           title: "Anything to leave out?",
                           subtitle: "Allergies, dislikes, or things you're tired of.")
                ChipPicker(options: ["Pork", "Beef", "Fish", "Shellfish", "Dairy", "Eggs", "Gluten",
                                     "Nuts", "Mushrooms", "Spicy", "Coriander", "Olives"],
                           selection: $draft.avoidTags)
                InputField(placeholder: "Something else?", text: $draft.avoid)
            }

        case .wishes:
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(food: .oranges,
                           title: "Any wishes?",
                           subtitle: "Optional: flavours, habits, kitchen limits.")
                ChipPicker(options: ["Asian flavours", "Mediterranean", "Mexican", "Middle Eastern",
                                     "Budget-friendly", "Eaten cold at work", "Freezer-friendly",
                                     "Few dishes", "Kid-friendly"],
                           selection: $draft.wishTags)
                InputField(placeholder: "Tell Claude more…", text: $draft.notes)
            }

        case .review:
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(food: .basket,
                           title: "Ready when you are",
                           subtitle: "Check your answers. Claude plans the rest in about a minute.")
                Summary(preferences: draft)
            }
        }
    }
}

// MARK: - Pieces

struct StepHeader: View {
    let food: Food?
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let food {
                Art(food: food, size: 84, tilt: -6)
                    .padding(.bottom, 6)
            }
            TitleText(title, size: 34)
                                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.sans(16))
                .foregroundStyle(Theme.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct Counter: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    let unit: String
    var compact = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(label)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(value)")
                        .titleFont(compact ? 44 : 60)
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(value)))
                    Text(unit)
                        .font(.sans(15))
                        .foregroundStyle(Theme.secondary)
                }
            }
            Spacer()
            HStack(spacing: 10) {
                CircleIconButton(systemImage: "minus", size: 46) { change(-step) }
                    .opacity(value > range.lowerBound ? 1 : 0.3)
                CircleIconButton(systemImage: "plus", size: 46) { change(step) }
                    .opacity(value < range.upperBound ? 1 : 0.3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, compact ? 16 : 22)
        .card()
    }

    private func change(_ delta: Int) {
        withAnimation(.snappy) { value = min(range.upperBound, max(range.lowerBound, value + delta)) }
    }
}

private struct OptionTile: View {
    let food: Food
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Art(food: food, size: 48)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(selected ? Theme.ink : Theme.line)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.sans(15, .semibold)).foregroundStyle(Theme.ink)
                    Text(subtitle).font(.sans(12)).foregroundStyle(Theme.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .card(selected ? Theme.subtle : Theme.surface,
                  stroke: selected ? Theme.ink : Theme.line,
                  lineWidth: selected ? 1.5 : 1)
        }
        .buttonStyle(.plain)
    }
}

private struct TimeOption: Identifiable {
    let minutes: Int
    let note: String
    var id: Int { minutes }

    static let all = [
        TimeOption(minutes: 45, note: "Quick and simple"),
        TimeOption(minutes: 60, note: "Weeknight"),
        TimeOption(minutes: 90, note: "Relaxed"),
        TimeOption(minutes: 120, note: "Sunday classic"),
        TimeOption(minutes: 150, note: "Big batch"),
        TimeOption(minutes: 180, note: "All in"),
    ]
}

private struct TimeTile: View {
    let option: TimeOption
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Duration.text(option.minutes))
                    .titleFont(28)
                    .foregroundStyle(Theme.ink)
                Text(option.note)
                    .font(.sans(13))
                    .foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .card(selected ? Theme.subtle : Theme.surface,
                  stroke: selected ? Theme.ink : Theme.line,
                  lineWidth: selected ? 1.5 : 1)
        }
        .buttonStyle(.plain)
    }
}

private struct ChipPicker: View {
    let options: [String]
    @Binding var selection: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Chip(text: option, selected: selection.contains(option)) {
                    if let index = selection.firstIndex(of: option) {
                        selection.remove(at: index)
                    } else {
                        selection.append(option)
                    }
                }
            }
        }
    }
}

private struct Summary: View {
    let preferences: Preferences

    var body: some View {
        let p = preferences
        let avoid = p.avoidTags + (p.avoid.isEmpty ? [] : [p.avoid])
        let wishes = p.wishTags + (p.notes.isEmpty ? [] : [p.notes])
        VStack(spacing: 0) {
            row("Meals", "\(p.meals) for \(p.people) \(p.people == 1 ? "person" : "people")")
            row("Eating style", p.diet)
            row("Per meal", "\(p.kcalPerMeal) kcal · \(p.proteinPerMeal) g protein")
            row("Modules", "\(p.proteins) proteins · \(p.carbs) carbs · \(p.vegetables) veg · \(p.sauces) sauces")
            row("Cooking time", Duration.text(p.maxPrepMinutes))
            row("Leave out", avoid.isEmpty ? "Nothing" : avoid.joined(separator: ", "))
            row("Wishes", wishes.isEmpty ? "None" : wishes.joined(separator: ", "), last: true)
        }
        .padding(.horizontal, 18)
        .card()
    }

    private func row(_ label: String, _ value: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(label).font(.sans(14)).foregroundStyle(Theme.secondary)
                Spacer(minLength: 12)
                Text(value)
                    .font(.sans(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 14)
            if !last { Hairline() }
        }
    }
}

// MARK: - Generating & failure

private struct FailedView: View {
    let message: String
    let retry: () -> Void
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Art(food: .tomatocan, size: 96, tilt: -10)
            TitleText("Something went wrong", size: 34)
            Text(message)
                .font(.sans(16))
                .foregroundStyle(Theme.secondary)
            Spacer()
            Button("Try again", action: retry)
                .buttonStyle(PrimaryButtonStyle())
            Button("Change my answers", action: back)
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(24)
    }
}
