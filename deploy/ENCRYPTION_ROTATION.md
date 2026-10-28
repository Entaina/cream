# Encryption of connection secrets

Gmail, Calendar, Mailjet, Stripe, Beehiiv and SMTP credentials, webhook secrets and the OKM service account key are stored with Active Record Encryption.

## Before deploying

1. Generate the keys with `bin/rails db:encryption:init` (on any machine with the app checked out).
2. Add them to the server `.env` as `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` and `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`. Production refuses to boot without them.
3. Store a copy outside the server. Without the keys, encrypted credentials cannot be read, also from restored backups.

## After deploying

1. Encrypt the rows stored before encryption was enabled:

   ```bash
   docker compose exec -T web bin/rails security:encrypt_connection_secrets
   ```

2. Rotate the third-party credentials (Gmail, Calendar, Mailjet, Stripe, Beehiiv, SMTP, webhooks, OKM): earlier backups hold them in plaintext.
3. Once every row is encrypted, set `config.active_record.encryption.support_unencrypted_data = false` in production.
