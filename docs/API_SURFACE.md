# API Surface

Netlify Portfolio Sentinel uses the stable Netlify REST API base:

`https://api.netlify.com/api/v1`

Required authorization:

`Authorization: Bearer <NETLIFY_PERSONAL_ACCESS_TOKEN>`

Current endpoints:

- `GET /sites?page=N&per_page=100`: complete site inventory.
- `GET /sites/{site_id}/deploys?per_page=100`: recent deploy state and deploy counts.
- `GET /sites/{site_id}/files`: optional current deploy file footprint for a bounded subset of sites.
- `GET /accounts/{account_slug}`: account/team capabilities when available.

Bandwidth limitation:

The public API documentation and OpenAPI spec expose site, deploy, file, and account capability data. Per-site real bandwidth is not guaranteed in the stable public API response. The product therefore surfaces real account quota metrics when the token response includes them, then clearly degrades to deploy velocity, failed deploys, and file-footprint risk when bandwidth is not exposed.

Rate-limit design:

- Netlify documents 500 requests per minute for most endpoints.
- The app defaults to a 15-minute refresh cadence.
- Deploy scans are capped by `deployFetchSiteLimit`.
- File footprint scans are opt-in and capped separately.
