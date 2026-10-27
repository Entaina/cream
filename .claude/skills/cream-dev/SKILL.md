---
name: cream-dev
description: How to run, build and debug the Cream CRM app locally — docker compose database, Rails server, Tailwind build, seeds and login credentials. Also covers production auto-deploy on push to main (GHCR + SSH) and installing the Gmail add-on for a Google Workspace organization. Use whenever starting the app, running migrations, reseeding, troubleshooting the dev environment, deploying/updating production, or publishing or domain-installing the Gmail add-on.
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
| `CREAM_APP_URL` | Base URL for browser verification (`cream-playwright` skill), email tracking pixels, marketing preference links, web tracking and Mailjet webhook URLs |
| `CREAM_PUBLIC_SIGNUP` | When `false`, only invited users or emails matching a workspace signup domain can register (default `true` outside production; production defaults to `false` when unset) |
| `MARKETING_DATA_RETENTION_DAYS` | Days to keep `PageView` and `EmailEvent` rows (default 180; `MarketingDataRetentionJob`) |

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

**Platform superadmin** (multi-tenant operators, not workspace admins):

```bash
bin/rails superadmin:grant[you@example.com]
```

Sign in and open **Superadmin** (lock icon in the sidebar footer) at `/superadmin` to create workspaces, set each tenant's signup email domain, and enter any workspace as admin for support.

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
- Public lead form request specs auto-import Liquid templates via `spec/support/public_lead_form_templates.rb` — **solo en test**, para tener datos mínimos en el workspace fixture.

### Lead form templates (dev)

**Fuente de verdad en runtime:** tabla `lead_form_templates` del workspace (editable por admins en **Formularios → Plantillas de formulario**). No hay fallback a disco en producción ni en desarrollo con datos reales.

- **Respeta lo que haya cambiado el usuario.** No reimportes plantillas sobre workspaces con personalización (p. ej. producción). El importer **sobrescribe el body** cuando el fichero del repo difiere — úsalo solo en contextos controlados.
- **`lib/lead_form_templates/`** = catálogo **demo** (`contacto`, `demo`, `newsletter`, `reserva` + partials/sistema) para `db:seed` y specs. Editar ahí **no** cambia formularios ya desplegados. En producción, las plantillas se crean/editan en la UI.
- **`LeadForm.available_template_keys(workspace:)`** lista solo plantillas **Página** en BD del workspace (no mezcla con el repo).
- Tras cambiar Liquid en la UI (o añadir tags nuevos en código), el admin debe **guardar la plantilla** para recompilar `submission_schema`. No asumas reimport masivo.

**Import (solo cuando proceda):**

```bash
# Workspace vacío / demo tras db:seed — NO en producción con plantillas custom
bin/rails 'lead_form_templates:import[WORKSPACE_ID]'

# Workspace de ejemplo en seed
bin/rails runner "w=Workspace.find_by(slug: ENV.fetch('CREAM_ORGANIZATION_WORKSPACE_NAME', 'Example').parameterize); LeadFormTemplates::Importer.import!(w)"
```

`db:seed` importa vía `LeadFormsExample.seed!` solo en el workspace de organización de demo. Detalle de arquitectura: skill `cream-architecture` § Lead capture forms.

### Recurring jobs (Solid Queue)

Defined in [`config/recurring.yml`](../../../config/recurring.yml). Production examples: `ScheduledReportsJob`, `AlertRulesJob` (daily alert evaluation), `GmailSyncSchedulerJob`, `StripeSyncSchedulerJob`, `JourneyRunnerJob` (every 10 min), `ScoringRecalculateJob` (daily 3am), `MarketingDataRetentionJob` (daily 4am). Run manually in dev:

```bash
bin/rails runner 'AlertRulesJob.perform_now'
bin/rails runner 'JourneyRunnerJob.perform_now'
bin/rails runner 'ScoringRecalculateJob.perform_now'
```

Marketing jobs also run in **development** (same schedule as production for journey runner, scoring and retention). Full marketing setup: skill `cream-marketing`.

