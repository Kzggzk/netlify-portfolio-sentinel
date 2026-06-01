import Foundation
import Security
import os

public final class KeychainTokenStore: @unchecked Sendable {
    public static let shared = KeychainTokenStore()

    private let service = "com.kzg.netlify-portfolio-sentinel"
    private let account = "netlify-auth-token"

    public init() {}

    /// Reads and decrypts the stored token. May trigger a system Keychain prompt
    /// if the calling binary's signature differs from the one that saved it
    /// (e.g. after an unsigned rebuild), which is logged distinctly from "absent".
    public func readToken() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                SentinelLog.keychain.info("No stored token (item not found).")
            } else {
                SentinelLog.keychain.error("Token read failed: \(Self.describe(status), privacy: .public)")
            }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Cheap, metadata-only presence check. Does not decrypt the secret, so it
    /// will not raise a Keychain prompt — safe to call from SwiftUI render paths
    /// where `readToken()` would be both expensive and prompt-spamming.
    public func tokenExists() -> Bool {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    public func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        var query = baseQuery()

        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return }
        if status != errSecItemNotFound {
            throw KeychainError(status: status)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError(status: addStatus)
        }
    }

    public func deleteToken() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    /// Human-readable description for an `OSStatus`, e.g. "errSecInteractionNotAllowed".
    static func describe(_ status: OSStatus) -> String {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
        return "OSStatus \(status): \(message)"
    }
}

public struct KeychainError: Error, LocalizedError, Equatable {
    public let status: OSStatus

    public var errorDescription: String? {
        "Keychain operation failed with status \(status)."
    }
}
