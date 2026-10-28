---
name: cream-architecture
description: Domain model, workspaces, API tokens, conventions, design system and production deployment of the Cream CRM (Attio clone). Use when adding features, models, views, auth, multi-tenancy, UI components, or working on production deploy/infra so everything stays consistent. For REST API v1 use skill `cream-api`; for MCP use skill `cream-mcp`; for marketing hub use skill `cream-marketing`.
---

# Cream — Architecture & conventions

Cream replicates Attio's CRM: workspace-scoped records (People, Companies, Deals) with notes, tasks, lists and an activity timeline.

## Domain model

- Core records: `Company`, `Person` (belongs_to company), `Deal` (stage machine in `Deal::STAGES`: lead/qualified/proposal/negotiation/won/lost, each with label+color; `move_to_stage!` handles kanban moves and logs a `stage_changed` activity with metadata `{ from:, to:, won: }`, where `won` is true when the target stage is a won stage).
- Shared concerns: `CrmRecord` (workspace, owner, notes/tasks/list_entries associations) and `Trackable` (auto-logs `created`/`updated` activities with field diffs; per-model `tracked_ignored_attributes`).
- `Note` / `Task` are polymorphic (`notable` / `taskable`) and log activities on their parent record.
- **`Task` assignee:** optional `assignee_id`; default on create is the current user. If the title contains `@handle` for a workspace member, `before_save` assigns the first match via `MentionParser` (same parser as comments).
- **`Product`**: workspace catalog (`name`, `price`, `segment`). `has_many :editions`, `has_many :deal_products`.
- **`Edition`**: belongs to **`Product`** (and denormalized `workspace` for policies/scoping). Unique `name` per product (`[product_id, name]`). Optional `starts_on` / `ends_on`. `has_many :deal_products` (`restrict_with_error` on delete).
- **`DealProduct`**: deal line — `product`, optional `edition` (must belong to the same product). `edition_name` resolves via `product.editions.find_or_create_by(name:)`. Value rolls up to `deal.value`.
- `List` + `ListEntry`: typed lists (record_type Person|Company|Deal) shown in the sidebar.
- `Activity`: polymorphic timeline (`subject`), rendered by `ApplicationHelper#activity_sentence`. On a person, `RecordActivityFeed` accepts `deal_ids:` and, when the filter is `all` or `changes`, also includes those deals' `stage_changed` rows. The person history renders them with `person_history_activity_html`: won stages use `activities.person_deal_won_html`; other moves use `activities.person_deal_stage_changed_html` (the deal name links to the deal). Rows without `metadata["won"]` fall back to whether the named target stage is `won?`.

## Workspaces & multi-tenancy

The workspace is the **tenant boundary** — all CRM data lives inside one.

```
User ←── Membership ──→ Workspace
              │
         role: admin | sales_director | salesperson | ai_salesperson
```

- **`Workspace`**: `name` + unique `slug`. Optional unique `email_domain` for automatic signup into this tenant. Owns companies, people, deals, notes, tasks, lists, activities.
- **`Membership`**: joins user ↔ workspace. Roles `admin` | `sales_director` | `salesperson` | `ai_salesperson` (`Membership::ROLES`). One membership per user/workspace pair. `superadmin_access` marks support memberships (hidden from team lists, excluded from last-admin checks). Per-workspace prefs: `current_pipeline_id`, `sales_director_briefing_enabled`, `alert_in_app` (default true), `alert_email` (default false).
- **`User`**: can belong to **many** workspaces (`has_many :workspaces, through: :memberships`). Global flag `superadmin` (grant via `bin/rails superadmin:grant[email]` only — no UI).

**Superadmin** (`/superadmin`, `Superadmin::*`): create/edit workspaces, set `email_domain`, manage members/invitations, **Enter workspace** (lazy admin membership with `superadmin_access: true`). Superadmins pass `UserContext#member?` / `#admin?` in any workspace; API/MCP still use normal membership only.

**Registration** (`RegistrationsController#create`): password signup stores an unverified user and emails a confirmation link. No session and no workspace membership until that link is opened. `CREAM_PUBLIC_SIGNUP=true` (default outside production; production defaults to `false` when unset) then creates a personal workspace (admin). When false, only invited emails or emails matching a workspace `email_domain` can register (legacy fallback: `CREAM_ORGANIZATION_*` env). `User#provision_default_workspace!` runs after confirmation and joins domain workspaces as admin if empty else salesperson. Google sign-in counts as verified; linking it to an unverified password account replaces that password. Accepting an invitation verifies the email.

