# Installation

Local developer install:

```bash
git clone https://github.com/Kzggzk/netlify-portfolio-sentinel.git
cd netlify-portfolio-sentinel
./script/build_and_run.sh
```

Token setup:

1. Open the menu bar item labeled `NF`.
2. Paste a Netlify personal access token.
3. Keep account slug as `baofang1990` unless the Netlify team changes.

CLI smoke test:

```bash
export NETLIFY_AUTH_TOKEN=...
export NETLIFY_ACCOUNT_SLUG=baofang1990
./script/smoke_api.sh
```

Release package:

```bash
./script/package_release.sh 0.2.0
```

The distributable ZIP appears under `release/`.