## Lint (local — not in CI)

CI does not run RuboCop. **At the end of every change or feature**, run lint locally and fix offenses before committing:

```bash
bin/rubocop          # check
bin/rubocop -a       # auto-correct safe offenses
```

Style rules: `.rubocop.yml` (inherits `rubocop-rails-omakase`). For ERB/HTML: `bundle exec herb parse <file>`.

## Gotchas

- **Email (dev):** Action Mailer usa Mailbin. Campañas salen por Mailjet si el workspace lo tiene en **Settings**. El transaccional solo si además está la casilla *Usar Mailjet para el correo transaccional*. Tras invitar a alguien sin eso, abre `http://localhost:$PORT/mailbin`.
- **Email (prod):** campañas usan Mailjet del workspace si está conectado. Transaccional: Mailjet solo con la casilla; si no, `SMTP_*` / `MAILER_FROM`.
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

## Gmail add-on — install for the organization

Source and manifest: [`gmail_addon/`](../../../gmail_addon/). Step-by-step: [`deploy/GMAIL_ADDON_SETUP.md`](../../../deploy/GMAIL_ADDON_SETUP.md). Publishing the private Marketplace listing and installing it for the organization are different steps.

A Cloud project Owner can publish the listing. Only a Google Workspace **Marketplace administrator** can install it for the domain. That privilege is not the super-admin role and it is not the Cloud project Owner.

### Where it shows up

| Place | Meaning |
|-------|---------|
| [mydomainapps](https://workspace.google.com/marketplace/mydomainapps) | The private listing is **published**. People in the domain can install it themselves. This does not mean an admin installed it for the organization. |
| Admin console → **Apps → Google Workspace Marketplace apps → Apps list** | Apps an administrator **installed for the organization** or **allowlisted**. CReaM missing here means there is no domain install. Without the Marketplace administrator privilege the list is empty. |

A **test deployment** (Apps Script → Deploy → Test deployments) appears in neither list. It runs for the script owner only. Any other account sees **Necesitas acceso** / **You need access** with **Lector** / **Editor**. That page is Drive sharing for the Apps Script project, not the Gmail consent screen. Do not approve it and do not share the project. Viewer can read the source. Editor can change the code and the script properties (`CREAM_CLIENT_ID`).

### Install for the domain

1. Sign in with a Marketplace administrator account.
2. Open [mydomainapps](https://workspace.google.com/marketplace/mydomainapps), or Admin console → **Apps → Google Workspace Marketplace apps → Apps list** → **Install app**.
3. Open **CReaM** → **Admin install** → the whole organization, an OU, or groups.
4. Accept the permissions.

If policy blocks internal apps: Admin console → **Apps → Google Workspace Marketplace apps → Settings** → allow internal Marketplace apps, or add CReaM to the allowlist.

CReaM then appears under **Domain installed apps**. Each person still clicks **Connect with CReaM** once. The organization install does not replace that per-user OAuth to Cream. An install from `mydomainapps` by each user is an individual install and does not create a domain **Grant access** button.

### Scopes

| Scope | What it covers |
|-------|----------------|
| `gmail.addons.execute` | Run the add-on |
| `gmail.addons.current.message.readonly` | The open message and the other messages in that same Gmail thread |
| `script.external_request` | Call the Cream API |

The manifest does not request `gmail.readonly`. A domain install does not share the Apps Script project. Requesting that scope opens the project file (`getAuthorizationUrl()`), so users still see **You need access** / **Necesitas acceso** (Viewer/Editor) after the organization install. Do not share the project. The open thread is enough to link or create a deal.

If a later version adds some other OAuth scope, Google does not notify the admin. **Data access** shows **Partially granted**; grant it in the Admin console ([Manage data access](https://support.google.com/a/answer/172983)). Cloud Console cannot do that, and that grant still does not give access to the script file. Ship the change as a new version of the **same** deployment. Until that version is deployed, Gmail keeps running the old script, which still opens the Apps Script access page.
