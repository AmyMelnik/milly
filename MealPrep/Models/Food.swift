import SwiftUI

/// The ingredient illustrations in Assets.xcassets/Ingredients.
enum Food: String, CaseIterable {
    case basket, basketfull
    case bellpepper, broccoli, carrots, courgette, leeks, lemonlime, mushrooms, oniongarlic
    case potatoes, spinach, sweetpotato, tomatoes
    case aubergine, avocado, beetroot, cabbage, cauliflower, chili, corn, cucumber, ginger
    case greenbeans, herbs, kale, lettuce, peas, frozenveg
    case apple, banana, berries, orange
    case chickenbreast, mincedmeat, salmon, shrimp, tofu, eggs
    case beef, sausage, tuna, whitefish, tempeh
    case butter, cheese, milk, yoghurt, cream, feta, mozzarella
    case chickpeas, coconutmilk, tomatotin, stock, beans, lentils
    case oats, pasta, rice, wraps, bread, noodles, quinoa
    case oliveoil, sauce, soysauce, spicejar
    case honey, mustard, peanutbutter, pesto, salt, sesame, tahini, vinegar
    case nuts, chocolate
    case lowcarb

    var image: Image { Image("ing-\(rawValue)") }

    /// Longest side of the real product, in centimetres.
    var realSizeCM: CGFloat {
        switch self {
        case .basket, .basketfull: 42
        case .leeks: 32
        case .cucumber: 28
        case .milk, .oats, .pasta, .potatoes, .wraps, .frozenveg, .kale, .lettuce: 25
        case .bread: 24
        case .chickenbreast, .courgette, .oliveoil, .rice, .spinach, .aubergine, .corn, .herbs: 22
        case .salmon, .whitefish: 21
        case .carrots, .stock, .sweetpotato, .banana, .sausage: 20
        case .broccoli, .eggs, .mincedmeat, .nuts, .sauce, .shrimp, .beef, .cabbage, .cauliflower,
             .greenbeans, .lentils, .vinegar, .lowcarb: 18
        case .chocolate, .noodles, .tempeh: 16
        case .soysauce: 15
        case .lemonlime, .mushrooms, .oniongarlic, .tomatoes, .beetroot, .feta, .quinoa: 14
        case .butter, .tofu: 13
        case .cheese, .yoghurt, .berries, .mozzarella, .peanutbutter, .peas, .tahini: 12
        case .bellpepper, .chickpeas, .coconutmilk, .tomatotin, .avocado, .beans, .honey, .pesto: 11
        case .spicejar, .chili, .cream, .ginger, .mustard, .orange, .salt, .tuna: 10
        case .apple, .sesame: 8
        }
    }

