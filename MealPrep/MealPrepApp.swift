import SwiftUI

@main
struct MealPrepApp: App {
    @State private var store: AppStore

    init() {
        AppFonts.register()
        Keychain.clearIfFreshInstall()
        _store = State(initialValue: AppStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
                .tint(Theme.ink)
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.plans.isEmpty {
                    LandingView(onOpen: { path = [$0] }, onCreated: { path = [$0] })
                } else {
                    HomeView(onOpen: { path = [$0] }, onCreated: { path = [$0] })
                }
            }
            .animation(.easeInOut, value: store.plans.isEmpty)
            .navigationDestination(for: UUID.self) { id in
                    PlanView(planID: id)
                }
        }
        .fullScreenCover(isPresented: Binding(get: { store.needsOnboarding }, set: { _ in })) {
            OnboardingView()
        }
        #if DEBUG
        .overlay { DebugPreviewOverlay() }
        .onAppear {
            // Simulator previews only: jump straight to the latest plan.
            if ProcessInfo.processInfo.arguments.contains("-PreviewOpenLastPlan"), let last = store.latestPlan {
                path = [last.id]
            }
        }
        #endif
    }
}

// MARK: - Landing

struct LandingView: View {
    @Environment(AppStore.self) private var store
    let onOpen: (UUID) -> Void
    let onCreated: (UUID) -> Void

    @State private var showingWizard = false
    @State private var showingSettings = false
    @State private var floating = false

    private struct Placement {
        let food: Food
        let x: CGFloat
        let y: CGFloat
        let tilt: Double
    }

    /// All products share one scale, so they keep their real-life proportions.
    private let pointsPerCM: CGFloat = 3.2

    /// Ingredients scattered around the title and button (fractions of the screen).
    private let placements: [Placement] = [
        // Top
        Placement(food: .cereal, x: 0.15, y: 0.14, tilt: -8),
        Placement(food: .milk, x: 0.41, y: 0.125, tilt: 10),
        Placement(food: .leeks, x: 0.63, y: 0.135, tilt: 24),
        Placement(food: .oranges, x: 0.85, y: 0.185, tilt: 0),
        Placement(food: .vegemite, x: 0.10, y: 0.265, tilt: -10),
        Placement(food: .soysauce, x: 0.34, y: 0.255, tilt: 8),
        Placement(food: .tomatoes, x: 0.60, y: 0.262, tilt: 0),
        // Sides
        Placement(food: .cherryripe, x: 0.05, y: 0.50, tilt: -72),
        Placement(food: .tomatocan, x: 0.95, y: 0.48, tilt: 10),
        // Bottom
        Placement(food: .salmon, x: 0.15, y: 0.81, tilt: -10),
        Placement(food: .broccoli, x: 0.40, y: 0.855, tilt: 0),
        Placement(food: .basket, x: 0.66, y: 0.835, tilt: 4),
        Placement(food: .chickensoup, x: 0.08, y: 0.945, tilt: 8),
        Placement(food: .butter, x: 0.29, y: 0.955, tilt: 14),
        Placement(food: .mayo, x: 0.52, y: 0.945, tilt: -10),
        Placement(food: .prawnchips, x: 0.88, y: 0.925, tilt: -14),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(placements.enumerated()), id: \.offset) { index, p in
                    Art(food: p.food, size: p.food.lifeSizeFrame(pointsPerCM: pointsPerCM), tilt: p.tilt)
                        .offset(y: floating ? -4 : 4)
                        .animation(
                            .easeInOut(duration: 2.6 + Double(index % 4) * 0.35)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.12),
                            value: floating
                        )
                        .position(x: geo.size.width * p.x, y: geo.size.height * p.y)
                }

                VStack(spacing: 18) {
                    Eyebrow("Meal prep · Picnic")
                    TitleText("Cook once,\neat well all week", size: 42, alignment: .center)
                                            Text("A few batch-cooked basics, endless combinations, and your groceries straight into Picnic.")
                        .font(.sans(15))
                        .foregroundStyle(Theme.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 8)
                    Button("Create a meal prep plan") { showingWizard = true }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .frame(maxWidth: 296)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.52)
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
            .padding(.trailing, 10)
        }
        .background(Theme.cream.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { floating = true }
        .sheet(isPresented: $showingSettings) { SettingsSheet(currentPlanID: nil) }
        .fullScreenCover(isPresented: $showingWizard) {
            WizardView { id in
                showingWizard = false
                onCreated(id)
            }
        }
    }
}
