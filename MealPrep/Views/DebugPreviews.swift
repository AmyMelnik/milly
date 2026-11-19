#if DEBUG
import SwiftUI

/// Simulator-only previews of the loading screens, with fake progress.
/// Launch with `-PreviewGenerating` or `-PreviewPicnicSearch`. Not compiled into release builds.
struct DebugPreviewOverlay: View {
    @Environment(AppStore.self) private var store
    @State private var active = true

    private var args: [String] { ProcessInfo.processInfo.arguments }

    var body: some View {
        if active, args.contains("-PreviewGenerating") {
            GeneratingView()
                .background(Theme.background.ignoresSafeArea())
                .task { await simulatePlan() }
        } else if active, args.contains("-PreviewPicnicSearch") {
            PicnicWorkingView(adding: false)
                .task { await simulateSearch() }
        }
    }

    private func simulatePlan() async {
        let steps: [(PlanProgress.Stage, Double, String)] = [
            (.thinking, 0.06, "Thinking about what works well together"),
            (.thinking, 0.12, "Balancing flavours, protein and prep time"),
            (.components, 0.24, "3 of 9 modules picked"),
            (.components, 0.38, "8 of 9 modules picked"),
            (.combinations, 0.5, "3 meal ideas so far"),
            (.cooking, 0.7, "Step 4 of the session"),
            (.groceries, 0.88, "11 items on the list"),
        ]
        for step in steps {
            store.progress = PlanProgress(stage: step.0, fraction: step.1, detail: step.2)
            try? await Task.sleep(for: .seconds(args.contains("-PreviewHold") ? 1000 : 2.5))
        }
    }

    private func simulateSearch() async {
        let names = ["Chicken thighs", "Salmon fillets", "Sweet potatoes", "Broccoli", "Greek yoghurt"]
        store.shopping.taskTotal = names.count
        for (index, name) in names.enumerated() {
            store.shopping.currentItem = name
            store.shopping.taskDone = index
            try? await Task.sleep(for: .seconds(2))
        }
    }
}
#endif