**Active workspace per request** — session `workspace_id` + switcher (`shared/_workspace_switcher`; superadmin sees all workspaces):

- `User#default_workspace` → first membership, or first workspace in DB for superadmin
- `ApplicationController#set_current_workspace` sets `Current.workspace`
- Exposed as `current_workspace`; `ensure_workspace_membership` requires a valid membership or raises `Pundit::NotAuthorizedError`
- Sidebar shows `current_workspace.name` (`shared/_sidebar`)

**Data isolation**:

- All CRM models include `CrmRecord` → `belongs_to :workspace`
- Pundit receives `UserContext` (user + workspace + membership) via `pundit_user`
- `WorkspaceRecordPolicy` scopes with `scope.where(workspace: workspace)` and checks `in_workspace?`
- Controllers always query via `current_workspace` (e.g. `policy_scope(current_workspace.deals)`)

**Roles**: `admin`, `sales_director`, `salesperson` and `ai_salesperson` on `Membership`. `ai_salesperson` only sees/edits deals it owns (ignores collaborator access and the workspace `salespeople_can_*` flags) and can never delete: `ApplicationPolicy` prepends a guard that forces `destroy?` to false in every policy and `merge?` is denied on people/companies. Everything goes through Pundit: any action that deletes (including child records authorized via their parent deal, e.g. offers, line items, collaborators) must `authorize ..., :destroy?`, and nested `_destroy` params are only permitted when `policy(record).destroy?`. Replacing a deal's contacts (web, REST, MCP `update_deal`) also requires `destroy?` when it would unlink existing ones (`Deal#removes_contacts?`). Admin-only mutations (via Pundit `admin?`) include team/invites, automations, **alert rules**, webhooks, stripe connection, etc. Members can view most workspace data; alert rule CRUD is admin-only, list is member-visible.

**Seeds**: demo workspace `Cream Demo` with multiple users (e.g. admin=admin, member=salesperson) sharing one workspace.

When adding features: ALWAYS scope queries through `current_workspace`. If implementing multi-workspace UX, you'll need session-stored workspace selection — today only `default_workspace` is used.

## API tokens

Per-user, per-workspace bearer tokens for programmatic access (MCP, REST API, etc.).

- Model: `ApiToken` — `belongs_to :user`, `belongs_to :workspace`
- Prefix: `cream_`; stored as SHA256 digest; plaintext shown once on create (`flash[:api_token]`)
- Created via `ApiTokensController` on `current_user` + `current_workspace`
- Policy: users list/revoke only their own tokens (`ApiTokenPolicy#destroy?` checks `record.user_id == user.id`; scope filters `user` + `workspace`)
- Routes: `resources :api_tokens, only: %i[index create destroy]`
- **REST API v1** (endpoints, OpenAPI): skill **`cream-api`**
- **MCP server** (tools, OAuth scope `mcp`, `/mcp`): skill **`cream-mcp`**

## UI conventions

