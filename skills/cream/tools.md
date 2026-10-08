# Cream MCP — tool catalog

Tool names exposed by the **Cream MCP server** (see `tools/list` in your MCP client). `record_type` is always `person`, `company`, or `deal`.

## Search and read

| Tool | Required args | Notes |
|------|---------------|-------|
| `search_records` | `query` | Top 10 each: people, companies, deals |
| `list_people` | — | Optional: `query`, `company_id`, `limit` |
| `list_companies` | — | Optional: `query`, `industry`, `limit` |
| `list_deals` | — | Optional: `stage` (name), `query`, `limit` |
| `get_record` | `record_type`, `record_id` | Notes, comments, tasks (≤20), recent activity |
| `list_pipelines` | — | Pipeline names and stages |
| `list_stage_conditions` | — | Optional: `pipeline`, `stage`; includes `available_fields` and `operators` |
| `create_stage_condition` | `stage`, `field`, `operator` | Optional: `pipeline`, `compare_value`, `active`, `position`; feature `:stage_conditions` |
| `update_stage_condition` | `id` | Partial: `field`, `operator`, `compare_value`, `active`, `position` |
| `delete_stage_condition` | `id` | Removes one entry rule |
| `list_products` | — | Optional: `query`, `limit` |
| `list_activity` | — | Optional: `record_type`, `record_id`, `limit` |
| `list_emails` | — | Optional: `record_type`, `record_id`, `status`, `awaiting_follow_up`, `limit` |
| `get_email` | `email_id` | Single message detail |
| `list_payments` | — | Optional: `deal_id`, `limit` |
| `get_deal_history` | `deal_id` | Optional: `limit` (default 50) |
| `recent_changes` | — | Optional: `days`, `limit`, `include_metrics` |
| `pipeline_summary` | — | Counts/value per stage, open/won totals |
| `sales_forecast` | — | Optional: `pipeline`, `months` |

## Create

| Tool | Required args | Notes |
|------|---------------|-------|
| `create_company` | `name` | Optional: domain, industry, employee_range, location, revenue, fiscal_information, description, custom_fields |
| `create_person` | `first_name`, `company_id` | Optional: last_name, email, phone, job_title, location, description, `internal_notes`, custom_fields |
| `create_deal` | `name`, `company_id`, `next_action_title`, `next_action_due_on` | Optional: person_ids, value, currency, pipeline, stage, probability, expected_close_date, execution_duration_days, custom_fields, `email` object |
| `create_product` | `name` | Optional: price, segment (b2b/b2c), description |
| `create_task` | `title` | Optional: `due_on`, `record_type`, `record_id` |

## Update

| Tool | Required args | Notes |
|------|---------------|-------|
| `update_person` | `person_id` | Partial fields (incl. `internal_notes`); empty string clears |
| `update_company` | `company_id` | Partial fields |
| `update_deal` | `deal_id` | Optional: name, value, currency, probability, expected_close_date, execution_duration_days, company_id, person_ids (replaces contacts), pipeline, stage |
| `update_deal_stage` | `deal_id`, `stage` | Stage name within deal’s pipeline |
| `update_product` | `product_id` | Partial fields |
| `update_deal_product` | `line_item_id` | Quantity, unit_price, edition, etc. |
| `add_deal_product` | `deal_id`, `product_id` | Optional: edition_name, quantity, unit_price |
| `update_task` | `task_id` | Optional: title, due_on |
| `complete_task` | `task_id` | Toggles completed ↔ pending |
| `set_custom_fields` | `record_type`, `record_id`, `custom_fields` | Keys from `list_custom_fields` |

## Tasks

| Tool | Required args | Notes |
|------|---------------|-------|
| `list_my_tasks` | — | **`scope`:** `today_or_overdue` (default), `today`, `overdue`, `pending`; `limit` default 50 |
| `list_tasks` | — | Optional: `status` (pending/completed/overdue), `mine`, `assignee_id`, `assignee_query`, `record_type` + `record_id` or `record_query`, `limit` |

## Notes, comments, email

| Tool | Required args | Notes |
|------|---------------|-------|
| `add_note` | `record_type`, `record_id`, `body` | Optional: `title` |
| `add_person_attachment` | `person_id`, `filename`, `content` (Base64) | Optional: `content_type`, `name`; up to 10 MB; feature `:attachments` |
| `add_deal_offer` | `deal_id` + (`filename`, `content` Base64 PDF/HTML **or** `html_body`) | Optional: `name`, `offer_id`, `comment`, `content_type`; adds a new numbered version if the offer exists (by `offer_id`, else `name`, else the deal's only offer), else creates the offer; up to 10 MB |
| `add_comment` | `record_type`, `record_id`, `body` | Optional: `parent_comment_id`; feature `:comments` |
| `send_deal_email` | `deal_id`, `subject`, `body` | Optional: `to_address`, attachments (Base64); feature `:record_email` |

## Duplicates and delete

| Tool | Required args | Notes |
|------|---------------|-------|
| `list_person_duplicates` | — | Groups by email |
| `list_company_duplicates` | — | Groups by domain/name rules |
| `merge_person` | `primary_id`, `secondary_ids` | Irreversible |
| `merge_company` | `primary_id`, `secondary_ids` | Irreversible |
| `delete_record` | `record_type`, `record_id` | **Company delete cascades** people + deals |

## Custom fields

| Tool | Required args | Notes |
|------|---------------|-------|
| `list_custom_fields` | — | Optional: `record_type` filter |

## AI (may return `ai_unavailable`)

| Tool | Required args | Notes |
|------|---------------|-------|
| `summarize_record` | `record_type`, `record_id` | Risks, next steps, gaps |
| `suggest_next_steps` | `record_type`, `record_id` | Action + optional task suggestions |
| `draft_email` | `record_type`, `record_id` | Optional: `goal` |
| `natural_language_search` | `query` | Stalled deals, overdue follow-ups, etc. |
| `enrich_record` | `record_type`, `record_id` | External enrichment when configured |

## Marketing tools

See [marketing.md](marketing.md) for workflows. Names:

`list_mqls`, `get_person_marketing`, `list_product_interests`, `list_subscription_types`, `list_subscriptions`, `list_campaigns`, `get_campaign`, `list_segments`, `get_segment`, `list_journeys`, `get_journey`, `list_scoring_rules`, `get_attribution`, `list_email_templates`, `list_lead_forms`, `create_mql`, `create_product_interest`, `convert_mql_to_sql`, `set_subscription`, `enroll_in_journey`, `send_campaign`, `cancel_campaign_send`.

## Response shape

Tools return JSON text. Records often include `id`, `type`, `name`, `url`, timestamps, and type-specific fields. Errors may include `error`, `message`, or feature/AI codes — surface them to the user.
