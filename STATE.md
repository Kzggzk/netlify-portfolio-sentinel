# Netlify Portfolio Sentinel STATE

## Product Definition

Netlify Portfolio Sentinel is a macOS menu bar app for Fangbao's Netlify portfolio. It shows all Netlify sites, recent deploy activity, failed deploys, account quota signals, and bandwidth-risk fallbacks in one dropdown so unexpected popularity or deploy churn can be noticed before cost or availability damage.

## Scope Lock

- Target user: Fangbao, moving across multiple Macs and Codex sessions.
- Core value: quick Netlify cost and deploy-risk awareness from the menu bar.
- Platform: macOS 13+ SwiftPM app bundle, plus CLI smoke runner.
- Auth: Netlify personal access token stored in macOS Keychain; CLI can use `NETLIFY_AUTH_TOKEN`.
- Data: Netlify sites, deploys, optional current deploy file footprints, account capabilities.
- Non-goals in v0.2.0: destructive Netlify controls, auto-disable sites, App Store distribution.

## Assumptions

- The Netlify team slug defaults to `baofang1990`.
- Stable public Netlify API may not expose per-site real bandwidth; app must explicitly degrade and show risk proxies.
- Read-only monitoring is safer than automated site disabling for the first versions.
- GitHub owner is `Kzggzk` based on local git config and Netlify connected account.

## Architecture

- `Package.swift`: SwiftPM products for core library, macOS app, and `sentinelctl`.
- `src/Core/Models.swift`: codable Netlify data, usage, risk, settings, and snapshot models.
- `src/Core/NetlifyAPIClient.swift`: authenticated REST client with pagination and error handling.
- `src/Core/Concurrency.swift`: `Array.concurrentMap(maxConcurrency:)` — ordered, bounded fan-out primitive.
- `src/Core/NetlifySnapshotService.swift`: builds a portfolio snapshot via a bounded concurrent deploy fan-out, with honest per-site fetch-failure tracking.
- `src/Core/RiskScorer.swift`: converts quota, deploy, failure, and file-size signals into risk levels; marks unreadable sites as `watch`/"unknown".
- `src/Core/UsageMetricExtractor.swift`: extracts account capability metrics from flexible JSON.
- `src/Core/SnapshotCache.swift`: local JSON cache for offline visibility.
- `src/Core/KeychainTokenStore.swift`: secure token storage; `tokenExists()` is a non-decrypting presence check; read failures are logged.
- `src/Core/Log.swift`: unified `os.Logger` handles (subsystem `com.kzg.netlify-portfolio-sentinel`). No secrets are ever logged.
- `src/App`: AppKit menu bar controller and SwiftUI dropdown dashboard; token is resolved off the main actor so Keychain prompts never freeze the UI.
- `src/CLI/main.swift`: terminal smoke runner.
- `tests/CoreTests`: core unit + async API tests, concurrency primitive tests, and end-to-end snapshot-service tests (including failure handling).
- `script/build_and_run.sh`: canonical build, bundle, xattr-strip, ad-hoc sign, launch, verify entrypoint.
- `script/package_release.sh`: release ZIP builder (also strips xattrs + signs).
- `script/generate_icon.swift`: generated `.icns` app icon.
- `docs`: installation, API surface, and extension guide.

## Current Version

`0.2.0`

## Completed

### v0.1.0
- Initialized independent repo under iCloud KZG products.
- Built SwiftPM library, macOS menu bar app, CLI runner, docs, tests, scripts, and generated icon source.
- Confirmed via Netlify connector that the account has 141 visible sites and KZG Pro team.
- Generated `assets/AppIcon.icns` and the first release ZIP.
- Created GitHub repo `https://github.com/Kzggzk/netlify-portfolio-sentinel`; pushed `main`, `dev`, `codex/feature-initial-sentinel`, tag `v0.1.0`.

### v0.2.0 (current)
- LIVE FETCH CONFIRMED: the installed app fetched the real portfolio — `snapshot.json` has `totalSites: 141`, 432 deploys / 4 failed in a 30d window, account `KZG`/Pro, rate limit healthy. Bandwidth is honestly degraded (Netlify did not expose per-site bandwidth for this token).
- Refactored the snapshot pipeline (the "logic chain"): per-site deploys now load through a bounded concurrent fan-out (`Array.concurrentMap`, default 6 in flight) instead of a sequential 141-request walk — much faster, still rate-gentle.
- Honest failure handling: a site whose deploy fetch fails is marked `watch`/"risk unknown" with a clear reason, never silently counted as a safe `0`. Added `NetlifySnapshot.deployFetchFailures` + a dashboard + CLI surface.
- Observability: added `os.Logger` across monitor/keychain/api/snapshot; refresh logs requested/started/ok/aborted and Keychain read failures (no secrets).
- Keychain robustness: presence checks use a non-decrypting `tokenExists()` (no prompt spam from SwiftUI); token resolution moved off the main actor; refresh distinguishes "no token" from "stored but unreadable by this build".
- Build/launch fix: `build_and_run.sh` and `package_release.sh` now `xattr -cr` + ad-hoc `codesign` the bundle, so apps launch from the iCloud folder (previously failed with RBSRequestErrorDomain Code=5 / POSIX 162).
- `swift test`: 12 tests, 0 failures. Release `netlify-portfolio-sentinel-0.2.0-macos.zip` built and signature-verified.

