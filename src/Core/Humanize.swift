import Foundation

public enum Humanize {
    public static func bytes(_ value: Int64?) -> String {
        guard let value else { return "unknown" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    public static func ratio(_ value: Double?) -> String {
        guard let value else { return "unknown" }
        return "\(Int((value * 100).rounded()))%"
    }

    public static func compactDate(_ iso: String?) -> String {
        guard let date = DateParser.parse(iso) else { return "unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