    /// Share of the square canvas the drawing itself fills. The pack is normalised, so it's the same for all.
    var canvasFill: CGFloat { 0.70 }

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
            (.pesto, ["pesto"]),
            (.tahini, ["tahini", "hummus", "houmous"]),
            (.peanutbutter, ["peanut", "pinda", "satay", "sate"]),
            (.mustard, ["mustard", "mosterd", "honey mustard"]),
            (.honey, ["honey", "honing", "maple"]),
            (.tomatotin, ["tomato", "tomaat", "salsa", "marinara", "harissa", "sambal", "romesco"]),
            (.yoghurt, ["yoghurt", "yogurt", "tzatziki", "raita"]),
            (.vinegar, ["vinaigrette", "balsamic", "balsamico"]),
            (.oliveoil, ["olive oil", "olijfolie"]),
        ]) ?? .sauce
    }

    static func forSection(_ section: String) -> Food {
        let s = section.lowercased()
        if s.contains("meat") || s.contains("fish") { return .salmon }
        if s.contains("dairy") || s.contains("egg") { return .milk }
        if s.contains("spice") { return .spicejar }
        if s.contains("pantry") { return .tomatotin }
        if s.contains("bread") || s.contains("bakery") { return .bread }
        if s.contains("frozen") { return .frozenveg }
        if s.contains("fruit") { return .apple }
        if s.contains("produce") { return .broccoli }
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
        // Multi-word names that would otherwise hit a broader keyword further down.
        (.coconutmilk, ["coconut milk", "coconut cream", "kokosmelk", "kokosroom"]),
        (.soysauce, ["fish sauce", "vissaus", "oyster sauce", "oestersaus"]),
        (.peanutbutter, ["peanut butter", "pindakaas"]),
        (.oliveoil, ["olive oil", "olijfolie"]),
        (.spicejar, ["smoked paprika", "paprika powder", "paprikapoeder", "black pepper", "zwarte peper",
                     "chili flakes", "chilivlokken", "chili powder", "chilipoeder"]),
        (.sweetpotato, ["sweet potato", "zoete aardappel", "pumpkin", "pompoen", "squash", "butternut"]),
        (.tomatotin, ["passata", "tomato paste", "tomatenpuree", "chopped tomato", "tomatenblokjes"]),
        (.leeks, ["spring onion", "lente-ui", "bosui"]),
        (.greenbeans, ["green bean", "sperziebo", "haricot"]),
        (.frozenveg, ["frozen veg", "diepvriesgroente", "wokgroente", "stir-fry veg", "roerbakgroente"]),
        (.whitefish, ["white fish", "witvis"]),
        (.cream, ["sour cream", "zure room", "crème fraîche", "creme fraiche", "cream cheese", "roomkaas",
                  "cooking cream", "kookroom", "slagroom"]),
        (.lettuce, ["little gem", "romaine", "iceberg"]),
        // Proteins
        (.shrimp, ["shrimp", "garnal", "prawn", "gamba", "scampi"]),
        (.tuna, ["tuna", "tonijn"]),
        (.salmon, ["salmon", "zalm", "trout", "forel", "mackerel", "makreel"]),
        (.whitefish, ["cod", "kabeljauw", "pollock", "koolvis", "hake", "heek", "tilapia", "pangasius",
                      "haddock", "schelvis", "fish", "vis"]),
        (.chickenbreast, ["chicken", "kip", "turkey", "kalkoen"]),
        (.sausage, ["sausage", "worst", "chorizo", "bacon", "spek", "ham"]),
        (.mincedmeat, ["mince", "gehakt", "meatball", "pork", "varken", "lamb", "lam"]),
        (.beef, ["beef", "rund", "steak", "biefstuk", "sukade", "brisket"]),
        (.tempeh, ["tempeh", "seitan"]),
        (.tofu, ["tofu"]),
        (.eggs, ["egg", "eieren"]),
        (.feta, ["feta", "halloumi", "paneer", "goat cheese", "geitenkaas"]),
        (.mozzarella, ["mozzarella", "burrata", "ricotta"]),
        (.cheese, ["cheese", "kaas", "parmesan", "cheddar", "gouda"]),
        (.chickpeas, ["chickpea", "kikkererwt"]),
        (.lentils, ["lentil", "linzen", "split pea", "spliterwt"]),
        (.beans, ["bean", "bonen", "edamame"]),
        (.corn, ["corn", "mais"]),
        (.stock, ["soup", "soep", "stock", "bouillon", "broth"]),
        // Carbs
        (.noodles, ["noodle", "noedel", "ramen", "udon", "soba", "mie"]),
        (.pasta, ["pasta", "orzo", "spaghetti", "penne", "macaroni", "lasagne", "gnocchi", "fusilli", "tagliatelle"]),
        (.quinoa, ["quinoa", "bulgur", "couscous", "farro", "barley", "gerst"]),
        (.rice, ["rice", "rijst", "grain"]),
        (.oats, ["oats", "haver", "granola", "muesli", "cereal"]),
        (.wraps, ["wrap", "tortilla", "pita", "naan", "flatbread"]),
        (.bread, ["bread", "brood", "bun", "bagel", "sourdough", "desem", "ciabatta", "baguette", "toast"]),
        (.potatoes, ["potato", "aardappel", "krieltjes"]),
        // Fats and pantry
        (.butter, ["butter", "boter", "ghee"]),
        (.tomatotin, ["tin", "blik", "canned"]),
        (.soysauce, ["soy", "soja", "ketjap", "miso", "sriracha", "teriyaki", "hoisin"]),
        (.vinegar, ["vinegar", "azijn", "balsamic", "balsamico"]),
        (.oliveoil, ["oil", "olie"]),
        (.pesto, ["pesto"]),
        (.tahini, ["tahini", "hummus", "houmous"]),
        (.mustard, ["mustard", "mosterd"]),
        (.honey, ["honey", "honing", "syrup", "siroop", "maple"]),
        (.sauce, ["mayo", "dressing", "aioli", "ketchup", "sauce", "saus", "jam"]),
        // Vegetables (mushrooms before dairy, so "mushroom" doesn't hit "room")
        (.mushrooms, ["mushroom", "champignon", "paddenstoel", "shiitake", "portobello"]),
        (.tomatoes, ["tomato", "tomaat", "tomaten", "radish", "radijs"]),
        (.chili, ["chili", "chilli", "jalapeño", "jalapeno", "peper", "pepper flakes"]),
        (.bellpepper, ["bell pepper", "paprika", "pepper"]),
        (.beetroot, ["beetroot", "beet", "biet"]),
        (.carrots, ["carrot", "wortel", "parsnip", "pastinaak"]),
        (.aubergine, ["aubergine", "eggplant"]),
        (.cucumber, ["cucumber", "komkommer"]),
        (.courgette, ["courgette", "zucchini"]),
        (.kale, ["kale", "boerenkool", "cavolo"]),
        (.lettuce, ["lettuce", "sla", "rucola", "arugula", "rocket", "salad"]),
        (.spinach, ["spinach", "spinazie", "greens", "chard", "snijbiet"]),
        (.herbs, ["herb", "parsley", "peterselie", "coriander", "koriander", "cilantro", "basil", "basilicum",
                  "mint", "munt", "dill", "dille", "thyme", "tijm", "rosemary", "rozemarijn"]),
        (.cauliflower, ["cauliflower", "bloemkool"]),
        (.cabbage, ["cabbage", "kool", "bok choy", "paksoi", "spruit", "sprout"]),
        (.peas, ["peas", "erwten", "doperwt", "sugar snap", "peultje"]),
        (.greenbeans, ["sperzie", "asparagus", "asperge"]),
        (.broccoli, ["broccoli", "broccolini"]),
        (.avocado, ["avocado", "guacamole"]),
        (.leeks, ["leek", "prei", "scallion", "celery", "selderij"]),
        (.ginger, ["ginger", "gember"]),
        (.oniongarlic, ["onion", "ui", "garlic", "knoflook", "shallot", "sjalot"]),
        // Fruit
        (.lemonlime, ["lemon", "citroen", "lime", "limoen"]),
        (.orange, ["orange", "sinaasappel", "mandarin", "clementine"]),
        (.berries, ["berry", "berries", "bes", "bessen", "aardbei", "blueberr", "frambo"]),
        (.banana, ["banana", "banaan"]),
        (.apple, ["apple", "appel", "pear", "peer"]),
        // Dairy
        (.yoghurt, ["yoghurt", "yogurt", "kwark", "skyr", "cottage"]),
        (.cream, ["cream", "room"]),
        (.milk, ["milk", "melk"]),
        // Flavourings and extras
        (.salt, ["salt", "zout"]),
        (.spicejar, ["spice", "kruiden", "cumin", "komijn", "turmeric", "kurkuma", "cinnamon", "kaneel",
                     "oregano", "curry", "kerrie"]),
        (.sesame, ["sesame", "sesam", "seed", "zaden", "zaad"]),
        (.nuts, ["nut", "noten", "cashew", "walnut", "almond", "amandel", "peanut", "pinda", "crackers", "chips"]),
        (.chocolate, ["chocolate", "chocola", "cacao", "cocoa", "dates", "dadels"]),
    ]
}
