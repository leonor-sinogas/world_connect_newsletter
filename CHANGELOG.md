# Change log

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
