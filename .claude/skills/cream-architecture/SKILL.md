---
name: cream-architecture
description: Domain model, workspaces, API tokens, conventions, design system and production deployment of the Cream CRM (Attio clone). Use when adding features, models, views, auth, multi-tenancy, UI components, or working on production deploy/infra so everything stays consistent.
---

# Cream — Architecture & conventions

Cream replicates Attio's CRM: workspace-scoped records (People, Companies, Deals) with notes, tasks, lists and an activity timeline.

## Domain model

- Core records: `Company`, `Person` (belongs_to company), `Deal` (stage machine in `Deal::STAGES`: lead/qualified/proposal/negotiation/won/lost, each with label+color; `move_to_stage!` handles kanban moves and logs a `stage_changed` activity).
- Shared concerns: `CrmRecord` (workspace, owner, notes/tasks/list_entries associations) and `Trackable` (auto-logs `created`/`updated` activities with field diffs; per-model `tracked_ignored_attributes`).
- `Note` / `Task` are polymorphic (`notable` / `taskable`) and log activities on their parent record.
- **`Task` assignee:** optional `assignee_id`; default on create is the current user. If the title contains `@handle` for a workspace member, `before_save` assigns the first match via `MentionParser` (same parser as comments).
- `List` + `ListEntry`: typed lists (record_type Person|Company|Deal) shown in the sidebar.
- `Activity`: polymorphic timeline (`subject`), rendered by `ApplicationHelper#activity_sentence`.

## Workspaces & multi-tenancy

The workspace is the **tenant boundary** — all CRM data lives inside one.

```
User ←── Membership ──→ Workspace
              │
         role: admin | member
```

- **`Workspace`**: `name` + unique `slug`. Owns companies, people, deals, notes, tasks, lists, activities.
- **`Membership`**: joins user ↔ workspace. Roles `admin` | `member` (`Membership::ROLES`). One membership per user/workspace pair.
- **`User`**: can belong to **many** workspaces (`has_many :workspaces, through: :memberships`).

**Registration** (`RegistrationsController#create`): creates user + workspace (form `workspace_name` or `"#{name}'s Workspace"`) + membership as `admin`.

**Active workspace per request** — no workspace switcher in the UI yet:

- `User#default_workspace` → `workspaces.order(:id).first`
- `ApplicationController#set_current_workspace` sets `Current.workspace`
- Exposed as `current_workspace`; `ensure_workspace_membership` requires a valid membership or raises `Pundit::NotAuthorizedError`
- Sidebar shows `current_workspace.name` (`shared/_sidebar`)

**Data isolation**:

- All CRM models include `CrmRecord` → `belongs_to :workspace`
- Pundit receives `UserContext` (user + workspace + membership) via `pundit_user`
- `WorkspaceRecordPolicy` scopes with `scope.where(workspace: workspace)` and checks `in_workspace?`
- Controllers always query via `current_workspace` (e.g. `policy_scope(current_workspace.deals)`)

**Roles**: `admin` and `member` exist on `Membership`, but policies currently only check `member?` — admin grants no extra permissions yet.

**Seeds**: demo workspace `Cream Demo` with multiple users (e.g. admin=admin, member=salesperson) sharing one workspace.

When adding features: ALWAYS scope queries through `current_workspace`. If implementing multi-workspace UX, you'll need session-stored workspace selection — today only `default_workspace` is used.

## API tokens

Per-user, per-workspace bearer tokens for programmatic access (MCP, etc.).

- Model: `ApiToken` — `belongs_to :user`, `belongs_to :workspace`
- Prefix: `cream_`; stored as SHA256 digest; plaintext shown once on create (`flash[:api_token]`)
- Created via `ApiTokensController` on `current_user` + `current_workspace`
- Policy: users list/revoke only their own tokens (`ApiTokenPolicy#destroy?` checks `record.user_id == user.id`; scope filters `user` + `workspace`)
- Auth: `ApiToken.authenticate(plaintext)` → sets `@mcp_user` and `@mcp_workspace` in `McpController`
- Routes: `resources :api_tokens, only: %i[index create destroy]`

## UI conventions

