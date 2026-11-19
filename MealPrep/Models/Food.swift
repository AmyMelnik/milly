import SwiftUI

/// The ingredient illustrations in Assets.xcassets/Ingredients.
enum Food: String, CaseIterable {
    case leeks, tomatoes, milk, cereal, oranges, vegemite, cherryripe, soysauce
    case butter, tomatocan, chickensoup, mayo, salmon, prawnchips, broccoli, basket

    var image: Image { Image("ing-\(rawValue)") }

    /// Longest side of the real product, in centimetres.
    var realSizeCM: CGFloat {
        switch self {
        case .basket: 42
        case .leeks: 32
        case .cereal: 30
        case .milk: 25
        case .prawnchips: 25
        case .oranges: 24
        case .salmon: 21
        case .mayo: 20
        case .broccoli: 18
        case .soysauce: 15
        case .tomatoes: 14
        case .cherryripe: 14
        case .butter: 13
        case .tomatocan: 11
        case .chickensoup: 11
        case .vegemite: 10
        }
    }

    /// Share of the square canvas the drawing itself fills (measured from the PNGs).
    var canvasFill: CGFloat {
        switch self {
        case .basket: 0.89
        case .broccoli: 0.65
        case .butter: 0.63
        case .cereal: 0.66
        case .cherryripe: 0.84
        case .chickensoup: 0.75
        case .leeks: 0.67
        case .mayo: 0.75
        case .milk: 0.76
        case .oranges: 0.59
        case .prawnchips: 0.71
        case .salmon: 0.84
        case .soysauce: 0.73
        case .tomatocan: 0.65
        case .tomatoes: 0.73
        case .vegemite: 0.61
        }
    }

    /// Frame size that draws the product at true relative scale.
    func lifeSizeFrame(pointsPerCM: CGFloat) -> CGFloat {
        realSizeCM * pointsPerCM / canvasFill
    }

    /// Picks the closest illustration for an English or Dutch ingredient name.
    /// It's a splash of colour, not a literal picture, so close is good enough.
    static func match(_ text: String) -> Food? {
        firstMatch(text, in: table)
    }

    /// Sauces get a sauce-like illustration even when they mention lemon or herbs.
    static func matchSauce(_ text: String) -> Food {
        firstMatch(text, in: [
            (.soysauce, ["soy", "soja", "ketjap", "teriyaki", "miso", "ponzu", "hoisin", "sesame", "sesam"]),
            (.vegemite, ["peanut", "pinda", "satay", "sate"]),
            (.tomatocan, ["tomato", "tomaat", "salsa", "marinara", "harissa", "sambal", "romesco"]),
        ]) ?? .mayo
    }

    static func forSection(_ section: String) -> Food {
        let s = section.lowercased()
        if s.contains("meat") || s.contains("fish") { return .salmon }
        if s.contains("dairy") || s.contains("egg") { return .milk }
        if s.contains("spice") { return .vegemite }
        if s.contains("pantry") { return .tomatocan }
        if s.contains("bread") { return .cereal }
        if s.contains("produce") || s.contains("frozen") { return .broccoli }
        return .basket
    }

    private static func firstMatch(_ text: String, in table: [(Food, [String])]) -> Food? {
        let lower = text.lowercased()
        let words = lower.split { !$0.isLetter }.map(String.init)
        for (food, keywords) in table {
            for keyword in keywords {
                // Short keywords must start a word ("kip" → "kipfilet"); longer ones can appear anywhere.
                if keyword.count >= 4 ? lower.contains(keyword) : words.contains(where: { $0.hasPrefix(keyword) }) {
                    return food
                }
            }
        }
        return nil
    }

    // Order matters: main ingredients before flavourings, so "lemon-oregano chicken" is chicken.
    private static let table: [(Food, [String])] = [
        (.soysauce, ["fish sauce", "vissaus"]),
        (.vegemite, ["peanut butter", "pindakaas"]),
        (.tomatocan, ["coconut milk", "kokosmelk"]),
        (.oranges, ["sweet potato", "zoete aardappel", "carrot", "wortel", "pumpkin", "pompoen", "squash", "butternut"]),
        (.salmon, ["salmon", "zalm", "fish", "vis", "tuna", "tonijn", "cod", "kabeljauw", "shrimp", "garnal",
                   "prawn", "mackerel", "makreel", "beef", "rund", "mince", "gehakt", "pork", "varken", "steak",
                   "lamb", "lam"]),
        (.chickensoup, ["chicken", "kip", "turkey", "kalkoen", "soup", "soep", "stock", "bouillon", "broth"]),
        (.butter, ["butter", "boter", "cheese", "kaas", "feta", "halloumi", "paneer", "mozzarella", "parmesan",
                   "tofu", "tempeh", "egg", "eieren"]),
        (.tomatocan, ["chickpea", "kikkererwt", "bean", "bonen", "lentil", "linzen", "tin", "blik", "canned",
                      "passata", "corn", "mais"]),
        (.cereal, ["rice", "rijst", "quinoa", "bulgur", "couscous", "pasta", "noodle", "noedel", "orzo", "farro",
                   "barley", "gerst", "oats", "haver", "granola", "bread", "brood", "wrap", "tortilla", "grain",
                   "potato", "aardappel", "krieltjes"]),
        (.soysauce, ["soy", "soja", "ketjap", "vinegar", "azijn", "oil", "olie", "miso", "sriracha", "teriyaki"]),
        (.mayo, ["mayo", "dressing", "tzatziki", "tahini", "hummus", "pesto", "aioli", "mustard", "mosterd", "sauce", "saus"]),
        (.tomatoes, ["tomato", "tomaat", "tomaten", "pepper", "paprika", "chili", "chilli", "radish", "radijs"]),
        (.broccoli, ["broccoli", "spinach", "spinazie", "kale", "boerenkool", "cabbage", "kool", "greens",
                     "lettuce", "sla", "courgette", "zucchini", "green bean", "sperzie", "cucumber", "komkommer",
                     "peas", "erwten", "bok choy", "paksoi", "asparagus", "asperge", "edamame", "herb",
                     "peterselie", "parsley", "coriander", "koriander", "basil", "basilicum", "mushroom",
                     "champignon", "aubergine", "eggplant", "cauliflower", "bloemkool", "spruit", "avocado"]),
        (.leeks, ["leek", "prei", "onion", "ui", "garlic", "knoflook", "scallion", "spring onion", "lente",
                  "ginger", "gember", "shallot", "sjalot", "celery", "selderij"]),
        (.oranges, ["lemon", "citroen", "lime", "limoen", "orange", "sinaasappel", "mango"]),
        (.milk, ["yoghurt", "yogurt", "milk", "melk", "cream", "room", "kwark", "skyr", "cottage"]),
        (.vegemite, ["spread", "honey", "honing", "jam", "spice", "kruiden", "cumin", "komijn", "turmeric",
                     "kurkuma", "cinnamon", "kaneel", "oregano", "salt", "zout", "peper", "curry", "kerrie"]),
        (.prawnchips, ["nut", "noten", "seed", "zaden", "cashew", "walnut", "almond", "amandel", "crackers", "chips"]),
        (.cherryripe, ["chocolate", "chocola", "cacao", "dates", "dadels", "bar"]),
    ]
}