- Layout: fixed left sidebar (`shared/_sidebar`), pages are flex columns: `shared/_page_header` (h-13 title bar with actions capture) + scrollable content.
- Record show pages: left attributes panel (w-80, `shared/_attribute` rows) + main column with `shared/_notes_section`, `shared/_tasks_section`, `shared/_timeline`.
- **Person show** is tabbed (`activity` / `deals` / `information` / `files`). Activity main column: `people/_overview_deals_section` (first 5 of `@deals`, remainder in a disclosure; **View deals** jumps to the deals tab when there are more than 5), next tasks, then `people/_activity_feed` (**History**). Deals tab: `people/_deals_panel` (full list; product `<select>` when more than one product) and, if `:mql_pool`, product interests and lead submissions. `@deals` is the policy scope of deals that have this person as a contact, newest first; a `product_id` query filters that set and opens the deals tab. `PeopleController#show` passes those deal ids into `RecordActivityFeed`.
- Components are CSS classes in `app/assets/tailwind/application.css`: `.btn-primary/.btn-secondary/.btn-ghost/.btn-danger`, `.input`, `.label`, `.table-base`, `.card`.
- **ViewComponents** (`gem "view_component"`, `app/components/`): reusable UI pieces with Ruby class + ERB template. Use `RecordPickerComponent` for searchable form pickers with optional on-the-fly creation (companies, editions per product, etc.). Hybrid search: embeds full list when `scope.count` is between 1 and `RecordPickerComponent::INLINE_LIMIT` (200); **empty scope** → remote-only (never embed an empty inline list). Otherwise queries `search_url` (e.g. `GET /companies/picker.json?q=`, `GET /products/:id/editions/picker.json?q=`). Stimulus: `record_picker_controller.js`; edition lines on deals also use `product_edition_picker_controller.js` to reload editions when the product `<select>` changes.
- Theme tokens (`@theme`): `ink` (text), `ink-soft`, `ink-faint`, `line` (borders), `canvas` (bg), `canvas-soft`, `canvas-sunken`, `canvas-tint` (sidebar), `accent`/`accent-dark`/`accent-soft` (Hoki), `on-dark`. Typography scale: `text-base` 15px (body), `text-sm` 14px (buttons/inputs), `text-xs` 13px (labels/meta), `text-2xs` 12px (badges/kbd). Fonts: Lato body, Comfortaa display.
- Helpers: `icon(:name)` (inline SVG set in `IconHelper::ICONS`), `avatar(record)` (initials, deterministic color), `badge`, `stage_badge`, `money`, `sort_link` (sortable table headers preserving query params), `mention_html(text)` (highlight `@mentions` in comments and task titles), `mention_text_field(form, field, **options)` (task title input + mention autocomplete wrapper).
- Stimulus: `kanban_controller.js` (HTML5 drag&drop, PATCH /deals/:id/move), `flash_controller.js` (auto-dismiss), `hotkeys_controller.js` ("/" → search), `mention_controller.js` (`@` autocomplete in task title fields; users JSON in `data-mention-users-json-value`), `record_picker_controller.js` (generic searchable record combobox; used by `RecordPickerComponent`), `product_edition_picker_controller.js` (deal product line: wires product select → edition picker URLs + inline edition list), `row_link_controller.js` (whole-row table navigation: plain click → Turbo, cmd/ctrl+click or middle-click → new tab).
- Index pages: search `?q=` + per-type filters + `sort_link` columns; rows use `row-link` Stimulus + `link_to` on the name cell. Deals table and board share `deals/_filters` partial; board omits stage filter (`show_stage: false`) and strips `:stage` from `@effective_filters`.

## List filtering & saved views

- **`ViewScoped`** concern (`app/controllers/concerns/view_scoped.rb`): `load_saved_views`, `@effective_filters`, `filter_value`, `filter_form_params`, `filters_active?`; merges saved-view JSON with URL overrides (`q`, native key, `cf`, `sort`, `dir`, `closed`, plus `@extra_filter_keys`).
- **`SavedView`**: `NATIVE_FILTER_KEYS` (Deal → `stage`); `EXTRA_FILTER_KEYS` (Deal → `product_id`, `edition_id`, `first_contact_from`, `first_contact_to`). `#resolve` applies native + custom fields + `Deal.apply_extra_filters` for Deal.
- **`Deal.filter_by(scope, filters)`** / **`Deal.apply_extra_filters`**: shared by `DealsController#filtered_deals`, `ExportsController`, and `SavedView#resolve`. Product + edition match the same `deal_products` row; first contact filters join `contacts` on `people.first_contact_on` range. Deal filter UI groups editions by product (`grouped_options_for_select` in `deals/_filters`).
- **`DealsController#board`**: `load_saved_views("Deal")` then `@effective_filters.except(:stage)` before filtering.

## Mentions (`@usuario`)

Shared service [`MentionParser`](../../../app/services/mention_parser.rb): pattern `@([\w.-]+)`, resolves workspace members by email prefix, exact name or partial name. Used by:

| Surface | Parse on save | Render | Autocomplete UI | Notification |
|---------|---------------|--------|-----------------|--------------|
| **Comments** (`Comment#notify_mentions`) | yes | `mention_html` in `_comments_section` | no (manual `@`) | yes (`NotificationService.notify_mention`) |
| **Tasks** (`Task#assign_from_mentions`) | yes → sets `assignee` | `mention_html` in task lists / dashboard | yes (`mention_controller` + `mention_text_field`) | no (yet) |

Task title fields with mentions: `shared/_tasks_section`, `tasks/index`, `deals/_form` (nested «Next action»).

## Notifications & alerts

