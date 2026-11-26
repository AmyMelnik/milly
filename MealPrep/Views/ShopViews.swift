import SwiftUI
import UIKit

struct ShopView: View {
    @Environment(AppStore.self) private var store
    let planID: UUID
    @State private var login = PicnicLogin()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if !store.picnic.isLoggedIn {
                PageScroll {
                    VStack(alignment: .leading, spacing: 20) {
                        StepIntro(art: (login.codeSent ? Illustration.codeSent : .picnicLogin).image, eyebrow: "Picnic", title: "Log in to order",
                                  text: "Your groceries go straight into your Picnic cart.")
                        PicnicLoginFields(model: login)
                        SecurityNote(text: "Your password goes straight to Picnic and is never saved. Only Picnic's session is kept, in the Keychain.")
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    PicnicLoginButton(model: login) {}
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Theme.background)
                }
            } else if let saved = store.plan(planID) {
                ShoppingListView(saved: saved)
            }

            if store.shopping.isMatching || store.shopping.isAdding {
                PicnicWorkingView(adding: store.shopping.isAdding)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.shopping.isMatching || store.shopping.isAdding)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(store.shopping.isMatching || store.shopping.isAdding ? .hidden : .visible, for: .navigationBar)
    }
}

// MARK: - Opening the Picnic app

enum PicnicApp {
    /// Picnic's app handles universal links under picnic.app/nl/link/…; the plain website doesn't open it.
    /// If the app isn't installed, fall back to the App Store.
    @MainActor
    static func open() {
        let appLink = URL(string: "https://picnic.app/nl/link/cart")!
        UIApplication.shared.open(appLink, options: [.universalLinksOnly: true]) { opened in
            guard !opened else { return }
            let store = URL(string: "itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?media=software&term=picnic%20supermarkt")!
            UIApplication.shared.open(store)
        }
    }
}

// MARK: - Shopping list

private struct LineRef: Identifiable {
    let id: String
}

struct ShoppingListView: View {
    @Environment(AppStore.self) private var store
    let saved: SavedPlan
    @State private var picking: LineRef?

    var body: some View {
        @Bindable var shopping = store.shopping
        PageScroll {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Picnic")
                        TitleText("Fill your cart", size: 36)
                    }
                    Spacer()
                    Art(image: headerArt, size: 84, tilt: 6)
                }
                if let error = shopping.errorMessage {
                    HStack(spacing: 12) {
                        if Illustration.isOffline(error) { Art(.offline, size: 44, tilt: -6) }
                        Text(error)
                    }
                        .font(.sans(14))
                        .foregroundStyle(Theme.accent)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(Theme.subtle, stroke: .clear, radius: 14)
                }

