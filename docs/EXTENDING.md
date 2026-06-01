# Extending The Product

Add a new data source:

1. Add typed models under `src/Core/Models.swift` or a new `src/Core/*Model.swift` file.
2. Add a fetch method to `NetlifyAPIClient`.
3. Extend `NetlifySnapshotService` to include the data in `NetlifySnapshot`.
4. Add scoring logic to `RiskScorer`.
5. Add tests in `tests/CoreTests`.
6. Add one small UI section under `src/App/Views`.

Good next extensions:

- Persist historical snapshots and draw 7-day or 30-day trend lines.
- Add notification alerts for quota ratio, failed deploy spikes, and unusually large deploys.
- Add Netlify Analytics or billing endpoints if Netlify exposes token-accessible bandwidth data for the account.
- Add a signed/notarized release workflow once an Apple Developer ID is available.

Do not add:

- Hardcoded Netlify tokens.
- Destructive site controls such as delete/disable in the first product line.
- API polling faster than the documented Netlify rate limit.
