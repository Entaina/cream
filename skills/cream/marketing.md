# Cream MCP — marketing

Operational marketing via MCP (read + key actions). No ESP credentials or admin CRUD for full config — use the Cream web UI for complex setup. Feature flags must be enabled per workspace.

## When to use which tool

| Need | Tool |
|------|------|
| MQL inbox / pool | `list_mqls` |
| One contact’s marketing profile | `get_person_marketing` |
| Interests on a person | `list_product_interests` |
| Consent list types | `list_subscription_types` |
| Who is subscribed (workspace-wide, with consent evidence) | `list_subscriptions` |
| Subscribe / unsubscribe | `set_subscription` |
| Register a new MQL (person + consent) | `create_mql` |
| Register manual interest | `create_product_interest` |
| MQL → deal (SQL) | `convert_mql_to_sql` |
| Campaigns list / detail | `list_campaigns`, `get_campaign` |
| Queue send to segment | `send_campaign` |
| Cancel queued send | `cancel_campaign_send` |
| Segments | `list_segments`, `get_segment` (+ `include_members`) |
| Journeys | `list_journeys`, `get_journey`, `enroll_in_journey` |
| Scoring rules (read) | `list_scoring_rules` |
| UTM attribution | `get_attribution` |
| Templates / forms (read) | `list_email_templates`, `list_lead_forms` |

## MQL pool — `list_mqls`

Optional filters (match admin MQL screen):

- `q` — name or email
- `subscription_type_id`, `subscription_status` (`subscribed`, `unsubscribed`, `pending`, `missing`)
- `open_deal` (`any`, `yes`, `no`), `open_deal_product_id`, `product_id`
- `interest_product_id`, `interest_status`
- `lead_form_id`, `capture_destination` (`any`, `mql`, `deal`)
- `lead_score_min`, `lead_score_max`
- `view: no_open_deal` — exclude contacts with open deals (optional `product_id` narrows product)
- `limit` (max 100)

Requires `:mql_pool`.

## Register an MQL — `create_mql`

Finds or creates the person by `email`, moves them to the `mql` lifecycle stage (never demotes) and subscribes them to a subscription type, all in one transaction. Required: `email`, `subscriptions` (at least one; ids from `list_subscription_types`) and, for new people, `company_id` or `company_name` (found case-insensitively or created). Each `subscriptions` entry is the consent for that type and needs `subscription_type_id`, `consent_text` (exact text accepted) and `consent_source` (form URL, event, contract…); optional `consent_obtained_at` (ISO 8601, default now, not in the future) and `consent_ip`; the evidence is stored on that subscription. Optional: `first_name`, `last_name`, `phone`, `job_title`, `location`, `internal_notes`, `notes` (`[{title, body}]`), `attachments` (Base64 `{filename, content, content_type}`), `product_id` + `interest_description` (pending product interest). Requires `:mql_pool` and `:marketing_consent` (`:attachments` when sending files). Returns `created` for a new person or `updated` for an existing one.

## Person marketing — `get_person_marketing`

Identify person by `person_id` or `person_query` (name/email).

Returns: lifecycle stage, lead score, marketing eligibility, suppression, subscriptions, product interests, active journey enrollments, recent email events, lead form submissions.

## Product interest → SQL

Typical conversion path:

1. `get_person_marketing` or `list_mqls` — confirm person and pending interest.
2. If no interest row: `create_product_interest` (`person_id`, `product_id`, `description`).
3. `list_pipelines` — pick `pipeline_id` for the new deal.
4. **`convert_mql_to_sql`** — required: `product_interest_id`, `pipeline_id`, `task_title`, `task_due_on` (ISO date). Optional: deal `name`, `owner_id`, `task_assignee_id`, `deal_id` (link existing open deal).

Response includes `status`, `message`, updated `interest`, and `deal` when created.

## Subscriptions — `list_subscriptions`

Lists the workspace's subscriptions (consent per person and type), most recently changed first, each with `status`, `source`, `consent_evidence` and the `person` (`id`, `name`, `email`). Optional filters: `subscription_type_id`, `status` (`subscribed` | `unsubscribed` | `pending`), `person_id`, `limit`. Only people the caller can see. Requires `:marketing_consent`.

## Consent — `set_subscription`

Required: `person_id`, `subscription_type_id`, `action` (`subscribe` | `unsubscribe`).

To `subscribe` you must also send the consent evidence: `consent_text` (exact text the person accepted) and `consent_source` (form URL, event, contract…); optional `consent_obtained_at` (ISO 8601, default now, not in the future) and `consent_ip`. It is stored on the subscription with the user who registered it. An already active subscription keeps its original evidence; `unsubscribe` needs no evidence.

Use `list_subscription_types` for ids. Requires `:marketing_consent`.

## Campaigns

1. `list_campaigns` / `get_campaign` — verify content and past sends.
2. `list_segments` — **`send_campaign` requires a Person segment** (`segment_id`).
3. **`send_campaign`** — required: `campaign_id`, `segment_id`. Optional: `email_template_id`, `subscription_type_id`, `scheduled_at` (ISO8601). Queues background send (not instant delivery).
4. **`cancel_campaign_send`** — `campaign_id`, `send_id` for pending/scheduled sends.

Campaign must have email content configured (or pass template). Requires `:marketing_campaigns`.

## Journeys

- Read: `list_journeys`, `get_journey` (steps, enrollments).
- **`enroll_in_journey`** — `journey_id`, `person_id`. Requires `:journeys`.

## Attribution — `get_attribution`

Optional: `date_range` (`month`, `quarter`, `year`, `all`), `utm_source`, `utm_medium`, `utm_campaign`.

Requires `:marketing_attribution`.

## Feature unavailable

Marketing tools return feature-disabled payloads when the workspace flag is off. Tell the user which capability is disabled; do not hammer retries.

## Coordination with CRM tools

- After SQL conversion, use CRM tools (`get_record`, `update_deal`, `add_note`) on the returned deal.
- Person/company/deal CRUD remains in the main [tools.md](tools.md) list.
