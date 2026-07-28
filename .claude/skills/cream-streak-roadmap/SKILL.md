---
name: cream-streak-roadmap
description: >-
  Tracks and implements Streak-parity features in Cream CRM. Use when enabling
  disabled features, updating CreamFeatures flags, extending partial email/automation
  integrations, or continuing the roadmap toward Streak-like functionality.
---

# Cream Streak roadmap

## Source of truth

- **Feature flags**: [app/services/cream_features.rb](app/services/cream_features.rb)
- **Tracking checklist**: [TRACKING.md](TRACKING.md) — update on every enable/disable
- **Route guards**: `RequiresFeature` in [app/controllers/concerns/requires_feature.rb](app/controllers/concerns/requires_feature.rb)
- **Menu**: [app/views/shared/_sidebar.html.erb](app/views/shared/_sidebar.html.erb) reads `CreamFeatures.menu_entries`

## Workflow to enable a feature

1. Read its entry in `CreamFeatures::REGISTRY` and **TRACKING.md**
2. Complete every item under `blockers` / `enable_steps` in TRACKING.md
3. Set `enabled: true` in `cream_features.rb`
4. Expose UI if needed (sidebar uses `menu: true` + `enabled: true`)
5. Re-enable background hooks if applicable (`AutomationEngine`, `SlackNotifier`, email sections)
6. Add or extend request specs; mock HTTP and jobs per project rules
7. Run `bundle exec rspec` and `bin/rubocop`
8. Mark the feature **done** in TRACKING.md with date and PR/commit note
9. Update [`USER_MANUAL.md`](../../../USER_MANUAL.md) and [`MANUAL_USUARIO.md`](../../../MANUAL_USUARIO.md): move the feature out of «Próximamente» / "Coming soon", document access and steps — see skill `cream-user-manual`

## Workflow to ship a new partial feature

Do **not** enable until the user-visible promise matches implementation:

1. Implement missing behaviour first
2. Keep `enabled: false` until verified manually (Mailbin for email in dev)
3. Update TRACKING.md status `:partial` → `:ready`
4. Then flip `enabled: true`
5. Update [`USER_MANUAL.md`](../../../USER_MANUAL.md) and [`MANUAL_USUARIO.md`](../../../MANUAL_USUARIO.md) when the feature becomes user-visible (same task as step 4)

## Feature dependency order (recommended)

```
gmail_sync (standalone OAuth; :send → :send_receive → :full incremental)
record_email + email_tracking (SMTP + public URL)
  └── email_snippets
  └── mail_merge
  └── gmail_sync (optional channel: SendViaGmailJob)
slack_integrations (wire NotificationService events)
automations (conditions UI + hooks already gated)
reports (builder before menu)
```

## Gmail sync notes (for implementers)

- OAuth modes in `GmailConnectionsController#gmail_auth_query`: `:send`, `:send_receive` (metadata), `:full` (readonly only — **no** `include_granted_scopes`).
- `:full` callback uses `assign_oauth_credentials(..., mode: "full")` to **replace** gmail scopes in DB (drops stale `gmail.metadata`).
- Google blocks `messages.list?q=` and `format=full` when `gmail.metadata` is on the token even with readonly — users may need **Enable full reply logging** re-auth + **Sync now**.
- Reply sync: `GmailSyncService` scans known `gmail_thread_id` via `threads.get`; inbox scan only for unreplied outbounds.
- Document user-facing behaviour in `USER_MANUAL.md` and `MANUAL_USUARIO.md` §15 when changing Gmail UX.

## Tests

- Mock `Net::HTTP` for webhooks/Slack
- Use `ActiveJob::Base.queue_adapter = :test` and `have_enqueued_job` for mail merge
- Do not call real Gmail API in specs

## Quick audit command

```bash
bundle exec rails runner 'CreamFeatures.all_entries.each { |e| puts "#{e.key}: #{e.enabled ? "ON" : "off"} (#{e.status})" }'
```