**In-app notifications** — model `Notification` (`kind`, `title`, `body`, `url`, `read_at`), scoped per user + workspace. Kinds include `mention`, `task_overdue`, `email_*`, `lead_submission`, `booking`, `automation`, **`alert`**. Created via `NotificationService`; inbox at `/notifications`.

**Configurable alerts** (time-based, separate from event-driven **Automations**):

```
Admin CRUD /alert_rules → AlertRule (trigger_field, offset_days, conditions[], recipient)
AlertRulesJob (daily, recurring.yml) → AlertRuleEngine → matching deals
  → AlertDelivery dedupe (rule + deal + user, once ever)
  → channels from Membership: alert_in_app / alert_email
  → NotificationService.notify_alert + AlertMailer#alert_email
```

- **`AlertRule`**: `TRIGGER_FIELDS` = `edition_ends_on` | `edition_starts_on` | `deal_expected_close_date` (fires when `date + offset_days <= Date.current`; negative offset = advance warning). `CONDITIONS` = `company_without_fiscal_info` (`companies.fiscal_information` blank), `deal_open` (stage not closed). `RECIPIENTS` = `deal_owner` | `admins`.
- Edition dates live on `Edition` (`starts_on`, `ends_on`); each edition belongs to one `Product`. Deal lines link via `deal_products.edition_id` (edition must match line's product).
- Feature flag `:alerts` in `CreamFeatures`; menu **Alertas**; `AlertRulesController` + `RequiresFeature`.
- User channel prefs: **Settings → Profile → Alertas** (`Settings::ProfileController` permits `alert_in_app`, `alert_email`). Used by **AlertRuleEngine**, lead-form responsible notify, and booking host notify. If both off, no delivery (and no `AlertDelivery` row for rules).

When adding a new alert trigger or condition, extend constants + `AlertRuleEngine#apply_trigger` / `#apply_conditions` and the form checkboxes in `alert_rules/_form.html.erb`.

## Lead capture forms (public)

Feature flag `:lead_forms`. Public URLs `/f/:slug` (POST creates lead) and `/f/:slug/success` (thank-you page). Admin CRUD: `LeadFormsController`, `LeadFormTemplatesController` (templates admin-only).

### Runtime rendering (Liquid, DB-only, user-configurable)

- **`LeadForm`** (`template_key`) picks which **page template** to render from `lead_form_templates` in DB. Public views: only `app/views/public/lead_forms/show.html.erb` and `success.html.erb` wrap rendered Liquid HTML.
- **`LeadFormTemplate`**: workspace-scoped Liquid body in DB, editable by admins (**Formularios → Plantillas de formulario**). Paths like `public/lead_forms/contacto` (pages) or `public/lead_forms/partials/contact_fields` (partials). System view: `public/lead_forms/success`.
- **`LeadFormTemplates::Source#find_body`**: reads **only from DB**; no filesystem fallback at runtime. Missing template → 404.
- **`LeadFormTemplates::Renderer`**: Liquid env + custom tags in `app/services/lead_form_templates/tags.rb`. Assigns: `lead_form`, `product`, `open_editions`. Registers: `field_renderer`, `form_action`, CSRF, etc.
- **`lib/lead_form_templates/`** (repo): **demo catalog only** — pages `contacto`, `demo`, `newsletter`, `reserva` + partials (`contact_fields`, `consent_fields`, …) and system `privacy`/`success`. Imported by `db:seed` / specs; **never** reimport on production deploy. Real workspaces: admins create templates in UI. `LeadForm.available_template_keys(workspace:)` reads **DB form pages only**.

### Liquid tags (form pages)

| Tag | Role |
|-----|------|
| `{% form_open %}` / `{% form_close %}` | `<form>` + Stimulus `lead-form` |
| `{% hidden_fields %}` | Honeypot metadata, UTM, `product_id`, `hidden_field_keys` from URL |
| `{% field type: "…", name: "…", required: true %}` | Inputs via `FieldRenderer` |
| `{% subscription_opt_in slug: "newsletter" %}` | Marketing checkbox; `name` = `SubscriptionType#consent_field_key`; label from tag arg, MQL form text, or type default |
| `{% partial 'name' %}` | Renders `public/lead_forms/partials/name` |
| `{% phone_with_prefix %}` | Phone + country prefix select |
| `{% honeypot %}`, `{% turnstile %}`, `{% submit '…' %}` | Anti-spam / submit |

Select options: inline in Liquid via `choices: "Label|value; Label2|value2"` on `{% field type: "select" %}`. Phone prefix lists use the same format on `{% phone_with_prefix prefixes: "…" %}`. Dynamic collections (e.g. `open_editions`) still use `collection: "open_editions"`. Admin **pipeline routes** are free-form rows (field value → pipeline); keys must match Liquid `choices` values (e.g. `curso`, not the label).

### Submission pipeline

1. **`Public::LeadFormsController#create`**: GDPR consent, Turnstile, honeypot + signed timestamp (`LeadForm::MIN_SECONDS_TO_SUBMIT`), rate limits.
2. **`LeadFormSubmissionProcessor`**: generic validation + CRM side effects. **No `template_key` branches.**
3. **`lead_params`**: accepts any `lead[…]` key matching `LeadForm::FIELD_KEY_FORMAT` (`[a-z][a-z0-9_]{0,39}`). No fixed field whitelist. Hidden field keys in admin cannot collide with **system** keys only (`SYSTEM_FIELD_KEYS`: UTM, honeypot, timestamp, GDPR, form metadata).

**Server validation** — schema stored on each form-page `LeadFormTemplate` (`submission_schema` jsonb), recompiled on save:

1. **At template save** (`LeadFormTemplate#refresh_submission_schema!`): `SchemaCompiler` renders the page in maximal/minimal contexts, parses HTML → JSON field definitions (required, types, allowed values, conditional flags like `requires_collects_company`, `requires_open_editions`).
2. **At submit** (`SubmissionSchema.build`): loads stored schema, applies runtime context (`collects_company?`, product, `open_editions`), validates params. Fallback: live render if schema empty (legacy rows).
3. `Public::LeadFormsController#lead_params` whitelists to `schema.allowed_param_keys`.

Implication: a field only persists if it appears in the stored schema **and** passes contextual filters for that submit. After Liquid changes, **re-save the template in admin** (recompiles schema). Do not rely on repo reimport in workspaces where users customized templates.

**URL prefill**: `hidden_field_keys` + `?key=value`; Stimulus `lead_form_controller.js` fills `[data-lead-form-param]`. Also `?product_id=` overrides configured product. **`open_editions`**: `LeadForm#open_editions_for(product)` → `product.editions.not_finished`, exposed to Liquid and `{% field collection: "open_editions" %}`.

**Deal behaviour**: reuse open deal in form pipeline; optional `pipeline_stage_id` advances without regressing; `resolve_pipeline(help_type:)` uses `pipeline_routes` JSON on the form (not template-specific code).

When adding a new public form: Liquid page + optional partials in DB, new `LeadForm` row. Field names only need to match `FIELD_KEY_FORMAT`; no Ruby whitelist to update. Define select options inline with `choices:` in the template.

## Marketing hub

Feature flags `:marketing_consent`, `:marketing_campaigns`, `:marketing_segments`, `:marketing_attribution`, `:journeys`, `:lead_scoring`, `:web_tracking` — menú lateral **Marketing** (Suscripciones, Campañas, Segmentos, Atribución, Recorridos, Puntuación de leads).

```
Consent (SubscriptionType / EmailSubscription / EmailSuppression)
  └── SendGuard en campañas, journeys y record_email masivo
Campañas (Campaign + CampaignSend) → Esp::Client (Mailjet/SMTP)
  └── Webhook POST /e/events → WebhookProcessor → scoring + journeys + supresión
Segmentos (Segment + SegmentMembership) → FilterResolver
  └── SegmentWatcher → JourneyTrigger (segment_entry)
Recorridos (Journey + JourneyStep + JourneyEnrollment) → JourneyRunnerJob
Puntuación (ScoringRule + ScoringEngine) → ScoringRecalculateJob
Tracking (PageView + cream.js) + landings /p/:workspace_slug/:slug
Atribución UTM → AttributionReport
```

- **Detalle completo** (modelos, servicios, rutas, jobs, tests, env): skill **`cream-marketing`**
- **Manual usuario**: §29 en `MANUAL_USUARIO.md` / `USER_MANUAL.md`
- **Landings**: scope por workspace en la URL pública; identificación `cream_aid` al enviar formulario de captación
- **Preferencias**: centro público `/e/preferences/:token`; baja por tipo sin supresión global salvo bounce/spam/unsub-all

## Testing

- Backend tests use **RSpec** (`bundle exec rspec`). Place request specs in `spec/requests/`, model specs in `spec/models/`.
- Always scope data through fixtures (`spec/fixtures/`) and the signed-in user's workspace when testing controllers.
- Mock HTTP clients and async job enqueues — specs must not call external APIs or run real background workers.

## Finishing a change

Before considering a task done:

1. If the change affects **user-visible** behaviour (screens, menus, flows, permissions in the UI), update [`USER_MANUAL.md`](../../../USER_MANUAL.md) and [`MANUAL_USUARIO.md`](../../../MANUAL_USUARIO.md) — see skill `cream-user-manual`.
2. If the change adds or modifies **REST API v1** endpoints, follow skill **`cream-api`** (incl. `docs/openapi.yaml` in the same PR).
3. If the change adds or modifies **MCP tools or OAuth MCP**, follow skill **`cream-mcp`**.
4. If the change adds or modifies **marketing** (campañas, journeys, scoring, tracking, consentimiento), follow skill **`cream-marketing`**.
5. Run `bin/rubocop` (or `bin/rubocop -a`) and fix style issues, then run the relevant specs. Lint is enforced locally via skills, not in CI — see `cream-dev` for commands.

## Production deployment

- **Host**: `<SERVER_IP>` · **user**: `deploy` · **path**: `/home/deploy/cream`
- **URL**: `https://crm.example.com`
- **Image**: `ghcr.io/entaina/cream:latest` (GHCR package)
- **CI/CD**: [`.github/workflows/docker.yml`](../../../.github/workflows/docker.yml) — on push to `main`, build → push GHCR → deploy job SSHs and runs `docker compose pull/up web`
- **Secrets**: GitHub environment **`production`** — `SSH_*`, `GHCR_READ_TOKEN`, `GHCR_USERNAME`, `DEPLOY_PATH` (see [`deploy/README.md`](../../../deploy/README.md))
- **Tenancy in prod**: same workspace model as dev; seeds create org workspace `Example` when `CREAM_ORGANIZATION_*` env vars are set in server `.env`
- **OAuth prod callback**: `https://crm.example.com/auth/google_oauth2/callback` (must match Google Cloud Console)
- **Backups**: `DatabaseBackupJob` daily at 2:00 → Google Drive, `age`-encrypted (`.dump.age`) when `BACKUP_AGE_PUBLIC_KEY` is set; restore with `cream:backup:restore` (destructive, `-e CONFIRM=1`). Commands: skill `cream-dev`; guide: [`deploy/BACKUP_SETUP.md`](../../../deploy/BACKUP_SETUP.md)

Do not confuse repo-root `docker-compose.yml` (local PostgreSQL only) with [`deploy/docker-compose.yml`](../../../deploy/docker-compose.yml) (Traefik + web + db for production).

## Design system

The UI implements the Cream design system, theme **Technology**:

- **Brand families** (full 50–950 scales in the CSS `@theme`): `hoki` (blue-grey, Technology pillar — primary), `copperfield` (copper, Innovation — secondary), `golden` (Golden Tainoi, People — accent), `chicago` (neutral greys, structure). Functional: `red`, `green`, `orange`, `blue`.
- **Grey, never black**: body text is Chicago 900 `#353535` (`ink`); subtle text Chicago 500 (`ink-faint`). This is a brand principle, don't use `#000`.
- **Fonts**: Comfortaa (`font-display`, applied to h1/h2 + brand marks via base layer) and Lato (`font-sans`, body). Loaded from Google Fonts in the layout.
- **White background by default**; sidebar uses `canvas-tint` (Hoki 50, the theme background); cards/hover Chicago 50/100; primary buttons `bg-accent` (Hoki 500) with `text-on-dark` (#f5f5f5).
- **Deal stage colors** map to brand: lead=chicago, qualified=hoki, proposal=copperfield, negotiation=golden, won=green, lost=red (`Deal::STAGES` → `BADGE_COLORS` keys). `List::COLORS` uses the same family names (dynamic `bg-<color>-500` classes are safelisted via `@source inline`).
- **The ellipsis**: "cream..." with three dots in hoki/copperfield/golden is the brand homage (login/registration headers); the three dots mean beginning, not ending.
- Iconography: stroke-based Lucide-style inline SVGs (`IconHelper`), colored via `currentColor` — matches the design system's Lucide convention.
