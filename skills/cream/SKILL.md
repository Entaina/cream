---
name: cream
description: >-
  Operates Cream CRM via MCP tools: people, companies, deals, pipelines, tasks,
  notes, comments, emails, products, duplicates, custom fields, and marketing
  (MQLs, campaigns, journeys). Use for ANY Cream CRM question or action — search
  contacts, create deals, move stages, my overdue tasks, pipeline summary, send
  deal email, convert MQL to SQL, or when the user shares a Cream record URL.
---

# Cream CRM (MCP)

Operate the workspace through the **Cream MCP server** (`POST /mcp`). Responses are JSON in tool text. For setup when tools are missing, see [setup.md](setup.md). Full tool args: [tools.md](tools.md). Marketing flows: [marketing.md](marketing.md).

## Agent invariants

**MUST follow these rules:**

1. **Use MCP tools only** — do not call `/api/v1` with curl, run SQL, or guess IDs. If Cream tools are unavailable, read [setup.md](setup.md) and stop until connected.
2. **Personal task queries** — overdue, due today, or “my tasks” → **`list_my_tasks` only** (not `natural_language_search`, `list_tasks` with `mine`, or `get_record`).
3. **Tasks on a record** — `list_tasks` with `record_type` + `record_id` or `record_query`. **Another member’s tasks** → `assignee_id` or `assignee_query`.
4. **Keyword search** (name, email, domain) → `search_records`. **Semantic / stalled / fuzzy** (“deals stuck in proposal”) → `natural_language_search` (needs AI; may return `ai_unavailable`).
5. **Record detail** → `get_record` (`person` | `company` | `deal`). Lists are capped inside `get_record`; use `list_*` for full lists.
6. **Create person** requires **`company_id`**. No company yet → `create_company` first.
7. **Create deal** requires **`name`, `company_id`, `next_action_title`, `next_action_due_on`** (ISO `YYYY-MM-DD`, today or future). Optional `person_ids` must belong to that company.
8. **Deal value** rolls up from product lines — use `add_deal_product` / `update_deal_product`. After lines exist, trust `products` / subtotals on the deal, not a manual `value` alone.
9. **Stage / pipeline moves** → `update_deal_stage` or `update_deal` with `stage` / `pipeline` (triggers timeline + stage automations). Stage names: `list_pipelines`. **Stage entry rules** → `list_stage_conditions`, `create_stage_condition`, `update_stage_condition`, `delete_stage_condition` (feature `:stage_conditions`).
10. **Destructive ops** — `delete_record` on a **company** deletes its people and deals. Duplicates: `list_person_duplicates` / `list_company_duplicates`, then `merge_person` / `merge_company`.
11. **AI tools** (`summarize_record`, `suggest_next_steps`, `draft_email`, `natural_language_search`, `enrich_record`) may return `ai_unavailable`. Other tools may return feature-disabled errors — do not retry blindly.
12. **Workspace scope** — the API token binds **one user + one workspace**. No workspace switcher. When the payload includes **`url`**, share it with the user (needs `CREAM_APP_URL` on the server).
13. **Comments** — `@Name` in `add_comment` notifies teammates. Reply with `parent_comment_id` from `get_record` comments (requires `:comments` feature).
14. **Task titles** — `@handle` in `create_task` / deal next-action titles can assign via mention parsing (same as the web app).

## Decision trees

### Finding content

```
Need something in Cream?
├── My overdue / today / pending tasks? → list_my_tasks (scope: today_or_overdue | today | overdue | pending)
├── Tasks on a deal/person/company? → list_tasks + record_type + record_id or record_query
├── Teammate's tasks? → list_tasks + assignee_query or assignee_id
├── Name, email, domain? → search_records
├── Natural language ("stalled deals", "follow-ups")? → natural_language_search
├── One record's context? → get_record
├── Deals by stage name? → list_deals(stage: "...")
├── Pipeline health? → pipeline_summary or sales_forecast
├── What changed lately? → recent_changes
├── Deal audit trail? → get_deal_history
├── MQL / marketing? → marketing.md
└── Know record id + type? → get_record or update_*
```

### Modifying content

