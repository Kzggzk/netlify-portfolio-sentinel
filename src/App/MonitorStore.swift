import Foundation
import NetlifyPortfolioSentinelCore
import SwiftUI

@MainActor
final class MonitorStore: ObservableObject {
    @Published var snapshot: NetlifySnapshot?
    @Published var isRefreshing = false
    @Published var statusMessage = "Ready"
    @Published var tokenInput = ""
    @Published var accountSlug = UserDefaults.standard.string(forKey: "accountSlug") ?? "baofang1990"
    @Published var deployLookbackDays = UserDefaults.standard.integer(forKey: "deployLookbackDays") == 0 ? 7 : UserDefaults.standard.integer(forKey: "deployLookbackDays")
    @Published var deployFetchSiteLimit = UserDefaults.standard.integer(forKey: "deployFetchSiteLimit") == 0 ? 160 : UserDefaults.standard.integer(forKey: "deployFetchSiteLimit")
    @Published var fetchFileFootprints = UserDefaults.standard.bool(forKey: "fetchFileFootprints")
    @Published var searchText = ""

    private let cache = SnapshotCache()
    private let keychain = KeychainTokenStore.shared
    private var refreshTask: Task<Void, Never>?

    init() {
        snapshot = try? cache.load()
        if keychain.readToken() != nil {
            statusMessage = snapshot == nil ? "Token saved. Refresh to load Netlify." : "Loaded cached snapshot."
        } else {
            statusMessage = "Add a Netlify personal access token to start."
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    var hasToken: Bool {
        keychain.readToken() != nil
    }

    var filteredSites: [SiteDigest] {
        guard let snapshot else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return snapshot.sites }
        return snapshot.sites.filter {
            $0.site.name.lowercased().contains(query) ||
            ($0.site.customDomain?.lowercased().contains(query) ?? false) ||
            ($0.site.url?.lowercased().contains(query) ?? false)
        }
    }

    func saveToken() {
        do {
            try keychain.saveToken(tokenInput)
            tokenInput = ""
            statusMessage = "Token saved in Keychain."
            refresh()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func clearToken() {
        do {
            try keychain.deleteToken()
            snapshot = nil
            statusMessage = "Token removed."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        guard let token = keychain.readToken() ?? ProcessInfo.processInfo.environment["NETLIFY_AUTH_TOKEN"] else {
            statusMessage = "Missing Netlify token."
            return
        }

        persistSettings()
        isRefreshing = true
        statusMessage = "Refreshing Netlify portfolio..."

        refreshTask = Task {
            do {
                let client = try NetlifyAPIClient(token: token)
                let service = NetlifySnapshotService(client: client)
                let settings = currentSettings()
                let nextSnapshot = try await service.buildSnapshot(settings: settings)
                try cache.save(nextSnapshot)
                snapshot = nextSnapshot
                statusMessage = "Updated \(nextSnapshot.totalSites) sites at \(Humanize.compactDate(nextSnapshot.generatedAt))."
            } catch {
                statusMessage = error.localizedDescription
            }
            isRefreshing = false
        }
    }

    func open(_ urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    func currentSettings() -> MonitorSettings {
        MonitorSettings(
            accountSlug: accountSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : accountSlug,
            deployLookbackDays: deployLookbackDays,
            deployFetchSiteLimit: deployFetchSiteLimit,
            fetchFileFootprints: fetchFileFootprints,
            fileFootprintSiteLimit: 12
        )
    }

    private func persistSettings() {
        UserDefaults.standard.set(accountSlug, forKey: "accountSlug")
        UserDefaults.standard.set(deployLookbackDays, forKey: "deployLookbackDays")
        UserDefaults.standard.set(deployFetchSiteLimit, forKey: "deployFetchSiteLimit")
        UserDefaults.standard.set(fetchFileFootprints, forKey: "fetchFileFootprints")
    }
}
