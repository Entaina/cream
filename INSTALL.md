# Installation guide

This guide covers everything you need to run Cream locally, plus pointers for optional features and production deployment.

## Requirements

- **Ruby 3.4.3** (see `.ruby-version`; use rbenv, mise, asdf or similar)
- **Docker + Docker Compose** (for PostgreSQL 16 with pgvector)
- **Git**

No Node.js is required: the app uses importmap-rails and tailwindcss-rails, so there is no JavaScript build step.

Default ports:

| Port | Used by |
|---|---|
| 3030 | Rails server (`PORT` in `.env`) |
| 5470 | PostgreSQL container (`CREAM_DATABASE_PORT` in `.env`) |

## Local setup

```bash
git clone https://github.com/Entaina/cream.git
cd cream

# 1. Environment
cp .env.example .env          # defaults work out of the box

# 2. Database (PostgreSQL 16 + pgvector in Docker)
docker compose up -d

# 3. Dependencies
bundle install

# 4. Schema + demo data
bin/rails db:prepare db:seed

# 5. Run the app (server + Tailwind watcher)
bin/dev
```

Open http://localhost:3030 and log in with the demo credentials:

- Admin: `admin@example.com` / `creamcream`
- Member: `member@example.com` / `creamcream`

The seed creates a demo workspace with people, companies, deals, pipelines, email templates, lead forms and booking pages so you can explore every feature.

In development, outgoing email is captured by an inbox at http://localhost:3030/mailbin — nothing is actually sent.

## Environment variables

All configuration lives in `.env` (see [.env.example](.env.example) for the full annotated list).

### Basics

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `3030` | Rails server port |
| `CREAM_DATABASE_HOST` / `PORT` / `USER` / `PASSWORD` | `localhost` / `5470` / `cream` / `cream` | PostgreSQL connection (matches `docker-compose.yml`) |
| `CREAM_APP_URL` | `http://localhost:3030` | Base URL used in links, OAuth redirects and browser verification |
| `MAILER_FROM` | `Cream <noreply@example.com>` | From address for outgoing email |

### Seeds and organization

| Variable | Purpose |
|---|---|
| `CREAM_SEED_ADMIN_EMAIL` / `CREAM_SEED_ADMIN_PASSWORD` | Demo admin account created by `db:seed` |
| `CREAM_SEED_MEMBER_EMAIL` / `CREAM_SEED_MEMBER_PASSWORD` | Demo member account |
| `CREAM_ORGANIZATION_EMAIL_DOMAIN` | New users with this email domain join the organization workspace instead of getting a personal one |
| `CREAM_ORGANIZATION_WORKSPACE_NAME` | Name of that organization workspace |

### Google OAuth (optional)

Enables "Sign in with Google" and the Gmail/Calendar integrations.

| Variable | Purpose |
|---|---|
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | OAuth credentials from [Google Cloud Console](https://console.cloud.google.com/) |

Add every redirect URI you use to the OAuth client (exact match), e.g. `http://localhost:3030/auth/google_oauth2/callback`. Full walkthrough: [deploy/GMAIL_SETUP.md](deploy/GMAIL_SETUP.md).

### AI features (optional)

Sales briefings, the contextual assistant and agent memory are enabled when an API key is present.

| Variable | Default | Purpose |
|---|---|---|
| `CREAM_AI_API_KEY` | — | API key (OpenAI-compatible). AI features are hidden without it |
| `CREAM_AI_API_URL` | `https://api.openai.com/v1/responses` | OpenAI-compatible endpoint |
| `CREAM_AI_MODEL` | `gpt-4o-mini` | Model used for AI features |
| `LLMEMORY_ENCRYPTION_KEY` | — | Optional AES-256-GCM encryption at rest for agent memory |

### Backups and knowledge base (optional)

| Variable | Purpose |
|---|---|
| `GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH` | GCP service account JSON key for Drive backups — see [deploy/BACKUP_SETUP.md](deploy/BACKUP_SETUP.md) |
| `GOOGLE_DRIVE_BACKUP_FOLDER_ID` | Destination folder in a Google Shared Drive |
| `OKM_DRIVE_ID` | Shared Drive ID for the knowledge chat (uses the same service account) |

### Anti-spam (optional)

| Variable | Purpose |
|---|---|
| `TURNSTILE_SITE_KEY` / `TURNSTILE_SECRET_KEY` | Cloudflare Turnstile invisible captcha on public lead forms. Without them, forms still work with honeypot + time-trap + rate limiting |

### Legal pages (optional)

| Variable | Default | Purpose |
|---|---|---|
| `CREAM_OPERATOR_NAME` | `Example` | Operator name shown on privacy/terms pages and consent texts |
| `CREAM_PRIVACY_EMAIL` / `CREAM_LEGAL_EMAIL` / `CREAM_SUPPORT_EMAIL` | `*@example.com` | Contact addresses on legal pages |

## Tests and lint

```bash
bin/rails db:test:prepare
bundle exec rspec        # full suite; HTTP calls and jobs are mocked
bin/rubocop              # style (rubocop-rails-omakase)
```

## Optional features

| Feature | Guide |
|---|---|
| Gmail send/receive from records | [deploy/GMAIL_SETUP.md](deploy/GMAIL_SETUP.md) |
| Gmail add-on (link threads to deals from Gmail) | [deploy/GMAIL_ADDON_SETUP.md](deploy/GMAIL_ADDON_SETUP.md) |
| Database backups to Google Drive | [deploy/BACKUP_SETUP.md](deploy/BACKUP_SETUP.md) |

## Production

Production runs as Docker containers (app + PostgreSQL + Traefik for TLS) with images published to GHCR and automatic deployment via GitHub Actions on push to `main`.

See [deploy/README.md](deploy/README.md) for the full guide: server provisioning, secrets, SMTP, OAuth and troubleshooting.

## Troubleshooting

- **`bin/dev` fails with a database error** — make sure the container is up (`docker compose ps`) and `.env` matches the ports in `docker-compose.yml`.
- **Port already in use** — change `PORT` or `CREAM_DATABASE_PORT` in `.env` (and re-create the db container if you change the latter: `docker compose up -d`).
- **Seeds fail after a schema change** — reset with `bin/rails db:reset` (drops and recreates the development database).
