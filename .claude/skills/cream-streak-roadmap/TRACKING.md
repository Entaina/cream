# Streak parity — feature tracking

Update this file whenever a feature flag changes in `app/services/cream_features.rb`.

Legend: `ready` | `partial` | `placeholder` — only `ready` features should have `enabled: true`.

## Enabled (visible in app)

| Feature | Status | Enabled | Notes |
|---------|--------|---------|-------|
| comments | ready | yes | Record show pages |
| attachments | ready | yes | Active Storage |
| csv_import_export | ready | yes | Index Import/Export buttons |
| notifications | ready | yes | Quick search area bell (not main nav) |
| magic_columns | ready | yes | Index tables only |
| formula_fields | ready | yes | Custom fields settings |
| pipeline_templates | ready | yes | Pipelines page |
| webhooks | ready | yes | Sidebar + admin CRUD |
| api_v1 | ready | yes | `/api/v1/*` Bearer token or Doorkeeper OAuth scope `api` |
| gmail_addon | ready | yes | Gmail Workspace add-on: select workspace/pipeline and create in its first stage, then link Gmail threads to existing or new deals via `/api/v1/gmail/*` (OAuth scope `api`) |
| record_email | ready | yes | Email section on Person/Company/Deal show pages; SMTP (Mailjet) in prod; send-later; follow-up reminders; **Timeline** entry `email_sent` on send (Gmail or SMTP) |
| email_tracking | ready | yes | Open pixel + click redirect; tracking URLs via `CREAM_APP_URL` |
| mail_merge | ready | yes | Recipient picker from saved views/lists/manual + live count; sidebar |
| email_snippets | ready | yes | Sidebar CRUD + snippet picker in the Send email composer (client-side interpolation) |
| gmail_sync | partial | yes | Send-as-Gmail (`SendViaGmailJob`); incremental OAuth (`:send`, `:send_receive`, `:full`); reply detection via thread sync; full reply logging (`Received` inbound) needs `gmail.readonly` without conflicting `gmail.metadata` on token — see deploy/GMAIL_SETUP.md |
| automations | ready | yes | Condition builder + contextual action fields; create_task & send_email live; notify_slack no-op until Slack |
| reports | ready | yes | Builder: metric × dimension × period, bar chart + save (ReportRunner); CSV export; scheduled email (ReportMailer + ScheduledReportsJob daily via recurring.yml) |
| stage_triggers | ready | yes | Per-stage triggers (⚡ in pipeline edit): natural-language LLM mode (tool-use loop, read-only CRM tools + UI actions via user-scoped Turbo Stream broadcasts) or native Ruby functions (`StageTriggers::NativeRegistry`); run audit (`StageTriggerRun`); LLM mode needs `CREAM_AI_API_KEY` |
| stage_field_formats | ready | yes | Per-stage display rules for deal fields (eye icon in pipeline edit): field + condition (eq/lt/gt/blank) + display text (e.g. price 0 → "guest"); applied via `deal_field_display` helper in show/table/board; value refreshed by turbo stream on stage moves |

## Disabled (implemented but gated)

| Feature | Status | Blockers | Next steps |
|---------|--------|----------|------------|
| slack_integrations | partial | Only deal stage change wired | Hook mentions, overdue tasks |

## Enable checklist template

When enabling `<feature_key>`:

- [ ] Blockers cleared (see `cream_features.rb`)
- [ ] `enabled: true` in REGISTRY
- [ ] UI visible (menu / record sections)
- [ ] Background hooks un-gated if needed
- [ ] Specs added/updated
- [ ] Manual smoke test documented below

### Changelog

