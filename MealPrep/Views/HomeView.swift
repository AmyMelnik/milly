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
    /// Starred plans to repeat, except the one already featured at the top.
    private var favorites: [SavedPlan] { store.favorites.filter { $0.id != featured?.id } }
    private var history: [SavedPlan] { store.plans.filter { $0.id != featured?.id && !$0.isFavorite } }

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
                        .overlay(alignment: .topTrailing) {
                            FavoriteButton(saved: featured, filled: true).padding(8)
                        }
                }

                if !favorites.isEmpty {
                    planList("Favourites", favorites, art: .favourite)
                }

                if !history.isEmpty {
                    planList("Other plans", history, art: .savedPlans)
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

    private func planList(_ title: String, _ plans: [SavedPlan], art: Illustration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Art(art, size: 36, tilt: -6)
                TitleText(title, size: 26)
                Spacer()
                Text("\(plans.count)").font(.sans(14)).foregroundStyle(Theme.tertiary)
            }
            VStack(spacing: 0) {
                ForEach(Array(plans.enumerated()), id: \.element.id) { index, saved in
                    if index > 0 { Hairline() }
                    HistoryRow(saved: saved) { onOpen(saved.id) }
                        .contextMenu {
                            Button(saved.isFavorite ? "Remove from favourites" : "Add to favourites",
                                   systemImage: saved.isFavorite ? "star.slash" : "star") {
                                store.toggleFavorite(saved.id)
                            }
                            Button("Delete plan", systemImage: "trash", role: .destructive) { deleting = saved }
                        }
                }
            }
            .padding(.horizontal, 16)
            .card()
        }
        .animation(.easeInOut(duration: 0.25), value: plans.map(\.id))
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

    /// The card is wide and short, so the side ingredients are drawn nearly as big as the centrepiece
    /// and sit closer in. The top-left one is a little lower, clear of the "Last ordered" pill.
    private static let cardLayout: [ArtCluster.Spot] = [
        (0.5, 0.52, 0.86, 0),
        (0.14, 0.40, 0.58, -12), (0.86, 0.28, 0.60, 12),
        (0.20, 0.86, 0.56, 8), (0.82, 0.82, 0.58, -8),
    ]

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Theme.cream
                    ArtCluster(foods: featured, layout: Self.cardLayout)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                }
                .frame(height: 220)
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
        for f in [Food.basket, .tomatoes, .leeks, .broccoli, .lemonlime] where foods.count < 5 && !foods.contains(f) {
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

    /// One of the plan's own ingredients, picked at random but fixed per plan (seeded by its ID),
    /// so the list has some variety and each plan keeps its picture between launches.
    private var thumbnail: Food {
        var foods: [Food] = []
        for c in saved.plan.components where !foods.contains(c.food) { foods.append(c.food) }
        guard !foods.isEmpty else { return .basket }
        let seed = withUnsafeBytes(of: saved.id.uuid) { $0.reduce(0) { $0 &* 31 &+ Int($1) } }
        return foods[Int(seed.magnitude % UInt(foods.count))]
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cream)
                    Art(food: thumbnail, size: 38, tilt: -6)
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
                // Room for the star, which sits over the row so it isn't part of the open button.
                Color.clear.frame(width: 36, height: 1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            FavoriteButton(saved: saved).padding(.trailing, 14)
        }
    }
}

// MARK: - Favourite star

/// Stars or un-stars a plan. `filled` draws it on a white circle, for use over artwork.
struct FavoriteButton: View {
    @Environment(AppStore.self) private var store
    let saved: SavedPlan
    var filled = false

    var body: some View {
        Button {
            store.toggleFavorite(saved.id)
        } label: {
            Image(systemName: saved.isFavorite ? "star.fill" : "star")
                .font(.system(size: filled ? 15 : 16, weight: .medium))
                .foregroundStyle(saved.isFavorite ? Theme.accent : Theme.tertiary)
                .frame(width: filled ? 34 : 36, height: filled ? 34 : 44)
                .background { if filled { Circle().fill(.white) } }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: saved.isFavorite)
        .accessibilityLabel(saved.isFavorite ? "Remove from favourites" : "Add to favourites")
    }
}

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

