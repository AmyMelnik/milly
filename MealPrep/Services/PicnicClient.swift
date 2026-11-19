import CryptoKit
import Foundation
import Observation

/// A product as shown in Picnic search results.
struct PicnicProduct: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var priceCents: Int?
    var unitQuantity: String?
    var imageId: String?

    var imageURL: URL? {
        guard let imageId else { return nil }
        return URL(string: "https://storefront-prod.nl.picnicinternational.com/static/images/\(imageId)/small.png")
    }

    var priceText: String { priceCents.map(Money.format) ?? "" }
}

struct PicnicCart {
    var totalCount: Int
    var totalPriceCents: Int
}

enum Money {
    static func format(_ cents: Int) -> String {
        String(format: "€%.2f", Double(cents) / 100)
    }
}

/// Client for Picnic's storefront API (Netherlands).
///
/// Picnic has no official public API. This uses the same endpoints as the Picnic app,
/// as documented by the open-source python-picnic-api2 library that Home Assistant uses.
/// They can change without notice. Your password is only sent to Picnic at login and is
/// never stored; the session token is kept in the Keychain.
@MainActor
@Observable
final class PicnicSession {
    enum LoginOutcome { case loggedIn, needsSecondFactor }

    enum PicnicError: LocalizedError {
        case auth(String)
        case server(String)
        case noToken

        var errorDescription: String? {
            switch self {
            case let .auth(message): "Picnic login failed: \(message)"
            case let .server(message): "Picnic: \(message)"
            case .noToken: "Picnic didn't return a session. Try logging in again."
            }
        }
    }

    private static let tokenKey = Keychain.Key.picnicToken
    private static let baseURL = "https://storefront-prod.nl.picnicinternational.com/api/15"

    /// Saved once login (and 2FA, if asked) is complete.
    private(set) var isLoggedIn: Bool
    private var token: String?
    private let deviceId: String

    init() {
        let savedToken = Keychain.get(Self.tokenKey)
        token = savedToken
        isLoggedIn = savedToken != nil
        if let saved = UserDefaults.standard.string(forKey: "picnic.deviceId") {
            deviceId = saved
        } else {
            let fresh = (0..<8).map { _ in String(format: "%02X", UInt8.random(in: 0...255)) }.joined()
            UserDefaults.standard.set(fresh, forKey: "picnic.deviceId")
            deviceId = fresh
        }
    }

    // MARK: Auth

    func login(email: String, password: String) async throws -> LoginOutcome {
        token = nil
        let secret = Insecure.MD5.hash(data: Data(password.utf8))
            .map { String(format: "%02x", $0) }.joined()
        let response = try await send("POST", "/user/login", body: [
            "key": email.trimmingCharacters(in: .whitespaces),
            "secret": secret,
            "client_id": 30100,
        ])
        if (response as? [String: Any])?["second_factor_authentication_required"] as? Bool == true {
            return .needsSecondFactor
        }
        try finishLogin()
        return .loggedIn
    }

    /// channel: "SMS" or "EMAIL"
    func sendSecondFactorCode(channel: String) async throws {
        try await send("POST", "/user/2fa/generate", body: ["channel": channel])
    }

    func verifySecondFactor(code: String) async throws {
        try await send("POST", "/user/2fa/verify", body: ["otp": code.trimmingCharacters(in: .whitespaces)])
        try finishLogin()
    }

    func logout() {
        token = nil
        isLoggedIn = false
        Keychain.set(nil, for: Self.tokenKey)
    }

    private func finishLogin() throws {
        guard let token else { throw PicnicError.noToken }
        Keychain.set(token, for: Self.tokenKey)
        isLoggedIn = true
    }

    // MARK: Shopping

    func search(_ term: String) async throws -> [PicnicProduct] {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let query = term.addingPercentEncoding(withAllowedCharacters: allowed) ?? term
        let page = try await send("GET", "/pages/search-page-results?search_term=\(query)")
        var found: [PicnicProduct] = []
        var seen = Set<String>()
        Self.collectTiles(in: page, into: &found, seen: &seen)
        return found
    }

    @discardableResult
    func add(productId: String, count: Int) async throws -> PicnicCart {
        let cart = try await send("POST", "/cart/add_product", body: ["product_id": productId, "count": count])
        return Self.parseCart(cart)
    }

    func cart() async throws -> PicnicCart {
        Self.parseCart(try await send("GET", "/cart"))
    }

    // MARK: Transport

    @discardableResult
    private func send(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> Any? {
        var request = URLRequest(url: URL(string: Self.baseURL + path)!)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("okhttp/4.9.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("30100;1.206.1-#15408", forHTTPHeaderField: "x-picnic-agent")
        request.setValue(deviceId, forHTTPHeaderField: "x-picnic-did")
        if let token { request.setValue(token, forHTTPHeaderField: "x-picnic-auth") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse

        // Picnic hands out (and refreshes) the session token in this response header.
        if let fresh = http?.value(forHTTPHeaderField: "x-picnic-auth"), !fresh.isEmpty, fresh != token {
            token = fresh
            if isLoggedIn { Keychain.set(fresh, for: Self.tokenKey) }
        }

        guard !data.isEmpty else { return nil }
        let json = try? JSONSerialization.jsonObject(with: data)

        if let dict = json as? [String: Any],
           let error = dict["error"] as? [String: Any],
           let code = error["code"] as? String,
           dict["second_factor_authentication_required"] as? Bool != true {
            let message = error["message"] as? String ?? code
            if code == "AUTH_ERROR" || code == "AUTH_INVALID_CRED" {
                if isLoggedIn { logout() }
                throw PicnicError.auth(message)
            }
            throw PicnicError.server(message)
        }
        if let status = http?.statusCode, status >= 400 {
            throw PicnicError.server("HTTP \(status)")
        }
        return json
    }

    // MARK: Parsing

    /// Search results come back as a UI page tree; products are the SELLING_UNIT_TILE nodes.
    private static func collectTiles(in node: Any?, into found: inout [PicnicProduct], seen: inout Set<String>) {
        if let dict = node as? [String: Any] {
            if dict["type"] as? String == "SELLING_UNIT_TILE",
               let unit = dict["sellingUnit"] as? [String: Any],
               let id = unit["id"] as? String,
               !seen.contains(id) {
                seen.insert(id)
                found.append(PicnicProduct(
                    id: id,
                    name: unit["name"] as? String ?? id,
                    priceCents: unit["display_price"] as? Int,
                    unitQuantity: unit["unit_quantity"] as? String,
                    imageId: unit["image_id"] as? String
                ))
                return
            }
            for value in dict.values { collectTiles(in: value, into: &found, seen: &seen) }
        } else if let array = node as? [Any] {
            for value in array { collectTiles(in: value, into: &found, seen: &seen) }
        }
    }

    private static func parseCart(_ json: Any?) -> PicnicCart {
        let dict = json as? [String: Any] ?? [:]
        return PicnicCart(
            totalCount: dict["total_count"] as? Int ?? 0,
            totalPriceCents: dict["total_price"] as? Int ?? 0
        )
    }
}
