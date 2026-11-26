import SwiftUI

/// The state illustrations in Assets.xcassets/States: empty screens, errors, confirmations and wizard steps.
enum Illustration: String, CaseIterable {
    case avoid, cameraDenied = "camera-denied", cartAdded = "cart-added", cartPartial = "cart-partial"
    case checkout, codeSent = "code-sent", favourite, invalidKey = "invalid-key"
    case kitchenPhotos = "kitchen-photos", noPlans = "no-plans", offline, picnicLogin = "picnic-login"
    case planDeleted = "plan-deleted", planFailed = "plan-failed", planReady = "plan-ready"
    case portionS = "portion-s", portionM = "portion-m", portionL = "portion-l"
    case productNotFound = "product-not-found", review, savedPlans = "saved-plans", searching
    case swap, time, tweak, welcome, wishes

    var image: Image { Image("state-\(rawValue)") }

    /// Whether an error message is about the connection rather than the request.
    static func isOffline(_ message: String) -> Bool {
        let lower = message.lowercased()
        return ["offline", "internet connection", "network connection", "timed out", "could not connect",
                "cannot connect", "not connected"].contains(where: lower.contains)
    }

    /// The offline picture when an error message is about the connection, otherwise `fallback`.
    static func forError(_ message: String, fallback: Illustration) -> Illustration {
        isOffline(message) ? .offline : fallback
    }

    /// Small, medium or large bowl for a meal of this many kcal.
    static func portion(kcal: Int) -> Illustration {
        switch kcal {
        case ..<550: .portionS
        case ..<850: .portionM
        default: .portionL
        }
    }
}

extension Station {
    /// The station illustrations in Assets.xcassets/Stations.
    var image: Image { Image("station-\(rawValue)") }
}