- Layout: fixed left sidebar (`shared/_sidebar`), pages are flex columns: `shared/_page_header` (h-13 title bar with actions capture) + scrollable content.
- Record show pages: left attributes panel (w-80, `shared/_attribute` rows) + main column with `shared/_notes_section`, `shared/_tasks_section`, `shared/_timeline`.
- Components are CSS classes in `app/assets/tailwind/application.css`: `.btn-primary/.btn-secondary/.btn-ghost/.btn-danger`, `.input`, `.label`, `.table-base`, `.card`.
- **ViewComponents** (`gem "view_component"`, `app/components/`): reusable UI pieces with Ruby class + ERB template. Use `RecordPickerComponent` for searchable form pickers with optional on-the-fly creation (companies today; people etc. later). Hybrid search: embeds full list when `scope.count <= RecordPickerComponent::INLINE_LIMIT` (200), otherwise queries `search_url` (e.g. `GET /companies/picker.json?q=`). Stimulus: `record_picker_controller.js`.
- **ViewComponents** (`gem "view_component"`, `app/components/`): reusable UI pieces with Ruby class + ERB template. Use `RecordPickerComponent` for searchable form pickers with optional on-the-fly creation (companies today; people etc. later). Hybrid search: embeds full list when `scope.count <= RecordPickerComponent::INLINE_LIMIT` (200), otherwise queries `search_url` (e.g. `GET /companies/picker.json?q=`). Stimulus: `record_picker_controller.js`.
- Theme tokens (`@theme`): `ink` (text), `ink-soft`, `ink-faint`, `line` (borders), `canvas` (bg), `canvas-soft`, `canvas-sunken`, `canvas-tint` (sidebar), `accent`/`accent-dark`/`accent-soft` (Hoki), `on-dark`. Typography scale: `text-base` 15px (body), `text-sm` 14px (buttons/inputs), `text-xs` 13px (labels/meta), `text-2xs` 12px (badges/kbd). Fonts: Lato body, Comfortaa display.
- Helpers: `icon(:name)` (inline SVG set in `IconHelper::ICONS`), `avatar(record)` (initials, deterministic color), `badge`, `stage_badge`, `money`, `sort_link` (sortable table headers preserving query params), `mention_html(text)` (highlight `@mentions` in comments and task titles), `mention_text_field(form, field, **options)` (task title input + mention autocomplete wrapper).
- Stimulus: `kanban_controller.js` (HTML5 drag&drop, PATCH /deals/:id/move), `flash_controller.js` (auto-dismiss), `hotkeys_controller.js` ("/" → search), `mention_controller.js` (`@` autocomplete in task title fields; users JSON in `data-mention-users-json-value`), `record_picker_controller.js` (generic searchable record combobox; used by `RecordPickerComponent`), `row_link_controller.js` (whole-row table navigation: plain click → Turbo, cmd/ctrl+click or middle-click → new tab).
- Index pages: search `?q=` + per-type filters + `sort_link` columns; rows use `row-link` Stimulus + `link_to` on the name cell. Deals table and board share `deals/_filters` partial; board omits stage filter (`show_stage: false`) and strips `:stage` from `@effective_filters`.

## List filtering & saved views

- **`ViewScoped`** concern (`app/controllers/concerns/view_scoped.rb`): `load_saved_views`, `@effective_filters`, `filter_value`, `filter_form_params`, `filters_active?`; merges saved-view JSON with URL overrides (`q`, native key, `cf`, `sort`, `dir`, `closed`, plus `@extra_filter_keys`).
- **`SavedView`**: `NATIVE_FILTER_KEYS` (Deal → `stage`); `EXTRA_FILTER_KEYS` (Deal → `product_id`, `edition_id`, `first_contact_from`, `first_contact_to`). `#resolve` applies native + custom fields + `Deal.apply_extra_filters` for Deal.
- **`Deal.filter_by(scope, filters)`** / **`Deal.apply_extra_filters`**: shared by `DealsController#filtered_deals`, `ExportsController`, and `SavedView#resolve`. Product + edition match the same `deal_products` row; first contact filters join `contacts` on `people.first_contact_on` range.
- **`DealsController#board`**: `load_saved_views("Deal")` then `@effective_filters.except(:stage)` before filtering.

## Mentions (`@usuario`)

Shared service [`MentionParser`](../../../app/services/mention_parser.rb): pattern `@([\w.-]+)`, resolves workspace members by email prefix, exact name or partial name. Used by:

| Surface | Parse on save | Render | Autocomplete UI | Notification |
|---------|---------------|--------|-----------------|--------------|
| **Comments** (`Comment#notify_mentions`) | yes | `mention_html` in `_comments_section` | no (manual `@`) | yes (`NotificationService.notify_mention`) |
| **Tasks** (`Task#assign_from_mentions`) | yes → sets `assignee` | `mention_html` in task lists / dashboard | yes (`mention_controller` + `mention_text_field`) | no (yet) |

Task title fields with mentions: `shared/_tasks_section`, `tasks/index`, `deals/_form` (nested «Next action»).

## Testing

- Backend tests use **RSpec** (`bundle exec rspec`). Place request specs in `spec/requests/`, model specs in `spec/models/`.
- Always scope data through fixtures (`spec/fixtures/`) and the signed-in user's workspace when testing controllers.
- Mock HTTP clients and async job enqueues — specs must not call external APIs or run real background workers.

## Finishing a change

Before considering a task done:

1. If the change affects **user-visible** behaviour (screens, menus, flows, permissions in the UI), update [`USER_MANUAL.md`](../../../USER_MANUAL.md) and [`MANUAL_USUARIO.md`](../../../MANUAL_USUARIO.md) — see skill `cream-user-manual`.
2. Run `bin/rubocop` (or `bin/rubocop -a`) and fix style issues, then run the relevant specs. Lint is enforced locally via skills, not in CI — see `cream-dev` for commands.

## Production deployment

- **Host**: `<SERVER_IP>` · **user**: `deploy` · **path**: `/home/deploy/cream`
- **URL**: `https://crm.example.com`
- **Image**: `ghcr.io/entaina/cream:latest` (GHCR package)
- **CI/CD**: [`.github/workflows/docker.yml`](../../../.github/workflows/docker.yml) — on push to `main`, build → push GHCR → deploy job SSHs and runs `docker compose pull/up web`
- **Secrets**: GitHub environment **`production`** — `SSH_*`, `GHCR_READ_TOKEN`, `GHCR_USERNAME`, `DEPLOY_PATH` (see [`deploy/README.md`](../../../deploy/README.md))
- **Tenancy in prod**: same workspace model as dev; seeds create org workspace `Example` when `CREAM_ORGANIZATION_*` env vars are set in server `.env`
- **OAuth prod callback**: `https://crm.example.com/auth/google_oauth2/callback` (must match Google Cloud Console)

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