                ForEach(shopping.sections, id: \.self) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(section)
                        VStack(spacing: 0) {
                            let indices = shopping.lines.indices.filter { shopping.lines[$0].item.section == section }
                            ForEach(Array(indices.enumerated()), id: \.element) { position, index in
                                if position > 0 { Hairline() }
                                CartLineRow(line: $shopping.lines[index]) {
                                    picking = LineRef(id: shopping.lines[index].id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .card()
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .onAppear { shopping.load(saved) }
        .onChange(of: saved.revision) { shopping.load(saved) }
        .safeAreaInset(edge: .bottom) { actionBar }
        .sheet(item: $picking) { ref in
            ProductPickerView(lineID: ref.id)
        }
    }

    /// The basket until something is in the cart, then how the order is going.
    private var headerArt: Image {
        let lines = store.shopping.includedLines
        guard lines.contains(where: { $0.status == .added }) else { return Food.basket.image }
        if lines.contains(where: { $0.status == .noMatch }) { return Illustration.cartPartial.image }
        if lines.allSatisfy({ $0.status == .added }) { return Illustration.checkout.image }
        return Illustration.cartAdded.image
    }

    @ViewBuilder
    private var actionBar: some View {
        let shopping = store.shopping
        let unmatched = shopping.includedLines.filter { $0.selected == nil && $0.status == .idle }
        VStack(spacing: 12) {
            if let cart = shopping.cart {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("In your Picnic cart").font(.sans(12)).foregroundStyle(Theme.secondary)
                        Text("\(cart.totalCount) items · \(Money.format(cart.totalPriceCents))")
                            .font(.sans(16, .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    if shopping.readyToAdd.isEmpty == false || !unmatched.isEmpty {
                        Button { PicnicApp.open() } label: {
                            HStack(spacing: 4) {
                                Text("Open Picnic")
                                Image(systemName: "arrow.up.right").font(.system(size: 11))
                            }
                            .font(.sans(14, .semibold))
                            .foregroundStyle(Theme.ink)
                        }
                    }
                }
            }

            if !unmatched.isEmpty {
                Button("Find \(unmatched.count) products on Picnic") {
                    Task { await shopping.matchAll(using: store.picnic) }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if !shopping.readyToAdd.isEmpty {
                Button("Add \(shopping.readyToAdd.count) to cart · about \(Money.format(shopping.estimatedCents))") {
                    Task {
                        await shopping.addAll(using: store.picnic)
                        if shopping.lines.contains(where: { $0.status == .added }) { store.markOrdered(saved.id) }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if shopping.cart != nil {
                Button("Open Picnic to check out") { PicnicApp.open() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(Theme.background.opacity(0.97))
        .overlay(alignment: .top) { Hairline() }
    }
}

private struct CartLineRow: View {
    @Binding var line: CartLine
    let onChange: () -> Void

    private var canChange: Bool { line.status != .added && line.status != .adding && line.status != .searching }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { line.include.toggle() }
                } label: {
                    Image(systemName: line.include ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(line.include ? Theme.ink : Theme.tertiary)
                }
                .buttonStyle(.plain)
                .disabled(line.status == .added)

                Art(food: line.item.food, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(line.item.name).font(.sans(15, .semibold)).foregroundStyle(Theme.ink)
                    Text(line.item.amount + (line.item.pantryStaple ? " · pantry" : ""))
                        .font(.sans(12))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                StatusBadge(status: line.status)
            }

            if line.include {
                if let product = line.selected {
                    // The whole product card opens the picker.
                    Button(action: onChange) {
                        HStack(spacing: 10) {
                            ProductImage(url: product.imageURL)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(product.name)
                                    .font(.sans(13, .semibold))
                                    .foregroundStyle(Theme.ink)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                Text([product.unitQuantity, product.priceText].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.sans(12))
                                    .foregroundStyle(Theme.secondary)
                            }
                            Spacer(minLength: 4)
                            if canChange {
                                VStack(spacing: 2) {
                                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 12))
                                    Text("Swap").font(.sans(10, .semibold))
                                }
                                .foregroundStyle(Theme.secondary)
                            }
                        }
                        .padding(10)
                        .contentShape(Rectangle())
                        .card(Theme.subtle, stroke: .clear, radius: 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canChange)
                    .accessibilityHint("Choose a different product")
                } else if line.status != .idle {
                    Button(action: onChange) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").font(.system(size: 13))
                            Text(line.status == .noMatch ? "No match found. Tap to search" : "Pick a product")
                                .font(.sans(13, .semibold))
                            Spacer()
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canChange)
                }

                if canChange {
                    HStack {
                        Text("Quantity").font(.sans(13)).foregroundStyle(Theme.secondary)
                        Spacer()
                        HStack(spacing: 12) {
                            CircleIconButton(systemImage: "minus", size: 32) {
                                // Below 1 the item stays on the list but is left out of the cart.
                                if line.count > 1 {
                                    line.count -= 1
                                } else {
                                    withAnimation(.easeOut(duration: 0.15)) { line.include = false }
                                }
                            }
                            .accessibilityLabel(line.count > 1 ? "Fewer" : "Leave out of cart")
                            Text("\(line.count)")
                                .font(.sans(15, .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.ink)
                                .frame(minWidth: 18)
                            CircleIconButton(systemImage: "plus", size: 32) { line.count = min(20, line.count + 1) }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .opacity(line.include ? 1 : 0.5)
    }
}

private struct StatusBadge: View {
    let status: CartLine.Status

    var body: some View {
        switch status {
        case .idle, .matched: EmptyView()
        case .searching, .adding: ProgressView().tint(Theme.secondary)
        case .noMatch: Pill(text: "No match", foreground: Theme.accent)
        case .added: Pill(text: "In cart", systemImage: "checkmark", fill: Theme.success.opacity(0.12), foreground: Theme.success)
        case .failed: Pill(text: "Failed", fill: Theme.accent.opacity(0.12), foreground: Theme.accent)
        }
    }
}

struct ProductImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Color.white
        }
        .frame(width: 44, height: 44)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Choose a different product

struct ProductPickerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let lineID: String
    @State private var term = ""

    private var line: CartLine? { store.shopping.lines.first { $0.id == lineID } }

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    if let line { Art(food: line.item.food, size: 60, tilt: -6) }
                    VStack(alignment: .leading, spacing: 2) {
                        TitleText(line?.item.name ?? "Product", size: 28)
                        if let line {
                            Text("You need \(line.item.amount)").font(.sans(14)).foregroundStyle(Theme.secondary)
                        }
                    }
                }
                HStack(spacing: 10) {
                    InputField(placeholder: "Search Picnic", text: $term, plain: true)
                        .submitLabel(.search)
                        .onSubmit(search)
                    CircleIconButton(systemImage: "magnifyingglass", size: 52, action: search)
                }

                if line?.status == .searching {
                    HStack {
                        Spacer()
                        Art(.searching, size: 96, tilt: -6)
                            .phaseAnimator([false, true]) { art, up in
                                art.offset(y: up ? -4 : 4).rotationEffect(.degrees(up ? 4 : -4))
                            } animation: { _ in .easeInOut(duration: 0.8) }
                        Spacer()
                    }
                } else if line?.status == .noMatch && (line?.candidates ?? []).isEmpty {
                    StateMessage(illustration: .productNotFound, title: "Nothing found",
                                 text: "Picnic has nothing for “\(term)”. Try a shorter or Dutch name.")
                        .padding(.top, 8)
                }

                VStack(spacing: 0) {
                    let candidates = line?.candidates ?? []
                    ForEach(Array(candidates.enumerated()), id: \.element.id) { index, product in
                        if index > 0 { Hairline() }
                        Button {
                            store.shopping.choose(product, for: lineID)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                ProductImage(url: product.imageURL)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(product.name).font(.sans(14, .semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                                    Text(product.unitQuantity ?? "").font(.sans(12)).foregroundStyle(Theme.secondary)
                                }
                                Spacer()
                                Text(product.priceText).font(.sans(14, .semibold)).foregroundStyle(Theme.ink)
                                if product.id == line?.selected?.id {
                                    Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
                                }
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .card()
                .opacity((line?.candidates ?? []).isEmpty || line?.status == .searching ? 0 : 1)
            }
            .padding(22)
        }
        .pageBackground()
        .presentationDragIndicator(.visible)
        .onAppear {
            guard let line else { return }
            if term.isEmpty { term = line.item.picnicSearchTerm }
            if line.candidates.isEmpty && line.status != .searching { search() }
        }
    }

    private func search() {
        let query = term.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        Task { await store.shopping.search(lineID: lineID, term: query, using: store.picnic) }
    }
}

// MARK: - Picnic login
// The fields and the main button are separate views so screens can pin the button
// above the keyboard (onboarding, ordering) while the fields scroll.

@MainActor
@Observable
final class PicnicLogin {
    var email = ""
    var password = ""
    var needsCode = false
    var channel = "SMS"
    var codeSent = false
    var code = ""
    var busy = false
    var error: String?

    var primaryTitle: String {
        guard needsCode else { return "Log in to Picnic" }
        return codeSent ? "Verify code" : "Send me a code"
    }

    var canSubmit: Bool {
        guard !busy else { return false }
        if needsCode { return codeSent ? !code.trimmingCharacters(in: .whitespaces).isEmpty : true }
        return !email.isEmpty && !password.isEmpty
    }

    func submit(_ picnic: PicnicSession, onLoggedIn: @escaping () -> Void) {
        run {
            if !self.needsCode {
                let outcome = try await picnic.login(email: self.email, password: self.password)
                self.password = ""
                if outcome == .needsSecondFactor { self.needsCode = true } else { onLoggedIn() }
            } else if !self.codeSent {
                try await picnic.sendSecondFactorCode(channel: self.channel)
                self.codeSent = true
            } else {
                try await picnic.verifySecondFactor(code: self.code)
                onLoggedIn()
            }
        }
    }

    func resend(_ picnic: PicnicSession) {
        run { try await picnic.sendSecondFactorCode(channel: self.channel) }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        busy = true
        error = nil
        Task {
            do { try await action() } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

struct PicnicLoginFields: View {
    @Environment(AppStore.self) private var store
    @Bindable var model: PicnicLogin

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.picnic.isLoggedIn {
                Label("Logged in to Picnic", systemImage: "checkmark.circle.fill")
                    .font(.sans(15, .semibold))
                    .foregroundStyle(Theme.success)
            } else if !model.needsCode {
                InputField(placeholder: "Email", text: $model.email, plain: true, keyboard: .emailAddress)
                    .textContentType(.username)
                InputField(placeholder: "Password", text: $model.password, secure: true)
                    .textContentType(.password)
            } else {
                Text(model.codeSent
                     ? "Enter the code Picnic sent you by \(model.channel == "SMS" ? "SMS" : "email")."
                     : "Picnic wants to confirm it's you. Where should they send a code?")
                    .font(.sans(15))
                    .foregroundStyle(Theme.ink)
                if !model.codeSent {
                    HStack(spacing: 8) {
                        Chip(text: "SMS", selected: model.channel == "SMS") { model.channel = "SMS" }
                        Chip(text: "Email", selected: model.channel == "EMAIL") { model.channel = "EMAIL" }
                    }
                } else {
                    InputField(placeholder: "Code", text: $model.code, plain: true, keyboard: .numberPad)
                        .textContentType(.oneTimeCode)
                    Button("Didn't get it? Send again") { model.resend(store.picnic) }
                        .font(.sans(14, .semibold))
                        .foregroundStyle(Theme.ink)
                        .underline()
                        .buttonStyle(.plain)
                        .disabled(model.busy)
                }
            }

            if let error = model.error {
                Text(error).font(.sans(14)).foregroundStyle(Theme.accent)
            }
        }
    }
}

/// The main login action: "Log in", "Send me a code" or "Verify code".
struct PicnicLoginButton: View {
    @Environment(AppStore.self) private var store
    let model: PicnicLogin
    let onLoggedIn: () -> Void

    var body: some View {
        Button {
            model.submit(store.picnic, onLoggedIn: onLoggedIn)
        } label: {
            if model.busy { ProgressView().tint(.white) } else { Text(model.primaryTitle) }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!model.canSubmit)
        .opacity(model.canSubmit || model.busy ? 1 : 0.4)
    }
}

/// Fields and button together, for places without a pinned footer (Settings).
struct PicnicLoginForm: View {
    @Environment(AppStore.self) private var store
    @State private var model = PicnicLogin()
    let onLoggedIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PicnicLoginFields(model: model)
            if !store.picnic.isLoggedIn {
                PicnicLoginButton(model: model, onLoggedIn: onLoggedIn)
            }
        }
    }
}

// MARK: - Settings

struct SettingsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let currentPlanID: UUID?
    @State private var key = ""
    @State private var checking = false
    @State private var keyMessage: String?

    var body: some View {
        NavigationStack {
            PageScroll {
                VStack(alignment: .leading, spacing: 18) {
                    section(title: "Claude", art: Food.soysauce.image) {
                        Label(store.hasAnthropicKey ? "API key saved on this iPhone" : "No API key",
                              systemImage: store.hasAnthropicKey ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .font(.sans(14, .semibold))
                            .foregroundStyle(store.hasAnthropicKey ? Theme.success : Theme.accent)
                        InputField(placeholder: "Paste a new key to replace it", text: $key, secure: true)
                        if let keyMessage {
                            Text(error: keyMessage).font(.sans(13)).foregroundStyle(Theme.accent).tint(Theme.ink)
                        }
                        HStack(spacing: 10) {
                            Button {
                                replaceKey()
                            } label: {
                                if checking { ProgressView().tint(.white) } else { Text("Verify and save") }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(key.isEmpty || checking)
                            .opacity(key.isEmpty ? 0.4 : 1)
                            if store.hasAnthropicKey {
                                Button("Remove") { store.setAnthropicKey("") }
                                    .buttonStyle(SecondaryButtonStyle(foreground: Theme.accent))
                            }
                        }
                        Text("Plans are made with \(ClaudePlanner.model). Each plan or change is one paid request.")
                            .font(.sans(12)).foregroundStyle(Theme.secondary)
                    }

                    section(title: "Picnic", art: Food.basket.image) {
                        if store.picnic.isLoggedIn {
                            Label("Logged in", systemImage: "checkmark.circle.fill")
                                .font(.sans(14, .semibold)).foregroundStyle(Theme.success)
                            Button("Log out of Picnic") { store.picnic.logout() }
                                .buttonStyle(SecondaryButtonStyle(foreground: Theme.accent))
                        } else {
                            PicnicLoginForm {}
                        }
                        Text("Picnic has no official API, so ordering may break if Picnic changes its app.")
                            .font(.sans(12)).foregroundStyle(Theme.secondary)
                    }

                    SecurityNote(text: "Your Claude key and Picnic session are stored only in this iPhone's Keychain: encrypted, readable only while it's unlocked, never synced or backed up. Your Picnic password is never stored. Saved plans are encrypted while the phone is locked.")

                    if store.plans.isEmpty {
                        section(title: "Saved plans", art: Illustration.noPlans.image) {
                            Text("No saved plans yet. Your plans show up here once you make one.")
                                .font(.sans(14)).foregroundStyle(Theme.secondary)
                        }
                    } else {
                        section(title: "Saved plans", art: Illustration.savedPlans.image) {
                            ForEach(store.plans) { plan in
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(plan.plan.title).font(.sans(15, .semibold)).foregroundStyle(Theme.ink)
                                        Text(plan.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.sans(12)).foregroundStyle(Theme.secondary)
                                    }
                                    Spacer()
                                    if plan.id != currentPlanID {
                                        Button { store.delete(plan.id) } label: {
                                            Image(systemName: "trash").foregroundStyle(Theme.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Text("Open").font(.sans(12)).foregroundStyle(Theme.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .pageBackground()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.font(.sans(16, .semibold))
                }
            }
        }
    }

    private func replaceKey() {
        let candidate = key.trimmingCharacters(in: .whitespacesAndNewlines)
        checking = true
        keyMessage = nil
        Task {
            do {
                try await ClaudePlanner.validate(key: candidate)
                store.setAnthropicKey(candidate)
                key = ""
            } catch {
                keyMessage = error.localizedDescription
            }
            checking = false
        }
    }

    private func section<Content: View>(title: String, art: Image, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Art(image: art, size: 40, tilt: -6)
                TitleText(title, size: 24)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .card()
    }
}
