import Foundation
import Security

enum KeychainHelper {

    // MARK: - Save

    static func save(key: String, service: String = "co.uk.bitmoor.hookqa.apikey") {
        guard let data = key.data(using: .utf8) else { return }

        // Delete any existing item first
        delete(service: service)

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecValueData:   data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[KeychainHelper] Save failed: \(status)")
        }
    }

    // MARK: - Read

    static func read(service: String = "co.uk.bitmoor.hookqa.apikey") -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    // MARK: - Delete

    static func delete(service: String = "co.uk.bitmoor.hookqa.apikey") {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("[KeychainHelper] Delete failed: \(status)")
        }
    }
}
