import NetlifyPortfolioSentinelCore
import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: MonitorStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
            Divider()
            if let snapshot = store.snapshot {
                summary(snapshot)
                siteList
            } else {
                emptyState
            }
            footer
        }
        .frame(minWidth: 430, minHeight: 620)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 26))
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("Netlify Portfolio Sentinel")
                    .font(.headline)
                Text(store.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                store.refresh()
            } label: {
                Image(systemName: store.isRefreshing ? "arrow.triangle.2.circlepath.circle" : "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh Netlify data")
            .disabled(store.isRefreshing)
        }
        .padding(14)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            if !store.hasToken {
                HStack {
                    SecureField("Netlify personal access token", text: $store.tokenInput)
                    Button("Save") {
                        store.saveToken()
                    }
                    .disabled(store.tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            HStack {
                TextField("Account slug", text: $store.accountSlug)
                    .textFieldStyle(.roundedBorder)
                Stepper("\(store.deployLookbackDays)d", value: $store.deployLookbackDays, in: 1...30)
                    .frame(width: 92)
                Toggle("Files", isOn: $store.fetchFileFootprints)
                    .toggleStyle(.checkbox)
            }
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search sites", text: $store.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
    }

    private func summary(_ snapshot: NetlifySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                MetricTile(title: "Sites", value: "\(snapshot.totalSites)", tint: .teal)
                MetricTile(title: "\(store.deployLookbackDays)d Deploys", value: "\(snapshot.totalDeploysInLookback)", tint: .blue)
                MetricTile(title: "Failed", value: "\(snapshot.failedDeploysInLookback)", tint: snapshot.failedDeploysInLookback > 0 ? .red : .green)
                MetricTile(title: "Risk", value: snapshot.highestRisk.rawValue.uppercased(), tint: tint(for: snapshot.highestRisk))
            }

            if !snapshot.usageMetrics.isEmpty {
                ForEach(snapshot.usageMetrics.prefix(3), id: \.key) { metric in
                    UsageMetricView(metric: metric)
                }
            }

            if let degradedReason = snapshot.degradedReason {
                Label(degradedReason, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
    }

    private var siteList: some View {
        List(store.filteredSites) { digest in
            SiteRowView(digest: digest) {
                store.open(digest.site.adminUrl ?? digest.site.url ?? digest.site.sslUrl)
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("No snapshot yet")
                .font(.headline)
            Text("Save a Netlify personal access token, then refresh.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            if store.hasToken {
                Button("Forget Token") {
                    store.clearToken()
                }
                .buttonStyle(.borderless)
            }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .font(.caption)
        .padding(10)
    }

    private func tint(for level: RiskLevel) -> Color {
        switch level {
        case .low: return .green
        case .watch: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(8)
        .background(tint.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct UsageMetricView: View {
    let metric: UsageMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(metric.label)
                    .font(.caption)
                Spacer()
                Text(Humanize.ratio(metric.ratio))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(metric.ratio ?? 0, 1))
        }
    }
}
