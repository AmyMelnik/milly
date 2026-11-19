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

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            VStack(spacing: 28) {
                ArtCluster(foods: [.basket, .tomatoes, .milk, .leeks, .salmon])
                    .frame(height: 260)
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
                StepIntro(food: .soysauce, eyebrow: "Step 1 of 2", title: "Connect Claude",
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
                    Text(keyError).font(.sans(14)).foregroundStyle(Theme.accent)
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
                StepIntro(food: .basket, eyebrow: "Step 2 of 2", title: "Log in to Picnic",
                          text: "So your grocery list can go straight into your Picnic cart. You still check out in the Picnic app.")
                PicnicLoginFields(model: picnicLogin)
                SecurityNote(text: "Your password goes straight to Picnic and is never saved. Only Picnic's session is kept, in the Keychain.")
            }

        case .done:
            VStack(spacing: 28) {
                ArtCluster(foods: [.broccoli, .oranges, .cereal, .chickensoup, .mayo])
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
            Button("Get started") { go(.claude) }
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
    let food: Food
    let eyebrow: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Art(food: food, size: 92, tilt: -6)
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

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let spots: [(CGFloat, CGFloat, CGFloat, Double)] = [
                (0.5, 0.52, 0.62, 0), (0.18, 0.28, 0.34, -12), (0.83, 0.24, 0.36, 14),
                (0.16, 0.80, 0.32, 8), (0.85, 0.80, 0.34, -8),
            ]
            ForEach(Array(foods.prefix(spots.count).enumerated()), id: \.offset) { index, food in
                let s = spots[index]
                Art(food: food, size: h * s.2, tilt: s.3)
                    .position(x: w * s.0, y: h * s.1)
            }
        }
    }
}
