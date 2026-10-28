# Set up database backups to Google Drive

Guide for the automatic daily backup of the primary database (`cream_production`)
and manual restoration from Google Drive.

## System overview

| What | How |
|-----|------|
| Automatic backup | `DatabaseBackupJob` via Solid Queue, **production only**, every day at **2:00 AM** |
| Manual backup | `bin/rails cream:backup:run` |
| Restore | `bin/rails cream:backup:restore` (latest for the environment) or by file name |
| Format | `pg_dump -Fc` (PostgreSQL custom, compressed) |
| Destination | Folder in Google Drive (Shared drive of your organization) |
| Authentication | Google Cloud service account + JSON key on disk |
| File name | `cream_backup_<environment>_<date>.dump` (optional `.age` suffix when `BACKUP_AGE_PUBLIC_KEY` is set) |
| Encryption (optional) | `age` with `BACKUP_AGE_PUBLIC_KEY` on backup; restore with `BACKUP_AGE_IDENTITY_FILE` or `BACKUP_AGE_IDENTITY` |
| Retention | Deletes backups older than **30 days**, except those from the **1st day of each month** (same environment only) |

The daily job **does not run in development** even if you have the variables configured.
Locally you can test with the rake task `cream:backup:run`.

## Architecture

```
PostgreSQL (cream_production)
        ↓ pg_dump -Fc
   Local tempfile
        ↓ upload (Drive API v3)
   Folder in Shared drive
        ↑ service account (JSON key mounted in the container)
```

In production the `web` container mounts the JSON key as a read-only volume
(see [`docker-compose.yml`](docker-compose.yml)).

---

## 1. Google Cloud — service account

