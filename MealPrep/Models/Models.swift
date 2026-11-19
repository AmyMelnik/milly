import Foundation

// MARK: - What you ask for (filled in by the wizard)

struct Preferences: Codable, Hashable {
    var meals = 8
    var people = 1
    var diet = "No restrictions"
    var kcalPerMeal = 600
    var proteinPerMeal = 40

    // The "modules": how many of each component to batch-cook.
    var proteins = 2
    var carbs = 2
    var vegetables = 3
    var sauces = 2

    var maxPrepMinutes = 120
    var avoidTags: [String] = []
    var avoid = ""
    var wishTags: [String] = []
    var notes = ""
}

struct DietOption: Identifiable {
    let name: String
    let blurb: String
    let food: Food
    var id: String { name }

    static let all: [DietOption] = [
        DietOption(name: "No restrictions", blurb: "A bit of everything", food: .basket),
        DietOption(name: "High protein", blurb: "Lean & filling", food: .chickensoup),
        DietOption(name: "Vegetarian", blurb: "No meat or fish", food: .butter),
        DietOption(name: "Vegan", blurb: "Fully plant-based", food: .broccoli),
        DietOption(name: "Pescatarian", blurb: "Fish, no meat", food: .salmon),
        DietOption(name: "Low carb", blurb: "Easy on the grains", food: .tomatoes),
        DietOption(name: "Mediterranean", blurb: "Olive oil & lemon", food: .oranges),
    ]
}

// MARK: - What Claude returns (mirrors PlanSchema)

enum ComponentCategory: String, Codable, CaseIterable, Hashable {
    case protein, carb, vegetable, sauce, topping

    var label: String {
        switch self {
        case .protein: "Proteins"
        case .carb: "Carbs"
        case .vegetable: "Veggies"
        case .sauce: "Sauces"
        case .topping: "Toppings"
        }
    }

    var fallbackFood: Food {
        switch self {
        case .protein: .salmon
        case .carb: .cereal
        case .vegetable: .broccoli
        case .sauce: .mayo
        case .topping: .prawnchips
        }
    }
}

struct PrepComponent: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var category: ComponentCategory
    var flavor: String
    var portions: Int
    var fridgeDays: Int

    var food: Food { category == .sauce ? Food.matchSauce(name) : Food.match(name) ?? category.fallbackFood }
}

struct Combination: Codable, Identifiable, Hashable {
    var name: String
    var vibe: String
    var componentIds: [String]
    var assembly: String
    var kcal: Int
    var proteinG: Int

    var id: String { name }
}

enum Station: String, Codable, CaseIterable, Hashable {
    case oven, stove, board, bowl, fridge

    var label: String {
        switch self {
        case .oven: "Oven"
        case .stove: "Stove"
        case .board: "Board"
        case .bowl: "Bowl"
        case .fridge: "Fridge"
        }
    }

    var symbol: String {
        switch self {
        case .oven: "oven"
        case .stove: "flame"
        case .board: "carrot"
        case .bowl: "fork.knife"
        case .fridge: "refrigerator"
        }
    }
}

struct CookingStep: Codable, Hashable {
    var startMinute: Int
    var minutes: Int
    var title: String
    var instruction: String
    var station: Station
    var componentIds: [String]

    var endMinute: Int { startMinute + minutes }
}

struct GroceryItem: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var amount: String
    var picnicSearchTerm: String
    var packages: Int
    var section: String
    var pantryStaple: Bool

    var food: Food { Food.match("\(name) \(picnicSearchTerm)") ?? Food.forSection(section) }
}

struct GeneratedPlan: Codable, Hashable {
    var title: String
    var summary: String
    var components: [PrepComponent]
    var combinations: [Combination]
    var cookingSteps: [CookingStep]
    var groceries: [GroceryItem]

    func component(_ id: String) -> PrepComponent? {
        components.first { $0.id == id }
    }

    /// Wall-clock length of the prep session (steps overlap).
    var totalMinutes: Int { cookingSteps.map(\.endMinute).max() ?? 0 }

    /// Every protein × carb × veggie × sauce pairing you could assemble.
    var mixAndMatchCount: Int {
        let counts = [ComponentCategory.protein, .carb, .vegetable, .sauce]
            .map { category in components.filter { $0.category == category }.count }
            .filter { $0 > 0 }
        return counts.isEmpty ? 0 : counts.reduce(1, *)
    }

    var orderedSteps: [CookingStep] {
        cookingSteps.sorted { ($0.startMinute, $0.endMinute) < ($1.startMinute, $1.endMinute) }
    }
}

// MARK: - What the app keeps

struct SavedPlan: Codable, Identifiable, Hashable {
    var id = UUID()
    /// Changes every time the plan is revised, so the Picnic list knows to rebuild.
    var revision = UUID()
    var createdAt = Date()
    var preferences: Preferences
    var plan: GeneratedPlan
    /// Grocery changes the cook made by hand that the recipes don't reflect yet.
    var groceryEdits: [String]?
    /// When groceries from this plan were last added to the Picnic cart.
    var orderedAt: Date?
}

enum Duration {
    static func text(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m)"
    }

    static func clock(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}
