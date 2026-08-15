# World Connect

A reply-able newsletter app for keeping up with friends around the world.

World Connect lets people create newsletters, publish titled issues with PNG/JPG images, reply with short text or an image, and build a private social graph around subscriptions.

## Architecture

- `backend/`: Python 3.13, FastAPI, SQLAlchemy, Argon2id password hashing, opaque bearer sessions
- `frontend/`: Flutter app targeting iOS, macOS, and Chrome/web
- `deploy/`: Docker Compose and AWS CloudFormation for a single `t4g.micro` EC2 host
- Production database: PostgreSQL 17 in a private Docker network with an encrypted EBS-backed volume
- Edge: Caddy terminates HTTPS automatically; only ports 80 and 443 are public

The Flutter UI uses a responsive glass-style layout with separate light and dark backgrounds, per-user appearance persistence, profile images, paginated Home and Friends views, owner-controlled private-newsletter join requests, and owner-only issue deletion/ownership transfer.

## Repository layout

- `backend/app/`: FastAPI routes, SQLAlchemy models, validation, authentication, uploads, and migrations
- `backend/tests/`: isolated pytest coverage for feeds, replies, uploads, and newsletter behavior
- `frontend/lib/src/`: Flutter screens, models, API client, and session state
- `frontend/assets/`: light/dark backgrounds and branding assets
- `deploy/`: Compose, Caddy, and AWS infrastructure/deployment helpers
- `mobile/`: legacy mobile client kept for compatibility

## Local development

Run FastAPI:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload
```

Run Flutter in Chrome, macOS, or iOS:

```bash
cd frontend
flutter pub get
flutter run -d chrome
flutter run -d macos
flutter run -d ios
```

Override the backend URL when needed:

```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:8000
```

For the current local development workflow, use a fixed web port so the API CORS allow-list remains deterministic:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 19006 \
  --dart-define=API_URL=http://127.0.0.1:8000
```

The development API can use SQLite; production uses containerized PostgreSQL. Set `DATABASE_URL` in `backend/.env` and never commit that file.

## Product behavior

- Home shows five recent issues at a time from subscribed newsletters; Load more fetches five more.
- Newsletters show Join, Pending, Leave, and Invite friends actions. Private join requests are approved or denied by the owner and appear at the top of the owner’s newsletter view.
- Only current subscribers or owners can publish an issue. Issue authors can delete their own issue through the pencil action.
- Replies have a title/body/image-capable composer where applicable; short replies are limited to 300 words. Reply author avatars are shown beside the username.
- Friends are split into incoming requests, Friends, and Discover. Friends and Discover paginate five records at a time; Discover only contains users who are not connected or already pending.
- Profile supports JPG/PNG avatar upload and System/Light/Dark appearance. Appearance is saved to the authenticated user profile.

## AWS deployment

The deployment intentionally has no public PostgreSQL or SSH port. Use AWS Systems Manager Session Manager for administration.

1. Configure the AWS SSO profile and sign in:

   ```bash
   aws configure sso --profile alicenbob-sso
   aws sso login --profile alicenbob-sso
   ```

2. Create the EC2 stack in your chosen region:

   ```bash
   aws cloudformation deploy \
     --profile alicenbob-sso \
     --region us-east-1 \
     --stack-name world-connect \
     --template-file deploy/infrastructure.yaml \
     --capabilities CAPABILITY_IAM
   ```

3. Read the stable Elastic IP and instance ID:

   ```bash
   aws cloudformation describe-stacks \
     --profile alicenbob-sso \
     --region us-east-1 \
     --stack-name world-connect \
     --query 'Stacks[0].Outputs' \
     --output table
   ```

4. In Namecheap, create two `A Record` entries pointing to that Elastic IP. Use `Automatic` TTL and remove conflicting records for the same hosts:

   | Type | Host | Value |
   |---|---|---|
   | A Record | `world-connect` | the stack's `PublicIp` output |
   | A Record | `world-connect-api` | the stack's `PublicIp` output |

5. Copy `.env.example` to `deploy/.env`, set the two full hostnames and generate the database secret with `openssl rand -base64 36`. Never commit this file.

6. Transfer the repository to `/opt/world-connect` through Session Manager, then run:

   ```bash
   cd /opt/world-connect/deploy
   docker compose up -d --build
   ```

Caddy requests certificates after DNS resolves. Check with `docker compose ps` and `curl https://world-connect-api.alicenbob.com/health`.

## Verification

```bash
cd backend && .venv/bin/python -m compileall -q app
cd frontend && flutter analyze && flutter test && flutter build web --release
```

Backend tests use a temporary SQLite database through `backend/tests/conftest.py`; they do not create test accounts in the development database.

## Security notes

- Passwords are hashed with Argon2id; API sessions use opaque bearer tokens stored as hashes.
- Signup is the only application path that creates a user. Usernames and email addresses are unique.
- Uploads accept only verified PNG/JPEG files, are size-limited, and receive randomized server-side names.
- Issue/reply image URLs are normalized to HTTP(S) or local upload paths; active schemes are rejected.
- Private newsletter issues and replies require newsletter access. Owner-only operations enforce the authenticated identity server-side.
- PostgreSQL and SSH are not exposed by the deployment security group; administer EC2 through Systems Manager.
- Keep `.env`, database files, uploads, AWS credentials, and generated build output out of Git.
