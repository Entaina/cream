# Set up Gmail "send as Gmail" (feature `gmail_sync`, phase 1a)

Step-by-step guide to enable sending emails from the user's Gmail account
(emails sent from a record go out from their own account and
end up in their **Sent** folder).

Use the **same** `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` as Google
login. There is no need to create new credentials.

## Context / decisions

- **Internal use (Google Workspace).** If your domain is on **Google Workspace**, the
  consent screen is set to **Internal**:
  - No Google verification or CASA assessment.
  - No "test users" limit.
  - **Refresh tokens do not expire** (in *Testing* mode they would expire after 7 days).
- Scope required for phase 1a: `https://www.googleapis.com/auth/gmail.send`.
- Additional scope for phase 1b (reply detection): `https://www.googleapis.com/auth/gmail.metadata`.
- Additional scope for phase 2 (storing reply bodies on the record): `https://www.googleapis.com/auth/gmail.readonly`
  (a **restricted** scope; with Internal consent it does not require external verification, but it must be added in Google Cloud).
- Permissions are requested **incrementally** in the app: send → metadata → readonly (without disconnecting between levels).
- **Important:** when adding new scopes, users grant the incremental permission from the **Gmail** page (*Enable reply detection* / *Enable full reply logging*) or reconnect using the appropriate mode.

## Values for this project

| Item | Value |
|------|-------|
| OAuth Client ID | `1053838014961-judjenugflkd742skf17u6cbr6hknli4.apps.googleusercontent.com` |
| Public dev URL (ngrok) | `https://dynamic-enormously-minnow.ngrok-free.app` (value of `CREAM_APP_URL`) |
| Production domain | `crm.example.com` |
| Dev redirect URI | `https://dynamic-enormously-minnow.ngrok-free.app/auth/google_gmail/callback` |
| Prod redirect URI | `https://crm.example.com/auth/google_gmail/callback` |
| Login callback (already existing) | `.../auth/google_oauth2/callback` |

> If the ngrok URL in `.env` changes, the dev redirect URI must be updated in Google.

## Steps in Google Cloud Console

> The console was reorganized: the "OAuth consent screen" now lives
> under **"Google Auth Platform"**. Use the **top search
> bar** to reach each section quickly.

### 1. Correct project
Select the project that already contains the login OAuth Client (the one for the Client
ID above).

### 2. Enable the Gmail API
Search bar → **`Gmail API`** → **Enable**.

### 3. Internal consent + scope
Menu **☰ → "Google Auth Platform"**:

- **Audience:** under **User type**, if it says *External*,
  click **"Make internal"** and confirm. If it already says *Internal*, nothing to do.
- **Data Access:** **"Add or remove scopes"** →
  under *"Manually add scopes"* paste (one per line or separated):
  ```
  https://www.googleapis.com/auth/gmail.send
  https://www.googleapis.com/auth/gmail.metadata
  https://www.googleapis.com/auth/gmail.readonly
  ```
  → **Add to table → Update → Save**.

### 4. Redirect URIs
Search bar → **`Credentials`** → under **"OAuth 2.0 Client IDs"**
open your client → under **"Authorized redirect URIs"** → **ADD URI**
and add (without deleting the login ones):
```
https://dynamic-enormously-minnow.ngrok-free.app/auth/google_gmail/callback
https://crm.example.com/auth/google_gmail/callback
```
**Save** (Google takes a few minutes to propagate).

## Enable and test (manual test)

1. `app/services/cream_features.rb` → `gmail_sync: { enabled: true, ... }`.
2. In dev: ngrok running pointing to `localhost:3030` and Rails server restarted
   (to load the `google_gmail` provider).
3. **Gmail** menu → choose one of the connection modes:
   - **Connect for sending only** — requests only `gmail.send`.
   - **Connect for sending and reply detection** — requests `gmail.send` + `gmail.metadata`.
   - **Connect with full reply logging** — requests `gmail.send` + `gmail.readonly` (includes detection and body).
   Accept permissions with an @example.com account (with Internal consent the "unverified app" warning does not appear).
4. Enable **Send emails from records through Gmail** if you connected in send-only mode.
5. If you connected for sending only and want to detect replies, click **Enable reply detection** (incremental authorization; no need to disconnect).
6. If you want to store the text of the replies, click **Enable full reply logging** (requests `gmail.readonly` incrementally).
7. Enable **Detect replies in your inbox** once the metadata permission is granted.
8. Send an email from a record (People/Company/Deal) and verify that:
   - it reaches the recipient **from your Gmail address**, and
   - it appears in your Gmail **Sent** folder.
9. Reply from another account to the sent email, click **Sync now** on **Gmail** (or wait for the recurring
   job) and verify that the email in Cream automatically switches to **Replied**.
10. If you have **full reply logging**, verify that the reply appears in the record's email list with the **Received** label and an expandable body.

After verifying, leave `gmail_sync` at `enabled: true` and mark it `ready` in
`.claude/skills/cream-streak-roadmap/TRACKING.md`.

## How it works under the hood (technical summary)

- A 2nd OmniAuth provider `google_gmail` (default scope `gmail.send`; the actual scope is passed via
  request params for incremental authorization, `access_type=offline`, `prompt=consent`) in
  `config/initializers/omniauth.rb`.
- `GmailConnection#granted_scopes` stores the granted scopes (`can_send?`, `can_read_metadata?`, `can_read_body?`).
- `OmniauthCallbacksController#connect_gmail` stores access/refresh token + email + scopes
  in `GmailConnection` (`assign_oauth_credentials`).
- `GmailSender` refreshes the expired token and calls `users.messages.send` (Net::HTTP), storing
  `gmail_message_id`, `gmail_thread_id` and `rfc822_message_id` on the `EmailMessage`.
- `SendViaGmailJob` sends reusing the `tracked_email` template (keeps the open-tracking pixel).
  If the API fails, it marks the message as **failed** (it does not fall back to SMTP).
- `GmailReader` + `GmailSyncService` list incoming messages, match replies by thread/`In-Reply-To`,
  set `replied_at`, record activity and notify. With `gmail.readonly`, `get_full` captures the body
  and creates inbound `EmailMessage` records (`direction: inbound`) on the record.
- `GmailSyncSchedulerJob` enqueues a sync every 10 min in production; there is also a manual **Sync now**.
- `RecordEmailsController` routes through Gmail when the user is connected and has
  *Send via Gmail* enabled (gated by the `gmail_sync` feature).

## Troubleshooting

- **`redirect_uri_mismatch`**: the redirect URI must match EXACTLY (including
  `https` and the path `/auth/google_gmail/callback`). Check that it is the public URL
  (ngrok in dev), not `localhost`.
- **"unverified app"**: only appears if the consent screen was left *External/Testing*.
  With *Internal* it does not appear. If it does, go back to Step 3.
- **Refresh token not received**: requires `access_type=offline` + `prompt=consent`
  (already configured). Google only returns it on the first consent; if you reconnect
  and it does not arrive, the model keeps the previous one.
- **403 when sending**: check that the Gmail API is enabled and that the
  `gmail.send` scope is on the consent screen.
- **403 when syncing / replies not detected**: add `gmail.metadata` in Google Cloud,
  click **Enable reply detection** on the Gmail page (or reconnect in "sending and reply detection" mode),
  and enable **Detect replies in your inbox**.
- **Reply body does not appear**: add `gmail.readonly` in Google Cloud, click **Enable full reply logging**,
  and sync again. Only replies detected after the permission was granted are captured.