1. Go to [Google Cloud Console](https://console.cloud.google.com/) and select
   (or create) a project, for example `cream-backups`.

2. **APIs & Services → Library** → search for **Google Drive API** → **Enable**.

3. **APIs & Services → Credentials → Create credentials → Service account**:
   - Suggested name: `cream-db-backup`
   - Project role: none required (access is granted per folder in Drive)

4. On the service account → **Keys** tab → **Add key → Create new key → JSON**.
   Download the file (e.g. `cream-backup.json`).

   The account email will look like:
   ```
   cream-db-backup@tu-proyecto.iam.gserviceaccount.com
   ```

5. **Do not commit this JSON to the repository.** It is in `.gitignore` as `cream-backup.json`.

---

## 2. Google Drive — permissions (option C: share with an external user)

Using a Google Workspace **Shared drive** is recommended. By default it may block
sharing with users outside the organization. Service accounts count as
**external**, even if they belong to Google Cloud.

**Option C (recommended):** adjust the shared drive
policy to **allow external members** and share the backups folder
with the service account email.

### 2a. Allow external users on the Shared drive

A **Google Workspace administrator** must:

1. Go to the [Admin console](https://admin.google.com) → **Apps → Google Workspace → Drive and Docs**.
2. Under **Shared drives**, review the settings of the drive
   where the backups will live (or create a new one, e.g. `Cream Backups`).
3. Allow the drive to **share content with people outside the
   organization**

> If sharing the folder shows the error *"This shared drive's settings
> prevent files from being shared with users who are not members of the drive and
> are outside your organization"*, that restriction must be relaxed at the shared drive level
> before continuing.

### 2b. Backups folder

1. In [Google Drive](https://drive.google.com), inside the Shared drive,
   create a folder, for example `database-backups`.

2. **Share** the folder with the service account email
   (`cream-db-backup@....iam.gserviceaccount.com`) with the **Editor** role
   (or Content manager).

3. Get the **folder ID** from the browser URL:
   ```
   https://drive.google.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUvWxYz
   ```
   The ID is the final part: `1AbCdEfGhIjKlMnOpQrStUvWxYz`.

---

## 3. Environment variables

| Variable | Description |
|----------|-------------|
| `GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH` | Path to the service account JSON file |
| `GOOGLE_DRIVE_BACKUP_FOLDER_ID` | ID of the folder in Drive |
| `BACKUP_AGE_PUBLIC_KEY` | Optional. `age` public key (`age1...`): backups are encrypted and uploaded as `.dump.age` |
| `BACKUP_AGE_IDENTITY_FILE` / `BACKUP_AGE_IDENTITY` | Only to restore `.dump.age` backups: path to the `age` private key, or the key itself |

### Backup encryption (age)

Without encryption, anyone with access to the Drive folder can read every contact, deal and email in the dumps. To encrypt them:

1. On your machine, generate a key pair with [`age`](https://github.com/FiloSottile/age):

   ```bash
   age-keygen -o cream-backup-age.txt
   ```

   The command prints the public key (`age1...`). The file holds the private key (`AGE-SECRET-KEY-...`).
2. Store `cream-backup-age.txt` in the password manager. **Do not leave it on the server**: without it, encrypted backups cannot be restored, and anyone who has it can read them.
3. Add the public key to the server `.env` and recreate the container:

   ```bash
   BACKUP_AGE_PUBLIC_KEY=age1...
   ```

From then on, daily backups are uploaded as `cream_backup_<environment>_<date>.dump.age`. If encryption fails, the backup fails and nothing is uploaded.

### Local development

In `.env` (copied from `.env.example`):

```bash
GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH=/ruta/absoluta/a/cream-backup.json
GOOGLE_DRIVE_BACKUP_FOLDER_ID=1AbCdEfGhIjKlMnOpQrStUvWxYz
```

### Production

In `/home/deploy/cream/.env`:

```bash
GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH=/run/secrets/cream-backup.json
GOOGLE_DRIVE_BACKUP_FOLDER_ID=1AbCdEfGhIjKlMnOpQrStUvWxYz
```

Place the JSON on the server next to the compose file:

```bash
cd /home/deploy/cream
scp cream-backup.json deploy@SERVER:~/cream/cream-backup.json
chmod 600 cream-backup.json
```

The [`docker-compose.yml`](docker-compose.yml) mounts that file into the container:

```yaml
volumes:
  - ./cream-backup.json:/run/secrets/cream-backup.json:ro
```

After adding or changing the file, recreate the container:

```bash
docker compose up -d web
```

---

## 4. Verify the configuration

On the server:

```bash
cd /home/deploy/cream

# Does it exist on the host?
ls -la cream-backup.json

# Can the container see it?
docker compose exec web ls -la /run/secrets/cream-backup.json

# Does Rails find it?
docker compose exec web bin/rails runner \
  'puts File.file?(ENV["GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH"])'
```

It should print `true`.

---

## 5. Usage

### Manual backup

```bash
# Local
bin/rails cream:backup:run

# Production
docker compose exec web bin/rails cream:backup:run
```

Expected output:

```
Uploaded: cream_backup_production_2026-07-02.dump
No old backups deleted.
```

### Restore

Without a file name, the task restores the **latest backup for the current environment**. With a name, it restores that file (it can be from another environment):

```bash
# Local
bin/rails cream:backup:restore
bin/rails "cream:backup:restore[cream_backup_production_2026-07-01.dump]"
```

In **production** the restore is destructive (`pg_restore --clean` replaces the whole database) and must be confirmed with `CONFIRM=1`. Pass it with `-e`: a variable set in front of `docker compose` stays on the host and the task aborts. Always give the exact file name (see the Drive folder): right after a manual backup, the latest one is today's.

Plain `.dump` backups need no key:

```bash
docker compose exec -e CONFIRM=1 web bin/rails "cream:backup:restore[cream_backup_production_2026-07-01.dump]"
```

Encrypted `.dump.age` backups need the matching **identity** (private key), not the public key used for upload. Paste the `AGE-SECRET-KEY-1...` line from the password manager so it never touches the server disk or the shell history; `-e BACKUP_AGE_IDENTITY` without a value forwards it from the shell, so it does not show up in the process arguments:

```bash
read -rs BACKUP_AGE_IDENTITY && export BACKUP_AGE_IDENTITY
docker compose exec -e CONFIRM=1 -e BACKUP_AGE_IDENTITY web \
  bin/rails "cream:backup:restore[cream_backup_production_2026-07-01.dump.age]"
unset BACKUP_AGE_IDENTITY
```

The app writes the key to a `600` temp file, decrypts, restores and deletes both files.

---

## 6. Automatic scheduling

Defined in [`config/recurring.yml`](../config/recurring.yml):

```yaml
production:
  database_backup:
    class: DatabaseBackupJob
    schedule: every day at 2am
```

Solid Queue runs inside the `web` container (`SOLID_QUEUE_IN_PUMA=1`).
Only the **primary** database (`cream_production`) is dumped; the cache,
queue and cable databases are not included (they can be regenerated).

---

## 7. Troubleshooting

| Symptom | Likely cause | What to do |
|---------|----------------|-----------|
| `Service account key file not found` | JSON not mounted or wrong path | Check the volume and `GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH` |
| Docker created an empty `cream-backup.json` directory | The file did not exist when running `docker compose up` | Delete the directory, copy the real JSON, `docker compose up -d web` |
| `403` / insufficient permissions in Drive | Folder not shared with the service account or shared drive policy | Repeat the steps in section 2 (option C) |
| `404` / folder not found | Wrong `GOOGLE_DRIVE_BACKUP_FOLDER_ID` | Copy the ID from the folder URL |
| `pg_dump failed` | Incompatible PostgreSQL client or unreachable DB | The image uses `postgresql-client-16`; check the connection to `db` |
| Job does not run in dev | Expected behavior | Use `cream:backup:run` manually |
| Restore aborted in prod | `CONFIRM=1` did not reach the container | Pass it as `docker compose exec -e CONFIRM=1 web ...` |
| `Backup is age-encrypted but BACKUP_AGE_IDENTITY_FILE or BACKUP_AGE_IDENTITY is not configured` | The private key did not reach the container | `export BACKUP_AGE_IDENTITY` and add `-e BACKUP_AGE_IDENTITY`; the database is not touched |
| `age decryption failed` | Wrong private key for that backup | Use the key whose public key was in `BACKUP_AGE_PUBLIC_KEY` when it was uploaded |
| `age encryption failed` in the backup job | Invalid `BACKUP_AGE_PUBLIC_KEY` | Check the `age1...` value; nothing was uploaded |

### Automatic backup logs

```bash
docker compose logs web | grep DatabaseBackupJob
```

---

## 8. Security

- The JSON key is a secret: `600` permissions on the server, never in git.
- With `BACKUP_AGE_PUBLIC_KEY` set, Drive only holds encrypted dumps; the `age` private key stays off the server.
- Restoring in production requires `CONFIRM=1`.
- Backups from different environments coexist in the same folder thanks to the
  `cream_backup_<environment>_` prefix; retention only deletes files from the environment running the backup.