## Next

1. (User action) Re-enable LIVE refresh in the rebuilt app: on the menu bar `NF`, either approve the macOS Keychain prompt ("Always Allow") or paste the Netlify token again and Save. A successful refresh rewrites `~/.netlify-portfolio-sentinel/snapshot.json` with `deployFetchFailures` and current data.
2. Sign the app with a stable Developer ID so the Keychain token survives app updates/rebuilds without re-entry (root cause of the cross-signature prompt).
3. Add launch-at-login toggle and notification preferences.
4. Add historical snapshot trend UI.
5. Add CLI Keychain read so `sentinelctl` works without exporting `NETLIFY_AUTH_TOKEN` (note: cross-signature prompt applies).

## Near-Term Upgrade Path

- Add historical snapshots and small trend lines.
- Add macOS notifications for high/critical quota or deploy spikes.
- Add per-site file footprint refresh on demand from the row context menu.
- Multi-page deploy pagination per site (today the lookback uses deploys page 1, up to 100, which can truncate very hot sites over long windows).

## Mid-Term Upgrade Path

- Add a lightweight companion web dashboard for phone viewing.
- Add Netlify Analytics or billing endpoint support if Netlify exposes bandwidth data to the token.
- Add signed Developer ID release automation.

## Long-Term Upgrade Path

- Multi-provider cost sentinel: Netlify, Vercel, Cloudflare, Render.
- Revenue-risk mapping: connect site traffic to monetization status and portfolio priority.
- Team mode with Slack/email push alerts.

## Three Future Branches

- `branch/audit-mode`: immutable daily Netlify portfolio audit reports.
- `branch/cost-firewall`: alert-first controls for pausing deploy loops before cost blowups.
- `branch/portfolio-command-center`: add mobile web dashboard and provider comparisons.

## Known Issues

- Cross-signature Keychain: an unsigned rebuild / fresh install has a different code signature than the binary that saved the token, so macOS prompts (or denies) on first read. Mitigated by a clear status message + logging; real fix is stable signing (see Next #2).
- Real per-site bandwidth depends on Netlify API availability; v0.2.0 marks degraded mode if absent.
- Release is locally bundled and ad-hoc signed; another Mac needs right-click → Open on first run.
- No background launch agent yet.
- `log show` returned no os_log output in the build session's environment (capture appears restricted here); logging is implemented and compiles, and a standalone Logger call executed without error.

## Technical Debt

- Deploy fetch uses page 1 (up to 100) per site; long lookbacks on very hot sites may undercount. Add pagination when needed.
- App UI has no screenshot-tested visual baseline yet.
- Keychain helper is covered indirectly by build, not unit-tested with a throwaway keychain item.
- No Developer ID signing/notarization yet.

## Environment And Commands

```bash
cd "/Users/fangbao/Library/Mobile Documents/com~apple~CloudDocs/KZG/products/netlify-portfolio-sentinel"
swift test
./script/build_and_run.sh --verify
swift run sentinelctl demo
NETLIFY_AUTH_TOKEN=... NETLIFY_ACCOUNT_SLUG=baofang1990 swift run sentinelctl snapshot --account baofang1990 --days 7 --limit 160
./script/package_release.sh 0.2.0
# diagnostics
security find-generic-password -s com.kzg.netlify-portfolio-sentinel -a netlify-auth-token >/dev/null 2>&1 && echo token_present || echo token_missing
test -f "$HOME/.netlify-portfolio-sentinel/snapshot.json" && jq '{generatedAt,totalSites,totalDeploysInLookback,failedDeploysInLookback,deployFetchFailures,degradedReason}' "$HOME/.netlify-portfolio-sentinel/snapshot.json" || echo no_snapshot_cache
log show --last 10m --predicate 'subsystem == "com.kzg.netlify-portfolio-sentinel"' --style compact
```

## Resume Protocol

Any new terminal or Codex session:

1. Clone or open the repo (GitHub or the iCloud folder).
2. Read `STATE.md`.
3. Run `swift test` (expect 12 passing).
4. Run `./script/build_and_run.sh --verify`.
5. If live data is needed and the menu bar shows "stored but unreadable", re-enter the token in the `NF` field (cross-signature Keychain).
6. Continue from `Next`, then update `STATE.md` and commit before stopping.

## Iteration Log

- 2026-06-02: Created v0.1.0 architecture and first implementation skeleton after confirming Netlify account visibility and API constraints.
- 2026-06-02: Fixed Swift 6 concurrency build issues, generated icon, passed tests, launched menu bar app, packaged release ZIP, and created GitHub repo.
- 2026-06-02 (v0.2.0): Confirmed live fetch of 141 sites. Refactored snapshot logic chain to bounded concurrent fan-out with honest fetch-failure tracking; added unified logging; fixed Keychain access pattern (non-prompting presence check, off-main-actor token resolution); fixed iCloud bundle launch (xattr strip + ad-hoc sign in build/release scripts). 12 tests green.

## Handoff Prompt

Copy/paste to next terminal: `cd "/Users/fangbao/Library/Mobile Documents/com~apple~CloudDocs/KZG/products/netlify-portfolio-sentinel" && sed -n '1,240p' STATE.md && swift test && ./script/build_and_run.sh --verify`
