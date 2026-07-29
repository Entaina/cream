---
name: cream-dev
description: How to run, build and debug the Cream CRM app locally — docker compose database, Rails server, Tailwind build, seeds and login credentials. Also covers production auto-deploy on push to main (GHCR + SSH). Use whenever starting the app, running migrations, reseeding, troubleshooting the dev environment, or deploying/updating production.
---

# Cream — Development environment

Rails 8.1 + Tailwind CSS v4 + PostgreSQL 16 (Docker Compose) + importmap/Stimulus/Turbo. No Node build step.

## Configuration

Local settings live in `.env` at the project root (copy from `.env.example` on first setup). Loaded automatically via `dotenv-rails` in development and test.

| Variable | Purpose |
|----------|---------|
| `PORT` | Rails server port (Puma) |
| `CREAM_DATABASE_HOST/PORT/USER/PASSWORD` | PostgreSQL connection (Docker Compose `db` service) |
| `CREAM_SEED_ADMIN_EMAIL/PASSWORD` | Admin demo user for `db:seed` and login |
| `CREAM_SEED_MEMBER_EMAIL/PASSWORD` | Member demo user |
| `CREAM_APP_URL` | Base URL for browser verification (`cream-playwright` skill) |

```bash
cp .env.example .env   # first time only
```

For shell commands outside Rails (e.g. Playwright), load the file first: `set -a && source .env && set +a`.

## Start everything

```bash
docker compose up -d          # PostgreSQL (host/port/user/pass from .env)
bin/rails db:prepare          # create + migrate if needed
bin/rails db:seed             # recreates the "Cream Demo" workspace (idempotent, wipes only that workspace)
bin/rails tailwindcss:build   # required after editing any view/css if not running the watcher
bin/rails server -d           # daemonized dev server on $CREAM_APP_URL (PORT from .env)
```

`bin/dev` runs server + tailwind watcher in foreground (foreman, reads `PORT` from `.env`). For agent work prefer the daemonized commands above.

Stop daemonized server: `kill $(cat tmp/pids/server.pid)`. Logs: `tail -f log/development.log`.

## Login credentials (seeded)

Values come from `.env` (`CREAM_SEED_*`). After `db:seed`, the console prints the admin email/password pair.

## Skills (shared between Claude Code and Cursor)

Skills live ONLY in `.claude/skills/`. `.cursor/skills` is a symlink to `../.claude/skills` so both tools share the same skills:

- Create/edit skills always under `.claude/skills/<name>/SKILL.md` — never put real files inside `.cursor/skills`.
- If the symlink is missing, recreate it: `mkdir -p .cursor && ln -s ../.claude/skills .cursor/skills`.

## User manual

End-user documentation: [`USER_MANUAL.md`](../../../USER_MANUAL.md) (English) and [`MANUAL_USUARIO.md`](../../../MANUAL_USUARIO.md) (Spanish). When shipping UI changes, follow skill `cream-user-manual` to keep both in sync.

## Tests

The test suite uses **RSpec** (not Minitest). Request specs live in `spec/requests/`, model specs in `spec/models/`. Fixtures are in `spec/fixtures/`.

```bash
bin/rails db:test:prepare   # if schema changed
bundle exec rspec           # run full suite
bundle exec rspec spec/requests/sessions_spec.rb  # single file
```

Conventions:
- Use RSpec (`describe`/`it`, `expect`) — all specs live under `spec/`; the `test/` directory is not used.
- Mock external HTTP calls and background jobs (Solid Queue / `deliver_later`) — do not hit real services in specs.
- `SessionHelper` (`spec/support/session_helper.rb`) provides `sign_in_as` / `sign_out` for authenticated request specs.
- `DealHelper` (`spec/support/deal_helper.rb`) provides `create_deal!`, `create_company!`, `create_person!` for deal-related specs.

### Recurring jobs (Solid Queue)

