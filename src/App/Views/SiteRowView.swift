import NetlifyPortfolioSentinelCore
import SwiftUI

struct SiteRowView: View {
    let digest: SiteDigest
    let openAction: () -> Void

    var body: some View {
        Button(action: openAction) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle()
                        .fill(tint)
                        .frame(width: 9, height: 9)
                    Text(digest.site.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text("\(digest.deploysInLookback)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(digest.site.customDomain ?? digest.site.url ?? "No URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(Humanize.compactDate(digest.lastDeployAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let reason = digest.riskReasons.first {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }

    private var tint: Color {
        switch digest.riskLevel {
        case .low: return .green
        case .watch: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}
