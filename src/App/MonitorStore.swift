import Foundation
import NetlifyPortfolioSentinelCore
import SwiftUI
import os

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
        if keychain.tokenExists() {
            statusMessage = snapshot == nil ? "Token saved. Refresh to load Netlify." : "Loaded cached snapshot."
        } else {
            statusMessage = "Add a Netlify personal access token to start."
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    var hasToken: Bool {
        keychain.tokenExists()
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
            SentinelLog.monitor.info("Token saved to Keychain.")
            refresh()
        } catch {
            statusMessage = error.localizedDescription
            SentinelLog.monitor.error("Token save failed: \(error.localizedDescription, privacy: .public)")
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
        SentinelLog.monitor.notice("Refresh requested.")

        persistSettings()
        isRefreshing = true
        statusMessage = "Refreshing Netlify portfolio..."

        let settings = currentSettings()
        let keychain = self.keychain
        let cache = self.cache

        refreshTask = Task {
            // Resolve the token off the main actor: a Keychain prompt (e.g. after a
            // re-signed rebuild or first run on a new Mac) must never freeze the
            // menu bar UI while the user decides whether to grant access.
            let resolved = await Self.resolveToken(keychain: keychain)
            guard let token = resolved.token else {
                // Distinguish "no token" from "token stored but this build can't
                // read it" — the classic cross-signature Keychain-ACL case.
                let detail = resolved.itemExists
                    ? "A token is stored but this build can't read it (Keychain access denied). Re-enter your token and Save."
                    : "Missing Netlify token. Paste your Netlify token and Save."
                statusMessage = detail
                isRefreshing = false
                SentinelLog.monitor.error("Refresh aborted: \(detail, privacy: .public)")
                return
            }

            SentinelLog.monitor.notice("Refresh started (token source: \(resolved.source, privacy: .public)).")
            do {
                let client = try NetlifyAPIClient(token: token)
                let service = NetlifySnapshotService(client: client)
                let nextSnapshot = try await service.buildSnapshot(settings: settings)
                try cache.save(nextSnapshot)
                snapshot = nextSnapshot
                statusMessage = "Updated \(nextSnapshot.totalSites) sites at \(Humanize.compactDate(nextSnapshot.generatedAt))."
                SentinelLog.monitor.notice(
                    "Refresh ok: \(nextSnapshot.totalSites) sites, \(nextSnapshot.totalDeploysInLookback) deploys, \(nextSnapshot.unavailableSiteCount) unreadable."
                )
            } catch {
                statusMessage = error.localizedDescription
                SentinelLog.monitor.error("Refresh failed: \(error.localizedDescription, privacy: .public)")
            }
            isRefreshing = false
        }
    }

    /// Resolves the Netlify token on a background executor (Keychain first, then
    /// `NETLIFY_AUTH_TOKEN`), reporting the source and whether a stored item exists
    /// even when it could not be decrypted. Kept off the main actor so a Keychain
    /// access prompt cannot block the UI.
    private static func resolveToken(
        keychain: KeychainTokenStore
    ) async -> (token: String?, source: String, itemExists: Bool) {
        await Task.detached(priority: .userInitiated) {
            if let token = keychain.readToken() {
                return (token, "keychain", true)
            }
            if let env = ProcessInfo.processInfo.environment["NETLIFY_AUTH_TOKEN"], !env.isEmpty {
                return (env, "env", keychain.tokenExists())
            }
            return (nil, "none", keychain.tokenExists())
        }.value
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
