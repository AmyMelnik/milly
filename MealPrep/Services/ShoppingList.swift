import Foundation
import Observation

/// One grocery row matched to a Picnic product.
struct CartLine: Identifiable, Hashable {
    enum Status: Hashable {
        case idle, searching, matched, noMatch, adding, added
        case failed(String)
    }

    var item: GroceryItem
    var include: Bool
    var count: Int
    var candidates: [PicnicProduct] = []
    var selected: PicnicProduct?
    var status: Status = .idle

    var id: String { item.id }
}

/// Turns a plan's grocery list into Picnic cart lines: search, pick, add.
@MainActor
@Observable
final class ShoppingList {
    var lines: [CartLine] = []
    var isMatching = false
    var isAdding = false
    var progress = 0
    /// For the loading screens: how far along, and which item is being handled now.
    var taskTotal = 0
    var taskDone = 0
    var currentItem: String?
    var cart: PicnicCart?
    var errorMessage: String?
    private(set) var revision: UUID?

    var includedLines: [CartLine] { lines.filter(\.include) }

    var readyToAdd: [CartLine] {
        includedLines.filter { $0.selected != nil && $0.status != .added }
    }

    var estimatedCents: Int {
        includedLines.reduce(0) { $0 + ($1.selected?.priceCents ?? 0) * $1.count }
    }

    var sections: [String] {
        var order: [String] = []
        for line in lines where !order.contains(line.item.section) { order.append(line.item.section) }
        return order
    }

    /// Rebuild the list only when the plan actually changed, so picks aren't lost.
    func load(_ saved: SavedPlan) {
        guard saved.revision != revision else { return }
        revision = saved.revision
        cart = nil
        errorMessage = nil
        lines = saved.plan.groceries.map {
            CartLine(item: $0, include: !$0.pantryStaple, count: max(1, $0.packages))
        }
    }

    /// Search Picnic for every included item that has no product yet, one at a time
    /// to stay gentle on an unofficial API.
    func matchAll(using picnic: PicnicSession) async {
        let todo = lines.filter { $0.include && $0.selected == nil }
        isMatching = true
        errorMessage = nil
        taskTotal = todo.count
        taskDone = 0
        defer {
            isMatching = false
            currentItem = nil
        }
        for line in todo {
            currentItem = line.item.name
            await search(lineID: line.id, term: line.item.picnicSearchTerm, using: picnic)
            taskDone += 1
            if case .failed = status(of: line.id), !picnic.isLoggedIn { break }
        }
    }

    func search(lineID: String, term: String, using picnic: PicnicSession) async {
        update(lineID) { $0.status = .searching }
        do {
            let results = try await picnic.search(term)
            update(lineID) {
                $0.candidates = Array(results.prefix(12))
                $0.selected = results.first
                $0.status = results.isEmpty ? .noMatch : .matched
            }
        } catch {
            update(lineID) { $0.status = .failed(error.localizedDescription) }
            errorMessage = error.localizedDescription
        }
    }

    func choose(_ product: PicnicProduct, for lineID: String) {
        update(lineID) {
            $0.selected = product
            $0.status = .matched
        }
    }

    func addAll(using picnic: PicnicSession) async {
        let todo = readyToAdd
        isAdding = true
        progress = 0
        errorMessage = nil
        taskTotal = todo.count
        taskDone = 0
        defer {
            isAdding = false
            currentItem = nil
        }
        for line in todo {
            guard let product = line.selected else { continue }
            currentItem = line.item.name
            update(line.id) { $0.status = .adding }
            do {
                cart = try await picnic.add(productId: product.id, count: line.count)
                update(line.id) { $0.status = .added }
            } catch {
                update(line.id) { $0.status = .failed(error.localizedDescription) }
                errorMessage = error.localizedDescription
                if !picnic.isLoggedIn { break }
            }
            progress += 1
            taskDone += 1
        }
    }

    private func status(of id: String) -> CartLine.Status? {
        lines.first { $0.id == id }?.status
    }

    private func update(_ id: String, _ change: (inout CartLine) -> Void) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        change(&lines[index])
    }
}
