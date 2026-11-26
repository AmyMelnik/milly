import SwiftUI

// MARK: - Basket animation

/// Ingredients keep dropping into a full basket that bounces as each one lands.
/// Each one falls in front of the groceries already inside and slips down behind the front wall,
/// never showing below or beside the basket.
struct BasketDrop: View {
    var foods: [Food] = [.tomatoes, .leeks, .milk, .salmon, .broccoli, .pasta, .lemonlime, .carrots, .eggs,
                         .soysauce, .butter, .chickenbreast, .sauce, .cheese, .tomatotin, .bellpepper]
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

    /// Height of the front rim above the bottom of the basket image, as a share of its size.
    private let rimHeight: CGFloat = 0.385
    /// Lowest point of the front wall's top edge (its middle), as a share of the basket size.
    /// Below this line a falling item may only show where the front wall is, which hides it.
    private let wallTop: CGFloat = 0.37

    var body: some View {
        ZStack(alignment: .bottom) {
            // Back: the full basket, groceries and all.
            Art(food: .basketfull, size: basketSize)
            ZStack(alignment: .bottom) {
                ForEach(drops) { drop in
                    // Same scale as the basket, so a tomato looks like a tomato next to it.
                    FallingItem(food: drop.food, x: drop.x, spin: drop.spin,
                                pointsPerCM: basketSize * Food.basketfull.canvasFill / Food.basketfull.realSizeCM,
                                rimY: -basketSize * rimHeight)
                }
            }
            // Tall and wide enough for the whole fall, so the mask doesn't cut it off.
            .frame(width: basketSize * 1.6, height: basketSize * 3, alignment: .bottom)
            // Once an item drops below the rim it is only drawn where the front wall covers it,
            // so it can't show through underneath or beside the basket.
            .mask(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    Rectangle().padding(.bottom, basketSize * wallTop)
                    Image("basketfull-front")
                        .resizable()
                        .scaledToFit()
                        .frame(width: basketSize, height: basketSize)
                }
            }
            .frame(width: basketSize, height: basketSize, alignment: .bottom)
            // Front wall, drawn over the falling items so they end up inside.
            Image("basketfull-front")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: basketSize, height: basketSize)
                .accessibilityHidden(true)
        }
        .scaleEffect(x: bump ? 1.05 : 1, y: bump ? 0.93 : 1, anchor: .bottom)
        .animation(.spring(response: 0.25, dampingFraction: 0.45), value: bump)
        .frame(width: basketSize * 1.5, height: basketSize * 1.6, alignment: .bottom)
        .accessibilityHidden(true)
        .task {
            while !Task.isCancelled {
                let food = foods[next % foods.count]
                next += 1
                drops.append(Drop(food: food, x: .random(in: -basketSize * 0.18...basketSize * 0.18),
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
    let pointsPerCM: CGFloat
    /// Offset of the front rim from the bottom of the basket (negative is up).
    let rimY: CGFloat

    @State private var fallen = false
    @State private var sunk = false

    var body: some View {
        let size = food.lifeSizeFrame(pointsPerCM: pointsPerCM)
        // The item's frame sits on the basket's bottom edge. Landed, its middle is at the rim,
        // so the lower half is already inside the basket; then it sinks out of sight.
        let landed = rimY + size / 2
        Art(food: food, size: size)
            .rotationEffect(.degrees(fallen ? spin : -spin / 2))
            // Sinks until its top is just below the rim, where the front wall and mask hide it.
            .offset(x: x, y: sunk ? landed + size * 0.6 : fallen ? landed : landed - 190)
            .onAppear {
                withAnimation(.easeIn(duration: 0.6)) { fallen = true }
                withAnimation(.easeOut(duration: 0.3).delay(0.62)) { sunk = true }
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
/// Veggies tossed in a pan: hand-drawn frames in Assets.xcassets/PanToss, played on a loop.
struct PanToss: View {
    var size: CGFloat = 255
    var framesPerSecond: Double = 12

    private static let frames = (1...16).map { Image(String(format: "pan-toss-%02d", $0)) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / framesPerSecond)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate * framesPerSecond)
            Self.frames[tick % Self.frames.count]
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}

struct GeneratingView: View {
    @Environment(AppStore.self) private var store
    var title = "Planning your prep"

    private var progress: PlanProgress { store.progress ?? PlanProgress() }

    private var stages: [PlanProgress.Stage] {
        (progress.withPhotos ? [.uploading] : []) + [.thinking, .components, .combinations, .cooking, .groceries]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            Group {
                if progress.stage == .finishing {
                    // The plan is in: the containers come out instead of the basket.
                    Art(.planReady, size: 170)
                        // Same footprint as the basket animation, so nothing below moves.
                        .frame(width: 170 * 1.5, height: 170 * 1.6, alignment: .bottom)
                        .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                } else {
                    PanToss(size: 255)
                        .frame(width: 170 * 1.5, height: 170 * 1.6, alignment: .bottom)
                        .transition(.opacity)
                }
            }
            .animation(.spring(duration: 0.45, bounce: 0.3), value: progress.stage == .finishing)
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
            Text(progress.stage == .uploading
                 ? "Photos can take a few seconds on mobile data. Keep the app open."
                 : "Usually takes about a minute. Keep the app open.")
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
