#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift run sentinelctl demo

if [[ -n "${NETLIFY_AUTH_TOKEN:-}" ]]; then
  swift run sentinelctl snapshot --account "${NETLIFY_ACCOUNT_SLUG:-baofang1990}" --days "${NETLIFY_SENTINEL_DEPLOY_LOOKBACK_DAYS:-7}" --limit "${NETLIFY_SENTINEL_DEPLOY_SITE_LIMIT:-160}"
else
  echo "live API smoke skipped: NETLIFY_AUTH_TOKEN is not set"
fi
