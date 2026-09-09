# Cream — production deployment

Docker Compose stack with **Rails** (image on GHCR) and **PostgreSQL 16 with pgvector**, published behind the server's **shared Traefik** (separate Traefik stack (see your infra docs)), which terminates HTTPS with Let's Encrypt and routes by domain.

## Architecture

```
Internet → Traefik (:443, separate stack — infra repo)
                │ external network `proxy`
                └→ web (:80, Thruster+Puma) → db (PostgreSQL + pgvector)
                        ↑
                 ghcr.io/entaina/cream:latest
```

Traefik is not part of this stack: it lives in `~/infra` on the server and serves all the apps on the machine (cream, academia…). This compose file only requires the external Docker network `proxy` to exist, and connects the `web` service to it with routing labels.

The image is built in GitHub Actions (`.github/workflows/docker.yml`) on every push to `main`, published to GHCR and **deployed automatically** to the server (`/home/deploy/cream`)

## Automatic deployment (push to `main`)

Flow:

```
push main → build image → push GHCR → SSH to deploy@server → docker compose pull/up web
```

### Secrets in GitHub (environment `production`)

Create the environment in **Settings → Environments → New environment → `production`**.

Optional: enable **Required reviewers** if you want to approve each deploy manually before it reaches the server.

Add these **environment secrets** (not repository secrets):

| Secret | Value |
|---|---|
| `SSH_HOST` | `<SERVER_IP>` |
| `SSH_USER` | `deploy` |
| `SSH_PRIVATE_KEY` | private key of the deploy key (see below) |
| `GHCR_READ_TOKEN` | PAT with `read:packages` scope |
| `GHCR_USERNAME` | GitHub user that owns the PAT (e.g. your GitHub username) |

In GitHub → repo **Entaina/cream** → Settings → Environments → **production** → Environment secrets.

### Deploy key on the server (one time)

On your machine:

```bash
ssh-keygen -t ed25519 -f cream-deploy -N "" -C "github-actions-cream"
```

Copy the public key to the server:

```bash
ssh deploy@<SERVER_IP> 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'
cat cream-deploy.pub | ssh deploy@<SERVER_IP> 'cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

In GitHub → repo **Entaina/cream** → Settings → Environments → **production** → Environment secrets → `SSH_PRIVATE_KEY` = contents of `cream-deploy` (no passphrase).

If you enable **Required reviewers** on the `production` environment, every push to `main` will require approval before deploying.

## Server requirements

- Docker and the Docker Compose plugin
- `deploy` user in the `docker` group
- Domain DNS pointing to the server's IP (ports 80 and 443 open)
- External `proxy` network created (`docker network create proxy`) and the Traefik stack (separate Traefik stack, see your infra docs) up and running (see its README)

## Installation (first time)

### Initial provisioning from local

From your local machine, with SSH access to the server:

```bash
export CREAM_SERVER_PASSWORD='...'   # server SSH password
python3 deploy/bin/provision-server.py
```

The script copies `docker-compose.yml` and creates `.env` in `/home/deploy/cream` using `config/master.key` and your local `.env`. If GHCR does not have an image yet (or the pull is denied), it builds the image on the server from the local code (`CREAM_BUILD_ON_SERVER=1` always forces the build).

### 1. Prepare the directory on the server

The stack lives in `/home/deploy/cream` under the `deploy` user (which must belong to the `docker` group):

```bash
mkdir -p ~/cream
cd ~/cream
```

Copy from your local machine (from the repo root):

```bash
scp deploy/docker-compose.yml deploy/.env.production.example deploy@SERVER:~/cream/
```

### 2. Create `.env` with real secrets

On the server:

```bash
cd /home/deploy/cream
cp .env.production.example .env
chmod 600 .env
nano .env   # fill in all the values
```

Required variables:

| Variable | Source |
|---|---|
| `CREAM_DOMAIN` | Public domain (e.g. `crm.example.com`) |
| `LETSENCRYPT_EMAIL` | Email for Let's Encrypt notices |
| `RAILS_MASTER_KEY` | Contents of the repo's `config/master.key` |
| `CREAM_DATABASE_PASSWORD` | Strong password for PostgreSQL |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Google Cloud Console |
| `GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH` / `GOOGLE_DRIVE_BACKUP_FOLDER_ID` | Backups to Drive — see [`BACKUP_SETUP.md`](BACKUP_SETUP.md) |
| `MAILER_FROM` | Visible sender (e.g. `Cream <noreply@example.com>`) |
| `SMTP_ADDRESS` / `SMTP_PORT` | `in-v3.mailjet.com` / `587` |
| `SMTP_USERNAME` / `SMTP_PASSWORD` | Mailjet API Key and Secret Key (see below) |
| `SMTP_DOMAIN` | Sender domain (e.g. `example.com`) |

`CREAM_APP_URL` is not needed in `.env`: the compose file derives it as `https://${CREAM_DOMAIN}`.

### SMTP with Mailjet