Defined in [`config/recurring.yml`](../../../config/recurring.yml). Production examples: `ScheduledReportsJob`, `AlertRulesJob` (daily alert evaluation), `GmailSyncSchedulerJob`, `StripeSyncSchedulerJob`. Run manually in dev:

```bash
bin/rails runner 'AlertRulesJob.perform_now'
```

## Lint (local — not in CI)

CI does not run RuboCop. **At the end of every change or feature**, run lint locally and fix offenses before committing:

```bash
bin/rubocop          # check
bin/rubocop -a       # auto-correct safe offenses
```

Style rules: `.rubocop.yml` (inherits `rubocop-rails-omakase`). For ERB/HTML: `bundle exec herb parse <file>`.

## Gotchas

- **Email (dev):** Action Mailer usa Mailbin. Tras invitar a alguien en Team, abre `http://localhost:$PORT/mailbin` (p. ej. `http://localhost:3030/mailbin`).
- **Email (prod):** requiere variables `SMTP_*` y `MAILER_FROM` en el `.env` del servidor (ver `deploy/README.md`).
- **Google OAuth (dev):** si `CREAM_APP_URL` es `https://` (ngrok), abre la app con esa URL, no `http://localhost`. Si trabajas solo en local, pon `CREAM_APP_URL=http://localhost:3030` y usa esa redirect URI en Google Cloud Console.
- Tailwind v4: utilities are defined in `app/assets/tailwind/application.css` with `@theme` tokens (ink, line, canvas, accent). You CANNOT `@apply` a custom class inside another (`@apply btn` fails the build). Dynamic classes like `bg-<%= color %>-500` need the `@source inline(...)` safelist already present there.
- The user wants backing services via docker compose only — never `sudo systemctl`.

## Production deployment

Production runs on your server (set `CREAM_SERVER_HOST`, user **`deploy`**, stack in **`/home/deploy/cream`**). Domain example: **`crm.example.com`**.

Full docs: [`deploy/README.md`](../../../deploy/README.md).

### Auto-deploy (push to `main`)

Workflow [`.github/workflows/docker.yml`](../../../.github/workflows/docker.yml):

```
push main → build image → ghcr.io/entaina/cream:latest → SSH deploy → docker compose pull/up web
```

- GHCR packages are **private** — server needs `docker login ghcr.io` (handled in the deploy job).
- Deploy job uses GitHub environment **`production`** (not repository secrets).
- Required **environment secrets**: `SSH_HOST`, `SSH_USER`, `SSH_PRIVATE_KEY`, `GHCR_READ_TOKEN`, `GHCR_USERNAME`.
- Optional: **Required reviewers** on the `production` environment to approve each deploy.

### Manual deploy on server

```bash
ssh deploy@YOUR_SERVER
cd ~/cream
docker compose pull web
docker compose up -d web
docker compose ps
curl -I https://crm.example.com/up
```

### First-time / reprovision from local

```bash
export CREAM_SERVER_HOST='YOUR_SERVER'
export CREAM_SERVER_PASSWORD='...'
export CREAM_DATABASE_PASSWORD='...'   # strong password, required
python3 deploy/bin/provision-server.py
```

Copies `deploy/docker-compose.yml` + `.env` to `/home/deploy/cream`. Falls back to building the image on-server if GHCR pull is denied (`CREAM_BUILD_ON_SERVER=1`).

### Production stack (not the repo-root `docker-compose.yml`)

| Service | Role |
|---------|------|
| `traefik` v3.6+ | HTTPS + Let's Encrypt (needs 3.6+ with Docker 29) |
| `web` | `ghcr.io/entaina/cream:latest` — Thruster + Puma, Solid Queue in Puma |
| `db` | PostgreSQL 16, volume `pgdata` |

Secrets live only in `/home/deploy/cream/.env` on the server (from `deploy/.env.production.example`). Never commit production `.env`.

### Verify production UI

Use `cream-playwright` with `CREAM_APP_URL=https://crm.example.com` (or override in shell for that session).
