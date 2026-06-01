# Netlify Portfolio Sentinel STATE

## Product Definition

Netlify Portfolio Sentinel is a macOS menu bar app for Fangbao's Netlify portfolio. It shows all Netlify sites, recent deploy activity, failed deploys, account quota signals, and bandwidth-risk fallbacks in one dropdown so unexpected popularity or deploy churn can be noticed before cost or availability damage.

## Scope Lock

- Target user: Fangbao, moving across multiple Macs and Codex sessions.
- Core value: quick Netlify cost and deploy-risk awareness from the menu bar.
- Platform: macOS 13+ SwiftPM app bundle, plus CLI smoke runner.
- Auth: Netlify personal access token stored in macOS Keychain; CLI can use `NETLIFY_AUTH_TOKEN`.
- Data: Netlify sites, deploys, optional current deploy file footprints, account capabilities.
- Non-goals in v0.1.0: destructive Netlify controls, auto-disable sites, App Store distribution.

## Assumptions

- The Netlify team slug defaults to `baofang1990`.
- Stable public Netlify API may not expose per-site real bandwidth; app must explicitly degrade and show risk proxies.
- Read-only monitoring is safer than automated site disabling for the first version.
- GitHub owner is `Kzggzk` based on local git config and Netlify connected account.

## Architecture

- `Package.swift`: SwiftPM products for core library, macOS app, and `sentinelctl`.
- `src/Core/Models.swift`: codable Netlify data, usage, risk, settings, and snapshot models.
- `src/Core/NetlifyAPIClient.swift`: authenticated REST client with pagination and error handling.
- `src/Core/NetlifySnapshotService.swift`: builds a portfolio snapshot from sites, deploys, files, and account data.
- `src/Core/RiskScorer.swift`: converts quota, deploy, failure, and file-size signals into risk levels.
- `src/Core/UsageMetricExtractor.swift`: extracts account capability metrics from flexible JSON.
- `src/Core/SnapshotCache.swift`: local JSON cache for offline visibility.
- `src/Core/KeychainTokenStore.swift`: secure token storage.
- `src/App`: AppKit menu bar controller and SwiftUI dropdown dashboard.
- `src/CLI/main.swift`: terminal smoke runner.
- `tests/CoreTests`: core unit and async API tests.
- `script/build_and_run.sh`: canonical build, bundle, launch, verify entrypoint.
- `script/package_release.sh`: release ZIP builder.
- `script/generate_icon.swift`: generated `.icns` app icon.
- `docs`: installation, API surface, and extension guide.

## Current Version

`0.1.0`

## Completed

- Initialized independent repo under iCloud KZG products.
- Built SwiftPM library, macOS menu bar app, CLI runner, docs, tests, scripts, and generated icon source.
- Confirmed via Netlify connector that current Netlify account has 141 visible sites and KZG Pro team.
- Confirmed official Netlify API supports sites/deploys/files/account endpoints and has documented pagination/rate limits.
- Generated `assets/AppIcon.icns` and release ZIP `release/netlify-portfolio-sentinel-0.1.0-macos.zip`.
- Passed `swift test`: 6 XCTest tests, 0 failures.
- Passed `./script/build_and_run.sh --verify`: app bundle launched and `NetlifyPortfolioSentinel` process verified.
- Passed `swift run sentinelctl demo` and `./script/smoke_api.sh` offline smoke.
- Created GitHub repository `https://github.com/Kzggzk/netlify-portfolio-sentinel`.

## Next

1. Push `main`, `dev`, `codex/feature-initial-sentinel`, and tag `v0.1.0`, then verify remote commit.
2. Run live API smoke after a Netlify PAT is saved in the app or exported as `NETLIFY_AUTH_TOKEN`.
3. Add launch-at-login toggle and notification preferences.

## Near-Term Upgrade Path

- Add historical snapshots and small trend lines.
- Add macOS notifications for high/critical quota or deploy spikes.
- Add per-site file footprint refresh on demand from the row context menu.

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

- Real per-site bandwidth depends on Netlify API availability; v0.1.0 marks degraded mode if absent.
- Release is locally bundled and unsigned; another Mac may need first-run trust approval.
- No background launch agent yet.
- Live API smoke did not run in this terminal because `NETLIFY_AUTH_TOKEN` is not exported; Netlify connector access verified account/site visibility separately.

## Technical Debt

- Snapshot fetch is intentionally sequential to stay gentle on API rate limits; can later add bounded concurrency.
- App UI has no screenshot-tested visual baseline yet.
- Keychain helper is covered indirectly by build, not unit-tested with a throwaway keychain item.

## Environment And Commands

```bash
cd "/Users/fangbao/Library/Mobile Documents/com~apple~CloudDocs/KZG/products/netlify-portfolio-sentinel"
swift test
./script/build_and_run.sh --verify
swift run sentinelctl demo
NETLIFY_AUTH_TOKEN=... NETLIFY_ACCOUNT_SLUG=baofang1990 swift run sentinelctl snapshot --account baofang1990 --days 7 --limit 160
./script/package_release.sh 0.1.0
```

## Resume Protocol

Any new terminal or Codex session:

1. Clone or open the repo.
2. Read `STATE.md`.
3. Run `swift test`.
4. Run `./script/build_and_run.sh --verify`.
5. Continue from `Next`, then update `STATE.md` and commit before stopping.

## Iteration Log

- 2026-06-02: Created v0.1.0 architecture and first implementation skeleton after confirming Netlify account visibility and API constraints.
- 2026-06-02: Fixed Swift 6 concurrency build issues, generated icon, passed tests, launched menu bar app, packaged release ZIP, and created GitHub repo.

## Handoff Prompt

Copy/paste to next terminal: `cd "/Users/fangbao/Library/Mobile Documents/com~apple~CloudDocs/KZG/products/netlify-portfolio-sentinel" && sed -n '1,220p' STATE.md && swift test && ./script/build_and_run.sh --verify`
