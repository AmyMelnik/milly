import SwiftUI

/// First run: connect Claude (required) and Picnic (can be done later).
struct OnboardingView: View {
    @Environment(AppStore.self) private var store

    enum Step: Int, CaseIterable { case welcome, claude, picnic, done }

    @State private var step: Step = .welcome
    @State private var key = ""
    @State private var checking = false
    @State private var keyError: String?
    @State private var picnicLogin = PicnicLogin()

    // Welcome animation
    @State private var flight: [Int: ArtCluster.FlightPhase] = [:]
    @State private var landings = 0
    @State private var packing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                HStack(spacing: 6) {
                    ForEach(1..<Step.allCases.count, id: \.self) { index in
                        Capsule()
                            .fill(index <= step.rawValue ? Theme.ink : Theme.line)
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .animation(.easeOut, value: step)
            }

            PageScroll {
                content
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                    .id(step)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
            .scrollDismissesKeyboard(.interactively)

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .pageBackground()
        .interactiveDismissDisabled()
    }

    private func go(_ next: Step) {
        withAnimation(.easeOut(duration: 0.25)) { step = next }
    }

    /// Groceries hop into the basket one after another, then the onboarding moves on.
    private func packBasketAndStart() {
        guard !packing else { return }
        guard !reduceMotion else { go(.claude); return }
        packing = true
        Task { @MainActor in
            await withTaskGroup(of: Void.self) { group in
                // Back of the basket first, so the front items end up in front: leeks, milk, tomatoes, salmon.
                for (order, index) in [3, 2, 1, 4].enumerated() {
                    group.addTask { @MainActor in
                        try? await Task.sleep(for: .milliseconds(order * 180))
                        withAnimation(.easeOut(duration: 0.22)) { flight[index] = .lifted }
                        try? await Task.sleep(for: .milliseconds(220))
                        withAnimation(.easeIn(duration: 0.3)) { flight[index] = .settled }
                        try? await Task.sleep(for: .milliseconds(300))
                        landings += 1
                    }
                }
            }
            // Let the packed basket sit for a moment before moving on.
            try? await Task.sleep(for: .milliseconds(650))
            go(.claude)
            // Reset once the welcome page is gone, so Back shows it as it was.
            try? await Task.sleep(for: .milliseconds(300))
            flight = [:]
            packing = false
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            VStack(spacing: 28) {
                ArtCluster(foods: [.basket, .tomatoes, .milk, .leeks, .salmon],
                           flight: flight, landings: landings)
                    .frame(height: 260)
                    .sensoryFeedback(.impact(weight: .light), trigger: landings)
                VStack(spacing: 14) {
                    TitleText("Welcome", size: 44)
                    Text("Two quick things before your first plan: connect Claude, which writes your plans, and Picnic, where your groceries go.")
                        .font(.sans(16))
                        .foregroundStyle(Theme.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                SecurityNote(text: "Your key and your Picnic session are stored only in this iPhone's Keychain. They're encrypted, never synced or backed up, and only sent to Anthropic or Picnic.")
            }

        case .claude:
            VStack(alignment: .leading, spacing: 20) {
                StepIntro(art: (keyError == nil ? Food.soysauce.image : Illustration.invalidKey.image), eyebrow: "Step 1 of 2", title: "Connect Claude",
                          text: "Claude writes your meal-prep plans. Paste an API key from your Anthropic account; each new plan or change is one small paid request.")
                if store.hasAnthropicKey && key.isEmpty {
                    Label("A key is already saved on this iPhone", systemImage: "checkmark.circle.fill")
                        .font(.sans(15, .semibold))
                        .foregroundStyle(Theme.success)
                }
                InputField(placeholder: store.hasAnthropicKey ? "Paste a new key to replace it" : "sk-ant-…",
                           text: $key, secure: true)
                    .textContentType(.password)
                if let keyError {
                    Text(error: keyError).font(.sans(14)).foregroundStyle(Theme.accent).tint(Theme.ink)
                }
                Link(destination: URL(string: "https://console.anthropic.com/settings/keys")!) {
                    HStack(spacing: 6) {
                        Text("Get a key at console.anthropic.com")
                        Image(systemName: "arrow.up.right").font(.system(size: 11))
                    }
                    .font(.sans(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .underline()
                }
                SecurityNote(text: "Checked with Anthropic before it's saved. Kept in the Keychain, readable only while your iPhone is unlocked.")
            }

        case .picnic:
            VStack(alignment: .leading, spacing: 20) {
                StepIntro(art: (picnicLogin.codeSent ? Illustration.codeSent : .picnicLogin).image, eyebrow: "Step 2 of 2", title: "Log in to Picnic",
                          text: "So your grocery list can go straight into your Picnic cart.")
                PicnicLoginFields(model: picnicLogin)
                SecurityNote(text: "Your password goes straight to Picnic and is never saved. Only Picnic's session is kept, in the Keychain.")
            }

        case .done:
            VStack(spacing: 28) {
                Art(.welcome, size: 220, tilt: -4)
                    .frame(height: 240)
                VStack(spacing: 14) {
                    TitleText("You're all set", size: 40)
                    Text(store.picnic.isLoggedIn
                         ? "Claude and Picnic are connected. Let's plan your first prep."
                         : "Claude is connected. You can log in to Picnic when you order.")
                        .font(.sans(16))
                        .foregroundStyle(Theme.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        switch step {
        case .welcome:
            Button("Get started") { packBasketAndStart() }
                .buttonStyle(PrimaryButtonStyle())

        case .claude:
            HStack(spacing: 12) {
                CircleIconButton(systemImage: "arrow.left", size: 54) { go(.welcome) }
                Button {
                    verifyKey()
                } label: {
                    if checking { ProgressView().tint(.white) } else { Text(key.isEmpty && store.hasAnthropicKey ? "Continue" : "Verify key") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(checking || (key.isEmpty && !store.hasAnthropicKey))
                .opacity(key.isEmpty && !store.hasAnthropicKey ? 0.4 : 1)
            }

        case .picnic:
            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    CircleIconButton(systemImage: "arrow.left", size: 54) { go(.claude) }
                    if store.picnic.isLoggedIn {
                        Button("Continue") { go(.done) }
                            .buttonStyle(PrimaryButtonStyle())
                    } else {
                        PicnicLoginButton(model: picnicLogin) { go(.done) }
                    }
                }
                if !store.picnic.isLoggedIn {
                    Button("Skip for now, log in when I order") { go(.done) }
                        .font(.sans(14, .semibold))
                        .foregroundStyle(Theme.secondary)
                        .buttonStyle(.plain)
                        .frame(height: 36)
                }
            }

        case .done:
            Button("Start planning") { store.completeOnboarding() }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func verifyKey() {
        let candidate = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.isEmpty && store.hasAnthropicKey {
            go(.picnic)
            return
        }
        #if DEBUG
        // Simulator testing only: "test" gets through onboarding without a real key.
        // Plans can't be generated with it. Not compiled into release builds.
        if candidate == "test" {
            store.setAnthropicKey(candidate)
            key = ""
            go(.picnic)
            return
        }
        #endif
        checking = true
        keyError = nil
        Task {
            do {
                try await ClaudePlanner.validate(key: candidate)
                store.setAnthropicKey(candidate)
                key = ""
                go(.picnic)
            } catch {
                keyError = error.localizedDescription
            }
            checking = false
        }
    }
}

// MARK: - Pieces

struct StepIntro: View {
    let art: Image
    let eyebrow: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Art(image: art, size: 92, tilt: -6)
                .padding(.bottom, 4)
            Eyebrow(eyebrow)
            TitleText(title, size: 36)
                .fixedSize(horizontal: false, vertical: true)
            Text(text)
                .font(.sans(16))
                .foregroundStyle(Theme.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SecurityNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondary)
            Text(text)
                .font(.sans(13))
                .foregroundStyle(Theme.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(Theme.subtle, stroke: .clear, radius: 14)
    }
}

/// A loose group of illustrations: one big in the middle, the rest around it.
struct ArtCluster: View {
    let foods: [Food]
    var layout: [Spot] = ArtCluster.standardLayout
    /// How far each surrounding item (by index) has got on its way into the centre basket.
    var flight: [Int: FlightPhase] = [:]
    /// Bumped each time something lands, to bounce the basket and what's in it.
    var landings = 0

    enum FlightPhase { case lifted, settled }

    /// Where items end up inside the basket: offset from the basket's centre, and size, both as a share
    /// of the basket's size; rotation; and depth (higher is nearer the front). Bottoms sit below the rim,
    /// so the front wall hides them and only the tops peek out.
    private static let packed: [Int: (x: CGFloat, y: CGFloat, size: CGFloat, tilt: Double, depth: Double)] = [
        3: (-0.14, -0.15, 0.44, -18, 1),  // leeks stand up out of the back left
        2: (0.15, -0.09, 0.42, 9, 2),     // milk stands at the back right
        1: (-0.09, -0.03, 0.41, -8, 3),   // tomatoes at the front left
        4: (0.05, 0.02, 0.38, 26, 4),     // salmon tray propped up at the front right
    ]

    /// The basket is drawn larger than a regular centrepiece, so the groceries fit inside it at about their own size.
    private static let basketScale: CGFloat = 0.78

    private struct Squash {
        var x: CGFloat = 1
        var y: CGFloat = 1
    }

    typealias Spot = (x: CGFloat, y: CGFloat, size: CGFloat, tilt: Double)

    /// Where each item sits, as shares of the cluster's width and height; sizes are shares of its height.
    /// The first spot is the big centrepiece.
    static let standardLayout: [Spot] = [
        (0.5, 0.52, 0.62, 0), (0.18, 0.28, 0.34, -12), (0.83, 0.24, 0.36, 14),
        (0.16, 0.80, 0.32, 8), (0.85, 0.80, 0.34, -8),
    ]

    var body: some View {
        KeyframeAnimator(initialValue: Squash(), trigger: landings) { squash in
            GeometryReader { geo in
                cluster(w: geo.size.width, h: geo.size.height, squash: squash)
            }
        } keyframes: { _ in
            KeyframeTrack(\.y) {
                CubicKeyframe(0.92, duration: 0.07)
                SpringKeyframe(1, duration: 0.4, spring: .bouncy)
            }
            KeyframeTrack(\.x) {
                CubicKeyframe(1.05, duration: 0.07)
                SpringKeyframe(1, duration: 0.4, spring: .bouncy)
            }
        }
    }

    @ViewBuilder
    private func cluster(w: CGFloat, h: CGFloat, squash: Squash) -> some View {
        let items = Array(foods.prefix(layout.count).enumerated())
        let hasBasket = foods.first == .basket
        let b = layout[0]
        let basketSize = h * (hasBasket ? Self.basketScale : b.size)
        let basketCentre = CGPoint(x: w * b.x, y: h * b.y)
        // The drawn bottom of the basket, which stays put while it squashes.
        let pivot = CGPoint(x: basketCentre.x, y: basketCentre.y + basketSize * 0.34)
        let squashed = { (p: CGPoint) in
            CGPoint(x: pivot.x + (p.x - pivot.x) * squash.x, y: pivot.y + (p.y - pivot.y) * squash.y)
        }

        ForEach(items, id: \.offset) { index, food in
            let s = layout[index]
            if index == 0 {
                Art(food: food, size: basketSize, tilt: s.tilt)
                    .scaleEffect(x: hasBasket ? squash.x : 1, y: hasBasket ? squash.y : 1)
                    .position(hasBasket ? squashed(basketCentre) : basketCentre)
                    .zIndex(0)
            } else {
                // One view per item for the whole trip, so it moves into the basket in one go instead of
                // being swapped for a second copy.
                let restSize = h * s.size
                let start = CGPoint(x: w * s.x, y: h * s.y)
                let toward: Double = s.x < 0.5 ? 1 : -1
                let p = hasBasket ? Self.packed[index] : nil
                let phase = p == nil ? nil : flight[index]
                let settled = phase == .settled
                let position: CGPoint = switch phase {
                case nil: start
                case .lifted: CGPoint(x: start.x + (basketCentre.x - start.x) * 0.4,
                                      y: min(start.y, h * 0.3) - h * 0.12)
                case .settled: squashed(CGPoint(x: basketCentre.x + basketSize * p!.x,
                                                y: basketCentre.y + basketSize * p!.y))
                }
                let tilt: Double = switch phase {
                case nil: s.tilt
                case .lifted: s.tilt + 20 * toward
                case .settled: p!.tilt
                }
                let scale: CGFloat = switch phase {
                case nil: 1
                case .lifted: 1.08
                case .settled: basketSize * p!.size / restSize
                }
                Art(food: food, size: restSize, tilt: tilt)
                    .scaleEffect(x: scale * (settled ? squash.x : 1), y: scale * (settled ? squash.y : 1))
                    .position(position)
                    // In flight it's above everything; once it heads down it slips behind the front wall.
                    .zIndex(settled ? p!.depth : 20)
            }
        }

        if hasBasket {
            // The front wall, drawn over whatever is inside.
            Image("basket-front")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: basketSize, height: basketSize)
                .scaleEffect(x: squash.x, y: squash.y)
                .position(squashed(basketCentre))
                .zIndex(10)
                .accessibilityHidden(true)
        }
    }
}