| Date | Feature | Action | By |
|------|---------|--------|-----|
| 2026-06-19 | reports, mail_merge, email_*, gmail_sync, automations, slack | Disabled; removed from menu | roadmap cleanup |
| 2026-06-19 | automations | Gated AutomationEngine send_email/notify_slack actions behind record_email & slack_integrations flags (automations would otherwise trigger incomplete features) | roadmap cleanup |
| 2026-06-22 | record_email, email_tracking | Enabled. Prod SMTP (Mailjet) + CREAM_APP_URL verified; specs added; local Mailbin smoke test passed | team |
| 2026-06-22 | RequiresFeature | Fixed gating bug: `before_action only: action_methods` was empty at class-load time so feature guards never fired on any controller — now applies to all actions | team |
| 2026-06-22 | mail_merge | Enabled. Recipient picker resolves saved views (`SavedView#resolve`) / lists / manual IDs + live `recipients_count` endpoint; specs added | team |
| 2026-06-22 | email_snippets | Enabled. Snippet picker wired into the Send email composer (`snippet_picker_controller.js`, client-side token interpolation); specs added | team |
| 2026-06-22 | automations | Enabled. Condition builder (key/value rows → `trigger_conditions`) + contextual action fields (`automation_form_controller.js`); fixed `create_task` (Task#user was never set → always raised); send_email live via record_email, notify_slack gated; engine + controller specs | team |
| 2026-06-22 | record_email (send-later) | Added scheduled send: `scheduled_at` column, optional "Send later" field in composer, `SendScheduledEmailJob` (wait_until, status-guarded so cancel works), DELETE to cancel. No new flag — part of record_email. Job + controller specs | team |
| 2026-06-22 | record_email (follow-ups) | Added follow-up reminders: `follow_up_at`/`replied_at` columns, "Follow up in X" composer field, `EmailFollowUpJob` (wait_until → `NotificationService.notify_email_followup` unless replied/cancelled), `mark_replied` action + "Follow up"/"Replied" badges. New `email_followup` notification kind. Job + controller specs | team |
| 2026-06-22 | reports | Enabled. Replaced the static 3-card page with an MVP builder: `Report` model (metric/dimension/period, savable), `ReportRunner` aggregation service, horizontal-bar results + saved reports. `ReportPolicy` now extends WorkspaceRecordPolicy. Runner + controller specs | team |
| 2026-06-23 | reports (phase 2) | CSV export (index `format.csv`); scheduled email reports — `schedule`/`last_sent_at` columns, `ReportMailer.scheduled_report`, `ScheduledReportsJob` (daily in recurring.yml, sends due reports), `update` action + schedule selectors in UI (auto_submit). Job + controller specs | team |
| 2026-06-23 | gmail_sync (phase 1a) | Built send-as-Gmail (flag still OFF, unverified): 2nd OmniAuth provider `google_gmail` (gmail.send + offline), callback stores access/refresh tokens (`GmailConnection#assign_oauth_credentials`), `GmailSender` (token refresh + messages.send via Net::HTTP), `SendViaGmailJob` (SMTP fallback), Connect/Disconnect/send toggle UI, RecordEmails routes via Gmail when enabled. Specs mock HTTP/OmniAuth. Needs Google Cloud config + manual test before enabling | team |
| 2026-07-01 | gmail_sync (phase 2) | Full inbound reply logging: incremental `gmail.readonly` OAuth mode, `GmailReader#get_full`, `EmailMessage` inbound records (`direction`, `from_address`, `in_reply_to`), conversation UI with **Received** badge, `Enable full reply logging` upgrade button. Specs mock HTTP/reader | team |
| 2026-07-01 | gmail_sync (fixes) | Thread-based reply sync (avoids Gmail metadata `q` restriction); metadata header URL fix; `:full` OAuth replaces gmail scopes (no `include_granted_scopes`); UI warning when metadata+readonly block body read. Specs updated | team |
| 2026-07-01 | record_email | Timeline activity `email_sent` on successful send (`EmailMessage#track_sent!` from SMTP controller + `SendViaGmailJob`). Helper + request/job specs | team |
| 2026-07-01 | gmail_sync | Flag `enabled: true`, menu **Gmail** visible; manual test in dev (send, Replied, Received after full re-auth) | team |
| 2026-07-03 | stage_triggers | New feature (enabled): per-pipeline-stage triggers fired from `Deal#move_to_stage!` via `StageTriggerJob`. Two modes: LLM agent (`Ai::Client#chat_with_tools` loop over Responses API; read-only context tools + UI tools) and native Ruby catalogue (`StageTriggers::NativeRegistry`, 2 examples). UI actions (toast/alert/confirm/deal panel) delivered by user-scoped Turbo Stream broadcasts (`turbo_stream_from current_user, :ui` — first broadcast use in the app) + custom stream actions (`stream_actions.js`, textContent only); panel markdown sanitized (redcarpet + sanitize). Run audit with transcript (`StageTriggerRun`, trigger show page). Fixed gap: `deals#update` (web + API v1) now routes stage changes through `move_to_stage!`. Full spec coverage | team |
| 2026-07-03 | stage_triggers (params) | Native functions can declare params (`NativeRegistry::Param`: string/text/select, required, placeholder); trigger form renders the fields dynamically per selected function (hidden fieldsets disabled client-side), values stored in `stage_triggers.native_params` jsonb (pruned + required-validated in model) and passed to handlers as `params:`. New parameterised function `show_toast` (message + kind) | team |
| 2026-07-03 | stage_field_formats | New feature (enabled): `StageFieldFormat` per-stage display rules for deal fields (value/probability/expected_close_date; operators eq/lt/gt/blank; first active match wins). Display-only: `deal_field_display` helper in deal show aside, deals table and board card (`_value_display`/`_card_value` partials replaced by turbo stream on `deals#move` so formats apply live). CRUD nested under pipeline_stages (eye icon in pipeline edit), `WorkspaceRecordPolicy`. Model + request specs | team |
| 2026-07-06 | stripe_payments | New feature (enabled): Stripe payment reconciliation. Per-workspace `StripeConnection` (restricted API key, plaintext like Gmail tokens — shared hardening pending; admin-only mutations) + `StripePayment` (idempotent by `stripe_charge_id`). `StripeClient` (raw Net::HTTP, `GET /v1/charges`, `created[gt]` cursor + pagination), `StripeSyncService` (imports succeeded charges, never overwrites user decisions, re-matches pending on each sync), deterministic `StripePaymentMatcher` (metadata `cream_deal_id` > email+amount+currency > single open deal > ambiguous > none). Reconciliation inbox `/stripe_payments` (tabs, accept suggestion / manual link / create-deal-prefill bridge in `DealsController` / ignore). `payment_received` activity on match. `StripeSyncSchedulerJob` every 15 min in recurring.yml. Deferred: webhooks, post-import refund updates, auto-stage-move on match, AI-assisted matching | team |
| 2026-07-22 | gmail_addon | New feature (enabled): Gmail Workspace add-on links full Gmail threads to deals (`GmailThreadLinker`, `/api/v1/gmail/threads/status` + `/link`); OAuth scope `api` on Doorkeeper; dual auth on API v1 (ApiToken + OAuth). Apps Script source in `gmail_addon/` | team |
