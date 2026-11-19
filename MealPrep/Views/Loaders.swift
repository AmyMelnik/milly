import SwiftUI

// MARK: - Basket animation

/// Ingredients keep dropping into a basket that bounces as each one lands.
struct BasketDrop: View {
    var foods: [Food] = [.tomatoes, .leeks, .milk, .salmon, .broccoli, .cereal, .oranges,
                         .soysauce, .butter, .chickensoup, .mayo, .vegemite, .tomatocan]
    var basketSize: CGFloat = 190

    private struct Drop: Identifiable {
        let id = UUID()
        let food: Food
        let x: CGFloat
        let spin: Double
    }

    @State private var drops: [Drop] = []
    @State private var bump = false
    @State private var next = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(drops) { drop in
                FallingItem(food: drop.food, x: drop.x, spin: drop.spin, landingY: -basketSize * 0.42)
            }
            Art(food: .basket, size: basketSize)
                .scaleEffect(x: bump ? 1.05 : 1, y: bump ? 0.93 : 1, anchor: .bottom)
                .animation(.spring(response: 0.25, dampingFraction: 0.45), value: bump)
        }
        .frame(width: basketSize * 1.5, height: basketSize * 1.6, alignment: .bottom)
        .accessibilityHidden(true)
        .task {
            while !Task.isCancelled {
                let food = foods[next % foods.count]
                next += 1
                drops.append(Drop(food: food, x: .random(in: -basketSize * 0.22...basketSize * 0.22),
                                  spin: .random(in: -50...50)))
                try? await Task.sleep(for: .milliseconds(620))
                bump = true
                try? await Task.sleep(for: .milliseconds(160))
                bump = false
                if drops.count > 4 { drops.removeFirst(drops.count - 4) }
                try? await Task.sleep(for: .milliseconds(420))
            }
        }
    }
}

private struct FallingItem: View {
    let food: Food
    let x: CGFloat
    let spin: Double
    let landingY: CGFloat

    @State private var fallen = false
    @State private var gone = false

    var body: some View {
        Art(food: food, size: food.lifeSizeFrame(pointsPerCM: 2.6))
            .rotationEffect(.degrees(fallen ? spin : -spin / 2))
            .offset(x: x, y: fallen ? landingY : landingY - 170)
            .opacity(gone ? 0 : 1)
            .scaleEffect(gone ? 0.6 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: 0.6)) { fallen = true }
                withAnimation(.easeOut(duration: 0.2).delay(0.62)) { gone = true }
            }
    }
}

// MARK: - Progress bar

struct ProgressLine: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule().fill(Theme.ink)
                    .frame(width: max(6, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 6)
        .animation(.easeOut(duration: 0.5), value: fraction)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(fraction * 100)) percent")
    }
}

// MARK: - Plan generation

/// Shown while Claude writes or updates a plan. Progress comes from the streamed reply.
struct GeneratingView: View {
    @Environment(AppStore.self) private var store
    var title = "Planning your prep"

    private var progress: PlanProgress { store.progress ?? PlanProgress() }

    private let stages: [PlanProgress.Stage] = [.thinking, .components, .combinations, .cooking, .groceries]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            BasketDrop(basketSize: 170)
            VStack(spacing: 10) {
                TitleText(title, size: 32, alignment: .center)
                Text(progress.detail)
                    .font(.sans(15))
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .animation(.easeInOut, value: progress.detail)
            }
            .padding(.top, 18)

            VStack(spacing: 8) {
                ProgressLine(fraction: progress.fraction)
                HStack {
                    Text(progress.stage.label).font(.sans(12, .semibold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(Int(progress.fraction * 100))%").font(.sans(12)).foregroundStyle(Theme.secondary).monospacedDigit()
                }
            }
            .padding(.top, 22)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(stages, id: \.self) { stage in
                    StageRow(label: stage.label, state: state(of: stage))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .padding(.top, 18)

            Spacer(minLength: 12)
            Text("Usually takes about a minute. Keep the app open.")
                .font(.sans(12))
                .foregroundStyle(Theme.tertiary)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 28)
    }

    private func state(of stage: PlanProgress.Stage) -> StageRow.State {
        if progress.stage == .finishing || stage.rawValue < progress.stage.rawValue { return .done }
        return stage == progress.stage ? .active : .waiting
    }
}

struct StageRow: View {
    enum State { case waiting, active, done }
    let label: String
    let state: State

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                switch state {
                case .done:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                case .active:
                    ProgressView().controlSize(.small).tint(Theme.ink)
                case .waiting:
                    Circle().strokeBorder(Theme.line, lineWidth: 1.5)
                }
            }
            .font(.system(size: 18))
            .frame(width: 20, height: 20)
            Text(label)
                .font(.sans(14, state == .active ? .semibold : .regular))
                .foregroundStyle(state == .waiting ? Theme.tertiary : Theme.ink)
        }
        .animation(.easeInOut, value: state)
    }
}

// MARK: - Picnic

/// Shown while products are searched on Picnic or added to the cart.
struct PicnicWorkingView: View {
    @Environment(AppStore.self) private var store
    let adding: Bool

    private var shopping: ShoppingList { store.shopping }

    private var fraction: Double {
        Double(shopping.taskDone) / Double(max(1, shopping.taskTotal))
    }

    private let searchLines = ["Walking the aisles…", "Checking the shelves…", "Comparing prices…", "Reading the labels…"]
    private let addLines = ["Filling your cart…", "Packing it neatly…", "Eggs on top…"]

    @State private var lineIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            BasketDrop(basketSize: 170)
            VStack(spacing: 10) {
                TitleText(adding ? "Adding to your Picnic cart" : "Shopping at Picnic", size: 32, alignment: .center)
                Group {
                    if let item = shopping.currentItem {
                        Text(adding ? "Adding \(item.lowercased())" : "Looking for \(item.lowercased())")
                    } else {
                        Text((adding ? addLines : searchLines)[lineIndex % (adding ? addLines : searchLines).count])
                    }
                }
                .font(.sans(15))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(.easeInOut, value: shopping.currentItem)
            }
            .padding(.top, 18)

            VStack(spacing: 8) {
                ProgressLine(fraction: fraction)
                HStack {
                    Text((adding ? addLines : searchLines)[lineIndex % (adding ? addLines : searchLines).count])
                        .font(.sans(12, .semibold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(shopping.taskDone) of \(shopping.taskTotal)")
                        .font(.sans(12)).foregroundStyle(Theme.secondary).monospacedDigit()
                }
            }
            .padding(.top, 22)
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 28)
        .background(Theme.background.ignoresSafeArea())
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.2))
                withAnimation { lineIndex += 1 }
            }
        }
    }
}
