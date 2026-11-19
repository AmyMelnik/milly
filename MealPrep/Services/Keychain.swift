import Foundation
import Security

/// Secrets (Anthropic API key, Picnic session token) live only in the iOS Keychain:
/// - readable only while the iPhone is unlocked,
/// - bound to this device ("ThisDeviceOnly"): never in iCloud Keychain, iCloud or device backups,
/// - never written to UserDefaults, files or logs.
enum Keychain {
    enum Key: String, CaseIterable {
        case anthropicKey = "anthropic.key"
        case picnicToken = "picnic.token"
    }

    private static let service = "com.personal.mealprep"

    private static func query(_ key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrSynchronizable as String: kCFBooleanFalse!,
        ]
    }

    @discardableResult
    static func set(_ value: String?, for key: Key) -> Bool {
        guard let value, !value.isEmpty else {
            delete(key)
            return true
        }
        let data = Data(value.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemUpdate(query(key) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query(key)
            add.merge(attributes) { $1 }
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    static func get(_ key: Key) -> String? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: Key) {
        SecItemDelete(query(key) as CFDictionary)
    }

    /// Keychain items survive deleting the app. On the first launch of a fresh install,
    /// wipe anything left over so an old key or session never comes back unexpectedly.
    static func clearIfFreshInstall() {
        let flag = "keychain.initialised"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        Key.allCases.forEach(delete)
        UserDefaults.standard.set(true, forKey: flag)
    }
}
