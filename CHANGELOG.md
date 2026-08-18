# Change log

## 2026-08-18 — Production frontend authentication fix

- Rebuilt and republished the World Connect Flutter web client after detecting
  that a build made with the development defaults had been uploaded to the
  production bucket.
- The production bundle now embeds
  `https://world-connect-api.alicenbob.com`; it no longer points at
  `localhost:8000`, so login and signup work from other devices.
- Replaced the accidentally served MBA bundle in the private `world-connect`
  S3 bucket and invalidated CloudFront distribution `E2PUH1K5CL3QPB`.
- Applied no-cache headers to the web shell and verified the live title,
  production API reference, and `/health` endpoint.

## 2026-08-17 — Production release

- Published the Flutter web release to the private `world-connect` S3 bucket and invalidated CloudFront.
- Deployed the FastAPI backend through AWS Systems Manager to the containerized EC2 stack.
- Confirmed the production endpoints:
  - Frontend: `https://world-connect.alicenbob.com`
  - API health: `https://world-connect-api.alicenbob.com/health`
- Confirmed the wildcard `*.alicenbob.com` ACM certificate is active on the CloudFront frontend and Caddy API edge.
- Applied the PostgreSQL compatibility migration for persisted appearance preferences, administrator flags, and reply image URLs.
- Provisioned the protected production administrator account out-of-band; credentials are intentionally not stored in Git.
- Verified the edge container uses `/opt/world-connect/deploy`, avoiding the previous stale deployment path.
- Corrected the production CORS environment mapping so browser authentication from the deployed frontend is accepted.
- Reordered the administrator navigation to Home, Newsletters, Friends, Admin, Profile. Non-admin navigation remains Home, Newsletters, Friends, Profile.

The deployment preserves the production database and uploaded media. Secrets, passwords, tokens, and deployment environment files are not committed.
