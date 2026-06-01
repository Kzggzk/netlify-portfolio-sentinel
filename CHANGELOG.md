# Changelog

## 0.2.0 - 2026-06-02

- Refactored the snapshot pipeline to fetch per-site deploys with a bounded
  concurrent fan-out (`Array.concurrentMap`) instead of a fully sequential walk —
  far faster across 140+ sites while staying within Netlify's rate limit.
- Deploy-fetch failures are now surfaced honestly: an unreadable site is marked
  `watch` ("risk unknown"), never silently counted as a safe `0`. Added
  `NetlifySnapshot.deployFetchFailures` and a dashboard warning.
- Added structured `os.Logger` observability across monitor/keychain/api/snapshot
  so "why won't it fetch?" is answerable from `log show` (no secrets logged).
- Fixed a latent Keychain issue: presence checks now use a non-decrypting
  `tokenExists()` instead of `readToken()`, avoiding repeated Keychain prompts
  from SwiftUI render paths. Refresh now distinguishes "no token" from
  "token stored but unreadable by this build".
- Verified live against the real Netlify account: 141 sites fetched.
- Redesigned the app icon: a smaller, well-padded macOS-style squircle with a
  clean "NF" monogram and a subtle uptrend accent (replaces the busier v0.1.0
  chart/dots/text stack).

## 0.1.0 - 2026-06-02

- Initial macOS menu bar app.
- Added Netlify REST API client for sites, deploys, files, and account capabilities.
- Added Keychain token storage and CLI smoke runner.
- Added risk scoring for deploy velocity, failed deploys, account quotas, and optional file footprints.
- Added build, run, release packaging, generated icon, README, docs, tests, and STATE.