1. Create an account at [app.mailjet.com](https://app.mailjet.com).

2. Get the SMTP credentials:
   - **Account settings → SMTP and SEND API settings**
   - **API Key** → `SMTP_USERNAME`
   - **Secret Key** → `SMTP_PASSWORD` (only shown when created; save it)

3. Verify the sender domain (`example.com`):
   - In Mailjet: **Account settings → Senders & Domains**
   - Add the domain and configure the **SPF** and **DKIM** DNS records that Mailjet provides
   - Without this, emails may go to spam or be rejected

4. Set a verified sender in `MAILER_FROM` (it must match an authorized sender in Mailjet):

   ```bash
   MAILER_FROM="Cream <noreply@example.com>"
   SMTP_ADDRESS=in-v3.mailjet.com
   SMTP_PORT=587
   SMTP_USERNAME=your_public_api_key
   SMTP_PASSWORD=your_secret_key
   SMTP_DOMAIN=example.com
   SMTP_AUTHENTICATION=plain
   ```

5. On the server, edit `/home/deploy/cream/.env`, then restart:

   ```bash
   docker compose up -d
   ```

6. Test by sending an invitation from **Team** in production. Check in Mailjet **Stats** whether the send shows up.

**Local development:** do not use SMTP. The app sends emails to **Mailbin** (`http://localhost:3030/mailbin` with the `PORT` from your `.env`).

### 3. Log in to GHCR (if the package is private)

Create a [Personal Access Token](https://github.com/settings/tokens) with `read:packages` scope, and on the server:

```bash
echo "YOUR_GITHUB_PAT" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

Alternative: in GitHub → Packages → cream → Package settings → Change visibility → Public.

### 4. Google OAuth

In [Google Cloud Console](https://console.cloud.google.com/), add the login redirect URI:

```
https://CREAM_DOMAIN/auth/google_oauth2/callback
```

### 4b. Gmail "send as Gmail" (feature `gmail_sync`, phase 1a)

So users can send emails from their own Gmail account (same
`GOOGLE_CLIENT_ID`/`SECRET` as the login). Since `example.com` is Google Workspace,
the consent screen is set to **Internal**: no verification, no user limit
and no token expiration.

**Full step-by-step guide (console in Spanish, real values, troubleshooting and manual test):** [`GMAIL_SETUP.md`](GMAIL_SETUP.md).

### 5. Bring up the stack

```bash
cd /home/deploy/cream
docker compose pull
docker compose up -d
```

The app's entrypoint runs `db:prepare` on startup (creates and migrates the production, cache, queue and cable databases).

Check the status:

```bash
docker compose ps
docker compose logs -f web
curl -I https://CREAM_DOMAIN/up
```

### 6. (Optional) Demo data

If you filled in the `CREAM_SEED_*` variables in `.env`:

```bash
docker compose exec web bin/rails db:seed
```

`db:seed` imports **demo example** Liquid templates into the organization workspace (from `lib/lead_form_templates/` in the image) and creates example lead forms when `CREAM_ORGANIZATION_*` is configured.

### 7. Lead capture form templates (Liquid)

Public forms at `/f/:slug` render **Liquid stored in the database** (`lead_form_templates`), not ERB files. The repo ships a small **demo catalog** under `lib/lead_form_templates/public/lead_forms/` (`contacto`, `demo`, `newsletter`, `reserva` + partials). It is imported only by `db:seed` on the organization workspace — **do not re-import on production** workspaces with customized templates.

Admins create and edit templates in the CRM (**Formularios → Plantillas de formulario**). If a form's `template_key` has no matching row in the workspace DB, the public URL returns **404**.

Manual import (empty workspace / local demo only):

```bash
docker compose exec web bin/rails 'lead_form_templates:import[WORKSPACE_ID]'
```

## Updating the app

After a push to `main`, GitHub Actions deploys to the `production` environment (if the environment secrets are configured).

Manual deployment (if needed):

```bash
cd ~/cream
docker compose pull db web
docker compose up -d db web
```

### PostgreSQL with pgvector (agent memory)

The DB uses the `pgvector/pgvector:pg16` image (`vector` extension for llmemory). The `pgdata` volume is compatible when switching from `postgres:16`.

If the server still has the old compose file (`image: postgres`), update it and recreate the `db` container:

```bash
cd /home/deploy/cream
# Copy the updated compose file from your local machine:
# scp deploy/docker-compose.yml deploy@SERVER:~/cream/
docker compose pull db
docker compose up -d db
docker compose up -d web   # db:prepare enables the vector extension and migrates llmemory
```

Verify:

```bash
docker compose exec db psql -U cream -d cream_production -c "SELECT extname FROM pg_extension WHERE extname = 'vector';"
```

## Changing the domain

1. Update the DNS record to the new hostname.
2. Change `CREAM_DOMAIN` in `/home/deploy/cream/.env`.
3. `docker compose up -d` (Traefik will request a new certificate).
4. Update the redirect URI in Google OAuth.

## Volumes

| Volume | Contents |
|---|---|
| `pgdata` | PostgreSQL data |
| `cream_storage` | Active Storage (uploads) |

Let's Encrypt certificates live in the Traefik stack (separate Traefik stack (see your infra docs), volume `traefik_letsencrypt`).

## Troubleshooting

**404 from Traefik:** the `web` service is not on the `proxy` network, or Traefik (separate Traefik stack (see your infra docs)) is not running. More routing and certificate troubleshooting in the infra README.

**HTTPS certificate not issued:** check that DNS points to the server and that port 80 is reachable from the internet (Let's Encrypt uses the HTTP challenge). Logs: `docker compose logs traefik` in `~/infra`.

**502 Bad Gateway:** `docker compose logs web` — usually the DB is not ready yet or migrations failed.

**Cannot pull the image:** verify `docker login ghcr.io` or make the package public.

**OAuth fails:** the redirect URI in Google must exactly match `https://CREAM_DOMAIN/auth/google_oauth2/callback`.

### Database backups (Google Drive)

Automatic daily backup at 2:00 (production only) and manual restore via rake tasks.
Full guide: [`BACKUP_SETUP.md`](BACKUP_SETUP.md).

Variables in `.env`:

| Variable | Description |
|---|---|
| `GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH` | Path to the service account JSON (in the container: `/run/secrets/cream-backup.json`) |
| `GOOGLE_DRIVE_BACKUP_FOLDER_ID` | ID of the folder in the Drive shared drive |

Place `cream-backup.json` in `/home/deploy/cream/` (next to the compose file). The volume mounts it into the `web` container.