```
Want to change CRM data?
├── New company → create_company → create_person(company_id) → optional create_deal
├── New deal only → create_deal (+ optional send via email in same call if record_email enabled)
├── Move kanban → update_deal_stage(deal_id, stage) or update_deal(stage/pipeline)
├── Note on record → add_note(record_type, record_id, body)
├── Thread comment → add_comment (optional parent_comment_id)
├── Task → create_task / update_task / complete_task
├── Email from deal → draft_email (optional) then send_deal_email
├── Custom fields → list_custom_fields then set_custom_fields or pass custom_fields on create
├── Line items → add_deal_product / update_deal_product
└── Merge dupes → list_*_duplicates → merge_* (never delete if merge is the goal)
```

## Quick reference

| Goal | Tool |
|------|------|
| Search CRM | `search_records` |
| List people / companies / deals | `list_people`, `list_companies`, `list_deals` |
| Record detail | `get_record` |
| My tasks | `list_my_tasks` |
| Tasks (filters) | `list_tasks` |
| Create person / company / deal | `create_person`, `create_company`, `create_deal` |
| Update records | `update_person`, `update_company`, `update_deal` |
| Move stage | `update_deal_stage` |
| Stage entry conditions | `list_stage_conditions`, `create_stage_condition`, … |
| Note / comment | `add_note`, `add_comment` |
| Task lifecycle | `create_task`, `update_task`, `complete_task` |
| Email | `send_deal_email` |
| Pipeline stats | `pipeline_summary`, `sales_forecast` |
| Products on deal | `list_products`, `add_deal_product`, `update_deal_product` |
| Custom fields | `list_custom_fields`, `set_custom_fields` |
| Duplicates | `list_person_duplicates`, `merge_person`, … |
| Activity | `list_activity`, `get_deal_history`, `recent_changes` |
| AI assist | `summarize_record`, `suggest_next_steps`, `draft_email`, `enrich_record` |
| Marketing | See [marketing.md](marketing.md) |

List endpoints accept `limit` (default 25, max 100). `list_my_tasks` default limit 50.

## Common workflows

### Onboard a lead (CRM)

1. `search_records` — avoid duplicate company/person.
2. `create_company` if needed.
3. `create_person` with `company_id`.
4. `create_deal` with next action title + due date; optional `person_ids`, `pipeline`, `stage`.
5. Return `url` fields from the response to the user.

### Daily follow-up

1. `list_my_tasks` with `scope: today_or_overdue`.
2. For each task, use `taskable` / `url` or `get_record` on the linked deal/person.
3. `add_note` or `add_comment` to log the call; `complete_task` when done.
4. If no next step exists, `create_task` on the same record.

### Move deal through pipeline

1. `list_pipelines` for valid stage names in the deal’s pipeline.
2. `update_deal_stage` with `deal_id` and target `stage` name (case-insensitive match).
3. Confirm with `get_record` or `list_activity` on the deal.

### Email from a deal

1. Optional: `draft_email` for subject/body suggestions (AI).
2. `send_deal_email` with `deal_id`, `subject`, `body`; optional `to_address`, Base64 `attachments`.
3. Requires `:record_email` feature on the workspace.

### Dedupe contacts

1. `list_person_duplicates` or search by email via `search_records`.
2. Choose `primary_id`, collect `secondary_ids`.
3. `merge_person` — irreversible; secondaries are deleted after data moves.

### Workspace pulse

1. `recent_changes` with `days` (default 7) and optional `include_metrics: true`.
2. `pipeline_summary` for stage counts and open/won totals.
3. `sales_forecast` for weighted pipeline by expected close month.

## Domain essentials

- **Records:** `Person` → belongs to `Company`. `Deal` → belongs to `Company`; optional contacts (`person_ids`) from that company.
- **Pipelines:** Deals sit in a pipeline + stage. Default pipeline/stage apply on create if omitted.
- **Tasks:** Polymorphic on person/company/deal; creating a deal always requires an initial next-action task.
- **Permissions:** Tools respect the signed-in user’s role. Admin-only marketing sends still apply.
- **Payments:** `list_payments` for Stripe-linked deal payments when enabled.

## Errors

| Payload hint | Action |
|--------------|--------|
| `ai_unavailable` | AI assistant off or no API key — use non-AI tools |
| `feature_unavailable` / feature name | Feature flag disabled in workspace |
| `invalid_argument` | Fix args (e.g. unknown pipeline, person not in company) |
| `merge_error` | Read message; merge constraints failed |
| Auth / 401 from client | Token missing or revoked — [setup.md](setup.md) |

## Additional resources

- [tools.md](tools.md) — all MCP tools and required arguments
- [marketing.md](marketing.md) — MQL pool, consent, campaigns, journeys
- [setup.md](setup.md) — connect Cursor / Claude to `/mcp`
