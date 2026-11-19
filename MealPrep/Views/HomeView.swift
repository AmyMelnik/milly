import SwiftUI

/// Home once you have plans: your latest plan front and centre, a big "new plan" button,
/// and every earlier plan below.
struct HomeView: View {
    @Environment(AppStore.self) private var store
    let onOpen: (UUID) -> Void
    let onCreated: (UUID) -> Void

    @State private var showingWizard = false
    @State private var showingSettings = false
    @State private var deleting: SavedPlan?

    private var featured: SavedPlan? { store.featuredPlan }
    private var history: [SavedPlan] { store.plans.filter { $0.id != featured?.id } }

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(greeting)
                        TitleText("Your meal prep", size: 34)
                    }
                    Spacer()
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Settings")
                }

                if let featured {
                    LatestPlanCard(saved: featured) { onOpen(featured.id) }
                }

                if !history.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            TitleText("Other plans", size: 26)
                            Spacer()
                            Text("\(history.count)").font(.sans(14)).foregroundStyle(Theme.tertiary)
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(history.enumerated()), id: \.element.id) { index, saved in
                                if index > 0 { Hairline() }
                                HistoryRow(saved: saved) { onOpen(saved.id) }
                                    .contextMenu {
                                        Button("Delete plan", systemImage: "trash", role: .destructive) { deleting = saved }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .card()
                        Text("Press and hold a plan to delete it.")
                            .font(.sans(12)).foregroundStyle(Theme.tertiary)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button { showingWizard = true } label: {
                Label("Make a new plan", systemImage: "sparkles")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .background(Theme.background.opacity(0.97))
            .overlay(alignment: .top) { Hairline() }
        }
        .pageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSettings) { SettingsSheet(currentPlanID: nil) }
        .fullScreenCover(isPresented: $showingWizard) {
            WizardView { id in
                showingWizard = false
                onCreated(id)
            }
        }
        .confirmationDialog("Delete \(deleting?.plan.title ?? "this plan")?",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let deleting { store.delete(deleting.id) }
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }
}

// MARK: - Latest plan

private struct LatestPlanCard: View {
    let saved: SavedPlan
    let onOpen: () -> Void

    private var plan: GeneratedPlan { saved.plan }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Theme.cream
                    ArtCluster(foods: featured)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 18)
                }
                .frame(height: 190)
                .overlay(alignment: .topLeading) {
                    Pill(text: saved.orderedAt != nil ? "Last ordered" : "Newest plan",
                         systemImage: saved.orderedAt != nil ? "cart.fill" : nil, fill: .white)
                        .padding(14)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(dateLine)
                        .font(.sans(12, .semibold))
                        .foregroundStyle(Theme.tertiary)
                    TitleText(plan.title, size: 30)
                    Text(plan.summary)
                        .font(.sans(14))
                        .foregroundStyle(Theme.secondary)
                        .lineSpacing(2)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    FlowLayout(spacing: 6) {
                        Pill(text: "\(plan.components.count) modules")
                        Pill(text: "\(plan.combinations.count) combos")
                        Pill(text: "\(Duration.text(plan.totalMinutes)) cooking", systemImage: "timer")
                        Pill(text: "\(saved.preferences.meals) meals")
                    }
                    .padding(.top, 2)
                    HStack {
                        Text("Open plan").font(.sans(15, .semibold))
                        Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 6)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
            .shadow(color: Theme.ink.opacity(0.06), radius: 18, y: 8)
        }
        .buttonStyle(PressableStyle())
    }

    private var dateLine: String {
        if let ordered = saved.orderedAt {
            return "Groceries ordered " + ordered.formatted(.relative(presentation: .named))
        }
        return "Made " + saved.createdAt.formatted(.relative(presentation: .named))
    }

    private var featured: [Food] {
        var foods: [Food] = []
        for c in plan.components where !foods.contains(c.food) { foods.append(c.food) }
        for f in [Food.basket, .tomatoes, .leeks, .broccoli, .oranges] where foods.count < 5 && !foods.contains(f) {
            foods.append(f)
        }
        return Array(foods.prefix(5))
    }
}

// MARK: - History

private struct HistoryRow: View {
    let saved: SavedPlan
    let onOpen: () -> Void

    private var subtitle: String {
        let date = saved.createdAt.formatted(date: .abbreviated, time: .omitted)
        let ordered = saved.orderedAt.map { " · ordered " + $0.formatted(date: .abbreviated, time: .omitted) } ?? ""
        return "\(date) · \(saved.plan.components.count) modules" + ordered
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cream)
                    Art(food: saved.plan.components.first?.food ?? .basket, size: 38, tilt: -6)
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text(saved.plan.title)
                        .font(.sans(15, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.sans(12))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

