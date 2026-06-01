import Foundation

public enum UsageMetricExtractor {
    private static let usageKeys: Set<String> = [
        "bandwidth",
        "edge_bandwidth",
        "cdn_bandwidth",
        "bandwidth_used",
        "build_minutes",
        "builds",
        "deploys",
        "sites",
        "collaborators",
        "functions",
        "edge_functions",
        "forms"
    ]

    public static func metrics(from account: NetlifyAccount?) -> [UsageMetric] {
        guard let capabilities = account?.capabilities else { return [] }
        return capabilities.compactMap { key, value in
            metric(for: key, value: value)
        }
        .sorted { $0.label < $1.label }
    }

    private static func metric(for key: String, value: JSONValue) -> UsageMetric? {
        let normalized = key.lowercased()
        guard usageKeys.contains(normalized) || normalized.contains("bandwidth") || normalized.contains("deploy") else {
            return nil
        }

        guard let object = value.objectValue else {
            return UsageMetric(key: key, label: label(for: key), used: value.doubleValue, included: nil, unit: unit(for: key))
        }

        let used = firstNumber(in: object, keys: ["used", "current", "value", "count", "usage"])
        let included = firstNumber(in: object, keys: ["included", "limit", "quota", "allowance", "max"])

        if used == nil && included == nil { return nil }
        return UsageMetric(key: key, label: label(for: key), used: used, included: included, unit: unit(for: key))
    }

    private static func firstNumber(in object: [String: JSONValue], keys: [String]) -> Double? {
        for key in keys {
            if let direct = object[key]?.doubleValue {
                return direct
            }
        }
        for (key, value) in object {
            let lower = key.lowercased()
            if keys.contains(where: { lower.contains($0) }), let number = value.doubleValue {
                return number
            }
        }
        return nil
    }

    private static func label(for key: String) -> String {
        key
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func unit(for key: String) -> String {
        key.lowercased().contains("bandwidth") ? "bytes" : ""
    }
}
