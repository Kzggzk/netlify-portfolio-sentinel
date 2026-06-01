import Foundation
import os

/// Centralized unified-logging handles so every layer is observable from
/// `log show --predicate 'subsystem == "com.kzg.netlify-portfolio-sentinel"'`.
///
/// Observability is a hard requirement: when a refresh silently does nothing,
/// these logs are how "why won't it fetch?" gets answered in seconds instead of
/// guesswork. Secrets (the Netlify token) are NEVER logged.
public enum SentinelLog {
    public static let subsystem = "com.kzg.netlify-portfolio-sentinel"

    public static let monitor = Logger(subsystem: subsystem, category: "monitor")
    public static let keychain = Logger(subsystem: subsystem, category: "keychain")
    public static let api = Logger(subsystem: subsystem, category: "api")
    public static let snapshot = Logger(subsystem: subsystem, category: "snapshot")
}
