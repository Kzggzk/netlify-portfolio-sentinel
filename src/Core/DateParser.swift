import Foundation

public enum DateParser {
    private static func fractionalFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func standardFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    public static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        return fractionalFormatter().date(from: value) ?? standardFormatter().date(from: value)
    }

    public static func isoString(_ date: Date = Date()) -> String {
        fractionalFormatter().string(from: date)
    }
}
