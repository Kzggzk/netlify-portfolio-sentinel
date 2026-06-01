# Netlify Portfolio Sentinel

Netlify Portfolio Sentinel is a macOS menu bar monitor for a large Netlify portfolio. It keeps a fast view of all sites, deploy velocity, failed deploys, account quota signals, and bandwidth-risk fallbacks so unexpected traffic or deploy cost does not stay invisible.

## Quickstart

```bash
git clone https://github.com/Kzggzk/netlify-portfolio-sentinel.git
cd netlify-portfolio-sentinel
./script/build_and_run.sh
```

Then open the `NF` menu bar item and save a Netlify personal access token in Keychain.

## Install, Run, Deploy

Install:

```bash
swift build
```

Run:

```bash
./script/build_and_run.sh
```

Package:

```bash
./script/package_release.sh 0.1.0
```

## CLI

Offline smoke:

```bash
swift run sentinelctl demo
```

Live smoke:

```bash
export NETLIFY_AUTH_TOKEN=...
export NETLIFY_ACCOUNT_SLUG=baofang1990
swift run sentinelctl snapshot --account baofang1990 --days 7 --limit 160
```

## Architecture

- `src/Core`: Netlify API client, models, usage extraction, risk scoring, cache, Keychain helper.
- `src/App`: AppKit status item and SwiftUI dashboard.
- `src/CLI`: `sentinelctl` terminal smoke runner.
- `tests/CoreTests`: API parsing, pagination, usage extraction, and risk scoring tests.
- `script`: one-command build/run, package, icon generation, and API smoke scripts.
- `docs`: API surface, installation, and extension guide.

## Configuration

Use the in-app token field or `NETLIFY_AUTH_TOKEN` for CLI runs. See `.env.example` for all supported variables. Real secrets must stay out of git.

## FAQ

Why does bandwidth sometimes say unavailable?

Netlify's stable public API does not guarantee per-site bandwidth fields. The app surfaces account capability metrics when present, and otherwise switches to deploy volume, failed deploys, and file footprint risk.

Does the app change Netlify sites?

No. Version `0.1.0` is read-only.

Can another Mac pick this up?

Yes. Clone the GitHub repo or use the iCloud folder, run `./script/build_and_run.sh`, then add a Netlify token on that Mac.
