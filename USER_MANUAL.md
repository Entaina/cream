# User Manual — Cream

> 🇪🇸 [Versión en español](MANUAL_USUARIO.md)

Cream is a **workspace**-based CRM for managing **people**, **companies** and **deals** (opportunities), with notes, tasks, lists and an activity history shared across the team.

> **Last revision:** 2026-09-30 (bookings: the host email attaches an .ics file)
> This document describes the functionality **visible to the user**. Disabled features are listed at the end under "Coming soon".

---

## Table of contents

1. [Account and access](#1-account-and-access)
2. [Workspaces](#2-workspaces)
3. [Navigation](#3-navigation)
4. [Dashboard](#4-dashboard)
5. [People, companies and deals](#5-people-companies-and-deals)
6. [Products](#6-products)
7. [Tasks](#7-tasks)
8. [Lists](#8-lists)
9. [Pipelines and kanban board](#9-pipelines-and-kanban-board)
10. [Saved views](#10-saved-views)
11. [Custom fields](#11-custom-fields)
12. [Magic columns](#12-magic-columns)
13. [Record page](#13-record-page)
14. [CSV import and export](#14-csv-import-and-export)
15. [Email from records](#15-email-from-records)
16. [Automations](#16-automations)
17. [Configurable alerts](#17-configurable-alerts)
18. [Webhooks](#18-webhooks)
19. [Notifications](#19-notifications)
20. [Team and invitations](#20-team-and-invitations)
21. [Workspace settings](#21-workspace-settings)
22. [API tokens and MCP](#22-api-tokens-and-mcp)
23. [Reports](#23-reports)
24. [AI assistant](#24-ai-assistant)
25. [Knowledge chat](#25-knowledge-chat)
26. [Stripe payments](#26-stripe-payments)
27. [Lead capture forms](#27-lead-capture-forms)
28. [Calendar bookings](#28-calendar-bookings)
29. [Marketing](#29-marketing)
30. [Coming soon](#30-coming-soon)

---

## 1. Account and access

### Sign in

On the sign-in screen you can:

- **Sign in with Google** (if configured in your environment).
- Use an **email and password** registered in Cream.

If you forgot your password, use **Forgot password?** to receive a reset link by email.

In the top-right corner of the sign-in (and registration) screen you will see the **ES | EN** switch. Choose the interface language; the preference is stored in your browser until you create an account or sign in.

### Create account

In **Create account** you enter your name, email, password and the workspace name. When you sign up:

- Your user is created.
- A new workspace is created with the given name (or «Name's Workspace» if you don't provide one).
- You are the **admin** of that workspace.

### Change your name

1. Open **Profile** (also from your name at the bottom of the sidebar).
2. In **Personal details**, edit your **Name** and, if you want, **Language** (Español / English).
3. Click **Save**.

Your name updates in the sidebar, mentions and team activity. Language affects the menu, login, app chrome and shared record sections (notes, tasks, activity…). The email is shown in the same section, but it cannot be changed from there.

You can also switch language on the fly with **ES | EN** at the bottom of the sidebar (next to the light/dark theme control).

### Sign out

At the bottom of the sidebar, click the exit icon next to your name.

---

## 2. Workspaces

A **workspace** is the team's shared working space. All records (people, companies, deals, etc.) belong to a specific workspace.

### Switching workspaces

If you belong to more than one workspace, the sidebar header shows the name of the current workspace. Click it to open the list and switch to the one you want.

### Roles

| Role                | Description |
|---------------------|-------------|
| Admin               | Full access to the workspace: invite members, change roles, edit the workspace name, manage custom fields and see **all** deals. |
| Director comercial (sales director) | Sees and edits **all** deals; can add collaborators on any deal. Does not manage invitations, roles or workspace settings. |
| Vendedor (salesperson) | Sees and edits only the deals they are **Owner** of or where they have been granted access as a **collaborator**. People, companies, tasks and all other records remain visible to the whole workspace. |

**Salespeople** only see their own or shared deals on the **Dashboard** and in **Deals**. **Admin** and **Director comercial** see all deals in the workspace.

---

## 3. Navigation

The left sidebar concentrates the main navigation. On **small screens (mobile)** the menu is hidden by default: tap the **hamburger** icon (☰) in the page header to open it. Tap outside the menu, press **Escape** or navigate to another section to close it. On desktop the menu is always visible.

Above the menu (**Search…**, **Notifications**) and below the **active pipeline** selector, entries are grouped as follows.

Some entries are **optional per workspace** and are **hidden by default**. An administrator can enable them under **Settings → Funcionalidades** (Features): **Reports**, **Atribución** (Attribution), **Puntuación de leads** (Lead scoring), **Webhooks** and **Custom fields**.

**Daily use** (always visible, not collapsible):

| Entry | Description |
|-------|-------------|
| **Search…** | Global search. Shortcut: `/` |
| **Notifications** | Workspace alerts (mentions, alerts, forms, bookings…) |
| **Dashboard** | Workspace overview |
| **People** | Contacts; may include **saved views** submenu |
| **Companies** | Companies; saved views |
| **Deals** | Kanban board; saved views |
| **Tasks** | All workspace tasks |

**Marketing** (collapsible group; see [§29](#29-marketing)):

| Entry | Description |
|-------|-------------|
| **Suscripciones** (Subscriptions) | List types and consent |
| **Campañas** (Campaigns) | Bulk sends to segments |
| **Segmentos** (Segments) | Filtered audiences |
| **Atribución** (Attribution) *(optional)* | UTM report |
| **Recorridos** (Journeys) | Automated sequences |
| **Puntuación de leads** (Lead scoring) *(optional)* | Scoring rules |
| **MQLs** | Marketing-qualified contact pool |
| **Plantillas** (Templates) | Email templates (campaigns, records, forms) |

**Configuración** (Settings group — **admins** only):

| Entry | Description |
|-------|-------------|
| **Team** | Members and invitations |
| **Products** | Product catalog |
| **Pipelines** | Stages, triggers, conditions |
| **Custom fields** *(optional)* | Custom fields |
| **Alertas** (Alerts) | Date-based alert rules |
| **Automations** | Event-driven automations |
| **Formularios** (Forms) | Public web capture |
| **Stripe** | Imported payments and reconciliation |
| **Webhooks** *(optional)* | Outgoing HTTP integrations |
| **Reports** *(optional)* | Reports and CSV export |
| **Settings** | Workspace settings (OKM, Mailjet, permissions…) |

**Mi perfil** (My profile — each user):

| Entry | Description |
|-------|-------------|
| **Profile** | Name, language, time zone, default pipeline, AI briefing, alert channels |
| **Gmail** | OAuth to send from records and detect replies |
| **Reservas** (Bookings) | Public calendar booking pages |
| **Mis listas** (My lists) | Workspace lists |
| **API tokens** | MCP / REST API v1 tokens |

You can also open **Profile** by clicking your **name** at the bottom of the sidebar.

Entries for disabled features **do not appear** until enabled (see [Coming soon](#30-coming-soon)). Example today: **Mail merge**.

### Customizing the menu

Next to the **Menu** title in the sidebar there is a gear icon. Clicking it enters **edit mode**:

- **Reorder:** drag a section by the grab icon (⋮⋮) to the position you want.
- **Hide or show:** use the eye icon on each section. Hidden entries no longer show in the normal menu, but remain visible (dimmed) while editing so you can restore them.

Changes are saved automatically for **your user** when you leave edit mode (click the gear again). Each person in the workspace has their own configuration; it does not affect Search or Notifications. You can hide entries from any group (including Marketing or My profile) without removing them from the workspace.

### Active pipeline

Below the workspace name, the sidebar shows the **active pipeline**. You can choose your default pipeline for that workspace in **Settings → Profile**. It is the one selected when you sign in and when you open the Gmail add-on. When you change the active pipeline:

- **Deals** (board and table) filter by that pipeline.
- **Dashboard** and **Reports** use that pipeline as the default filter in deal metrics.
- The **Todos los pipelines** (all pipelines) option removes the deal filter: the dashboard and reports **group stages by name** (one bar per stage, stacked segments per pipeline; hover each segment to see that pipeline's count), the kanban board shows **one column per stage name** (each card shows its pipeline), and the table view adds a **Pipeline** column.

The selection is stored per user and workspace, and persists across sessions. You can also change it from the selectors in Deals and Dashboard when there are several pipelines.

### Light and dark theme

At the bottom of the sidebar, next to your name, there is a button that toggles the application **theme**. Each press moves to the next mode:

| Icon | Mode | Behavior |
|-------|------|----------------|
| ☀️ Sun | **Light** | Always light background |
| 🌙 Moon | **Dark** | Always dark background |
| 🖥️ Monitor | **System** | Automatically follows the operating system theme (default) |

The preference is stored on your user, so it persists across sessions and devices. The change applies instantly, without reloading the page.

---

## 4. Dashboard

The dashboard shows a workspace overview:

- **My tasks:** your upcoming pending tasks, in the main block at the top of the dashboard (mark them complete with one click).
- **Director de ventas (sales director):** daily AI-generated briefing with guidance for the team, classified as **Urgente** (urgent) and **Importante** (important). It only appears in workspaces where an administrator has enabled it in **Settings** (checkbox *Briefing diario del director de ventas*), and it also requires AI to be configured on the server (`CREAM_AI_API_KEY`). Each user can turn it off for themselves in **Settings → Profile** (checkbox *Mostrar briefing del director de ventas en el dashboard*); you can also open Profile from your name at the bottom of the sidebar. To enrich the report, the director uses CRM read tools, the workspace **OKM** (if configured) and **persistent memory** (llmemory) with learnings from previous briefings. In addition, each user who has it enabled receives a **Para ti** (for you) block with direct guidance, **Aciertos** (congratulations on recent wins) and **A mejorar** (mistakes or omissions with a recommendation). If a deal already has a **next action** (an open task with a future date), the briefing does not ask for parallel actions nor flags it as inactive; at most it may suggest **moving that date up**. Deals without an open task can appear as pending a defined next step. If there is no briefing for the day yet, you can click **Generar ahora** (generate now); if one already exists, you can click **Regenerar** (regenerate) up to 5 times a day (the number of regenerations you have left is shown). Guidance items can link to deals, people, companies or tasks; in the team block, the ones assigned to you are highlighted.
- **Metric cards:** number of people, companies, open pipeline value and won revenue (deals in a *won* stage). Deal metrics respect the **active pipeline** (see above); people and companies cover the whole workspace.
- **Pipeline by stage:** bars showing the distribution of deals per stage. If you have an active pipeline, the chart and the deal cards use that pipeline; if you choose **Todos los pipelines**, the cards add up all deals and the chart groups stages by name with bars stacked by pipeline (each segment shows that pipeline's count on hover).
- **Recent activity:** the team's latest actions (creations, field changes, stage changes, etc.).

Click any card or link to go to the corresponding list.

---

## 5. People, companies and deals

The three record types share a similar pattern in the interface.

### Lists (table)

Each list includes:

- **Text search**. For people it searches name, email and job title; for companies name, domain and industry; for deals the deal name, **the name of the associated company** and the **invoice number** (if set).
- **Type-specific filters** per record type (see the table below in [Deals → Filters](#deal-filters)).
- **Custom field filters** when they exist.
- **Sortable columns** (click the header).
- **Magic columns** and **custom fields** as extra columns.
- **New …** buttons to create a record.

Click a row to open the record page. **Cmd/Ctrl+click** or **middle click** (mouse wheel) opens the record in a new tab without losing the list.

The list shows **50 records per page**. When there are more, a pagination bar appears at the bottom with the **Anterior** / **Siguiente** (previous / next) buttons and the page indicator; when changing pages the active search, filters and sorting are kept. The counter next to the title reflects the total number of records, not just those on the current page.

**Session persistence:** if you apply a search or filters and then navigate to another screen (for example, you open a record and return to the list from the sidebar), Cream **remembers the active filters and the pagination page** while you stay signed in. When you return to the list they are restored automatically. Click **Clear** (or the **All** tab in saved views) to go back to the unfiltered list. This memory is **per session**: when you sign out or start a new session, filters are not kept (to store them permanently use [saved views](#10-saved-views)).

### People

- Can be linked to a **company**.
- Usual attributes: name, email(s), phone, job title, location, owner.
- **Multiple emails per contact:** a person can have more than one address (personal, work, alias, etc.). The record page lists all of them; the one marked **Principal** (primary) is the one used by default when sending emails from Cream and the one shown in the list. To add, remove or change which one is primary, click **Edit** on the record: the **Emails** section lets you add rows with **Add email**, mark the primary one and delete addresses.
- People **search** finds contacts if the term matches **any** of their emails, not just the primary one.
- In the list you can filter by **company** (*All companies*) and by **owner** (*All owners*), in addition to search and custom fields.
- **Quick edit in the list:** **double-click** the **Company** or **Owner** cell to change that value without opening the record. The same control as in the edit form appears (company search box with the **+ Create "…"** option, or owner selector with **Unassigned**). Choosing a value saves instantly and the cell updates; press **Escape** to cancel without saving. A single click on the rest of the row still opens the record.
- When creating or editing a person, the **Company** field is a search box: type part of the name (or domain) and choose one of the suggestions. If the name doesn't exist, the **+ Create "…"** option appears to create the company on the spot without leaving the form.
- When creating or editing a person, next to the **LinkedIn URL** field there is a **Buscar en LinkedIn** (search on LinkedIn) button: it opens LinkedIn profile search in another tab with the name and company already filled in. When you find the right profile, copy its URL and paste it into **LinkedIn URL**.
- **Relationships between contacts:** in the left panel of the record, the **Relationships** section lets you link this person with another one in the workspace. Choose the other person, the relationship type (**Invitó a**, **Referido por**, **Trabajó con**, **Colega de** — invited, referred by, worked with, colleague of) and click **Add**. The relationship is stored with a direction: what you declare from the current record is the origin (for example, «Ana invitó a Bruno» — Ana invited Bruno). On Bruno's record you will see the consistent inverse label («invitado por Ana» — invited by Ana). You can delete the relationship from either of the two records; it disappears from both.
- **Create a deal from the record:** click **Add deal** in the top bar. A dialog opens where you choose the **pipeline** (by default yours from *Settings → Profile*, or the workspace's if you don't have one), the **product** and the **first action** (title and date). The deal is created in the **first stage** of the chosen pipeline, with the person's company and contact; the name is generated as «Empresa — Producto» (Company — Product). After creating it you go to the deal page. If there are validation errors, they are shown inside the same dialog without leaving the record. If there are no products in the catalog, the dialog tells you that you must create one first.
- **Person's deals:** on the **Activity** tab, the **Deals** section lists deals where the person is a contact and that you can see, newest first. Each row shows the name (link to the deal), the **stage**, the creation date and the **products**. The first five are always visible; the rest are under **Show N more deals**. If there are more than five, **View deals (N)** opens the **Deals** tab, with the full list. When those deals involve more than one distinct product, that tab includes the **All products** filter.
- **Subscriptions** (marketing): when the consent module is active, the left panel lists each **subscription type** (general, newsletter, etc.) with its status (**Suscrito** / Subscribed, **Dado de baja** / Unsubscribed or **Pendiente** / Pending). You can **Suscribir** / **Subscribe** or **Dar de baja** / **Unsubscribe** manually, and copy the link to the contact's **preference center** (see [§29](#29-marketing)).
- **Lead score** and **Lifecycle**: with lead scoring enabled, the left panel shows the numeric score and lifecycle stage (*subscriber*, *lead*, *mql*, *sql*, *opportunity*, *customer*, *evangelist*). Lifecycle reflects automatic scoring; it is **not** the same as having an open sales **deal**.

**Possible duplicates**

In the **People** list, the **Possible duplicates** button opens a summary of contacts with the **same email** in the workspace (even if they belong to different companies). The number next to the button indicates how many duplicate groups there are.

1. Review each group (email, companies involved and contacts).
2. Click **Review merge** to open the merge assistant.
3. The oldest contact is proposed as the record to keep; you can change the selection on the merge screen.

**Merging contacts**

From a person's record, **Merge** opens the same assistant:

1. At the top you see the contact that will be **kept** (including their company).
2. Check one or more suggested contacts to merge: those from the **same company** and, if the contact has email(s), also other contacts that share **any** of those addresses in other companies.
3. If the contact you're looking for doesn't appear, use the **Search for other contacts** box to find and add **any other contact in the workspace**.
4. Confirm the action.

When merging, the notes, tasks, deals, emails and timeline activity of the selected contacts move to the kept contact. The duplicates' email addresses are merged into the resulting contact (without repeating the same address). The resulting contact **stays in the company of the contact you keep**. The main contact's fields take priority; if data is missing (phone, job title, etc.), it is filled in from the duplicate. The action is **irreversible** and is recorded on the resulting contact's timeline.

### Companies

- Usual attributes: name, domain, industry, size, location, owner.
- When creating or editing a company, next to the **LinkedIn URL** field there is a **Buscar en LinkedIn** (search on LinkedIn) button: it opens LinkedIn company search in another tab with the name already filled in. When you find the right page, copy its URL and paste it into **LinkedIn URL**.
- **Fiscal information** field: a free-text box on the company form to note all tax details (legal name, CIF/NIF, tax address, IBAN, etc.). If filled in, it appears as its own section in the left panel of the record.

**Possible duplicates**

In the **Companies** list, the **Possible duplicates** button opens a summary of companies with a **similar name** (e.g. *Mapfre* and *Mapfre España*) or the **same web domain**. The number next to the button indicates how many duplicate groups there are.

1. Review each group (reason for the suggestion and companies involved).
2. Click **Review merge** to open the merge assistant.
3. The oldest company is proposed as the record to keep; you can change the selection on the merge screen.

**Merging companies**

From a company's record, **Merge** opens the same assistant:

1. At the top you see the company that will be **kept**.
2. Check one or more companies suggested as duplicates that you want to merge into it.
3. Confirm the action.

When merging, the contacts, deals, notes, tasks, emails and timeline activity of the selected companies move to the kept company. If two contacts had the same email, they are automatically merged into one. The main company's fields take priority; if data is missing (domain, industry, etc.), it is filled in from the duplicate. The action is **irreversible** and is recorded on the resulting company's timeline.

### Deals

- They represent sales opportunities with **value**, **currency**, **stage**, **probability**, **expected close date**, optional **execution duration** (days) and optional **invoice number** (*Nº factura*). You enter the exact amount (including cents) and it is shown the same way on the **record page**, **table** and **board**; whole euros are shown without trailing zeros.
- They are linked to a **company** and an **owner**; **contacts** are optional.
- They can include **product lines** (catalog products with quantity and price).
- When **creating a deal** (`New deal`):
  - Choose **Pipeline** and **Stage** to decide which stage the opportunity enters.
  - In **Company**, type to search for the company and pick a suggestion; if it doesn't exist, use **+ Create "…"** to create it on the spot. **Contacts** are optional (you can create a new one with **New** without leaving the form).
  - In the **New contact** dialog you can enter **First name** (required), **Last name**, **Email**, **Phone**, **Contact source** (*Formulario web*, *Recomendado*, *Lo trae alguien del equipo* — web form, referral, brought in by a team member) and **First contact date**.
  - In **Products of interest** you can add catalog products with **Edition** (searchable picker: select an existing one or **+ Create "…"**) and quantity before saving.
  - You must define a **Next action** (a task with a future date) to be able to create the deal.
  - Optionally set **Execution duration (days)** and **Nº factura** (invoice number) when you already have them; you can also add or change them later when editing the deal.
- They have a **Version history** that stores every change to the deal's attributes (value, name, probability, etc.) and lets you check what the deal looked like at a specific moment.
- When **editing** a deal and saving a stage change to **Won**, a brief celebration animation is shown on screen before returning to the record. If the new stage is **closed** but not a winning one (e.g. *Lost*), a defeat animation is shown. The same happens when changing stage with the **Move to stage** buttons on the deal page. It does not happen when moving cards on the kanban board. If the target stage has **entry conditions** that the deal does not meet, the change is rejected, an error notice is shown and the deal remains in its original stage.
- From a deal's page you can **Duplicar** (duplicate) the deal with one click: a copy is created with the same name plus «(copia)» (copy), company, contacts, stage, value, currency, probability, close date, execution duration, owner, custom fields and in-progress tasks. The **invoice number is not copied**. Product lines, notes, attachments, emails and the activity history are not copied.
- On the deal page, the **Colaboradores** (collaborators) section lets the **Owner**, an **Admin** or a **Director comercial** add or remove **salespeople** with access to that deal. A collaborator can view and edit the deal even if they are not the owner. Salespeople who are neither owner nor collaborators will not see that deal in lists, board or dashboard.

### Deal filters {#deal-filters}

In the **table view** and on the **kanban board** you can combine several filters; when any control changes, the list updates instantly. Click **Clear** to remove all active filters.

| Filter (on-screen label) | Table view | Board | What it does |
|-------------------------------|:-----------:|:-------:|----------|
| **Search deals…** | yes | yes | Searches by deal or company name, or invoice number |
| **All stages** | yes | no | Shows only deals in the chosen stage (not applicable on the board: columns already are stages) |
| **All products** | yes | yes | Deals that include that product in their lines |
| **All editions** | yes | yes | Deals with a line that has that specific edition (the dropdown **groups editions by product**; the same name may exist on different products) |
| **First contact from / to** (date fields) | yes | yes | Deals whose contact has a **First contact date** within the range (if there are several contacts, it is enough that one matches) |
| Custom fields | yes | no | Same as for people and companies |

Active filters are kept when switching between **Board** and **Table**, when paginating, when enabling **Show closed** and when exporting CSV. They can also be **saved in a view** (see [§10](#10-saved-views)).

**Deal list views:**

- **Board** (Deals menu): kanban board by stage — drag cards between columns to change stage. Filter bar with search, product, edition and first-contact range, plus **saved views** tabs (same as the table).
- **Table** (button on the board): table view with the same filters (including stage), saved views, custom fields and CSV import/export. With **Todos los pipelines** active, the table includes a **Pipeline** column before the stage.

On the board, a saved view with a **stage** filter does not restrict the columns (stages already are columns); the other filters do apply.

---

## 6. Products

The **Products** catalog stores reusable products for creating lines in a deal. From a deal page — or when **creating a new deal** — you can add products with quantity, edition and unit price; the deal value can reflect those lines.

Each product can be tagged with a **B2B** or **B2C** **segment** when creating or editing it. In the product list you can filter and sort by segment.

On a product's edit page, the **View deals** button opens the **Deals** list (table view) filtered to that product and including closed deals. From there you can refine with the usual filters: edition, owner, stage, etc.

### Editions

Each product has **its own editions** (variants or cohorts). **There is no global Editions tab** — they are managed inside each product.

1. Go to **Products** and open a product (**Edit**).
2. In the **Editions** section you will see the edition table (name, dates, lines in use).
3. Click **New edition** to create one; edit or delete from the same section.
4. Each edition has a **name** and optional **start** and **end** dates.

On deal product lines:

- The **Edition** field is a **searchable picker** that only shows editions **for that line's product**.
- When **adding** a new line, choose the product first; then Edition is enabled and loads that product's editions.
- Type to filter (dates appear next to the name), pick one or use **+ Create "…"** to add a new edition on the fly (it is linked to that product).
- Editions created on the fly have no dates until you complete them on the product page.

---

## 7. Tasks

Tasks can be created:

- From the **Tasks** section of the menu (workspace-wide view).
- From a person, company or deal page.
- When **creating a new deal**, in the «Next action (required)» block.

Each task has a **title**, a **due date**, an **assignee** and a **pending / completed** status. Overdue tasks are shown in red. On the dashboard and in Tasks you can mark a task as done with one click.

### Mentioning and assigning with @

When typing a task **title** you can mention a workspace teammate:

1. Type `@` in the title field.
2. A dropdown with the team members appears; keep typing to filter by name or by email prefix (e.g. `@ana` for `ana@…`).
3. Choose with the mouse or with the ↑↓ arrows and **Enter** (or **Tab**).
4. When the task is saved, it is **automatically assigned** to the mentioned person (if there are several mentions, the first one counts). If you mention no one, the task is assigned to whoever creates it.
5. The mention stays in the title and is shown **highlighted in color** in the list, the dashboard and record pages.

> **Comments vs tasks:** in **Comments** you can type `@name` by hand (no dropdown) and you will receive a **notification**. In **Tasks**, the `@` mention includes autocomplete and **assigns** the task, but **does not generate a notification yet**.

---

## 8. Lists

**Lists** group records of a single type (Person, Company or Deal) with a name and a color. They live under **Mi perfil** → **Mis listas** (My lists); the submenu gives quick access to each list.

- Create a list with the **+** button next to **Mis listas**.
- Add or remove records from the record page or from the list view.
- **Journeys** can include an **Add to list** step to add contacts automatically.
- For bulk email with consent and metrics use **Campaigns** + **Segments** ([§29](#29-marketing)); CRM lists are useful for manual follow-up and journey steps.

---

## 9. Pipelines and kanban board

A **pipeline** defines the **stages** a deal moves through (name, color and close probability).

### Managing pipelines

In **Pipelines** you can:

- Create a new pipeline with its stages.
- Edit stages, probabilities and colors.
- **Reorder stages** by dragging the row by its handle (dots icon) while editing a pipeline; save the changes with **Save changes**.
- Mark a pipeline as the **default** (the one used by new deals).
- Choose which **fields are visible on board cards** (checkboxes when editing the pipeline): value, company, owner, close date, probability, **execution duration**, **invoice number**, contacts, products and editions. Default: value, company, close date and owner.
- **Duplicate** a pipeline (copies the stages and the board field selection, not the deals).
- Create from predefined **templates** (Sales, Recruiting, etc.).
- Configure **per-stage triggers** (⚡ icon next to each saved stage): AI actions or predefined functions that run when a deal enters the stage — see [Automations](#16-automations).
- Configure **per-stage field formats** (eye icon next to each saved stage): rules that change how a deal field is **displayed** while it is in that stage. For example, showing «guest» instead of «0 €» when the price is zero. Each rule has: a field (price, probability or close date), a condition (*es igual a*, *es menor que*, *es mayor que* or *está vacío* — equals, less than, greater than or is empty — with its value) and the text to display. The first matching active rule wins. It only affects presentation (record page, table and board); the stored data does not change, and the board column totals still use the real value.
- Configure **per-stage entry conditions** (lock icon next to each saved stage): rules that **block** moving a deal into that stage until they are met. Each condition picks a field (from the deal, its company or its contacts — including custom fields), an operator (*es igual a*, *no es igual a*, numeric or date comparisons, *contiene*, *está vacío* or *tiene valor* — equals, not equals, contains, is empty or has a value) and, except for empty/present, a reference value. **All** active conditions must be met. For **contact** fields, it is enough that **some** contact of the deal meets the rule (except *está vacío*, which requires that no contact has a value). If you try to move the deal without meeting them — on the board, on the record page or when editing — you will see an error notice and the deal will remain in its current stage.

### Kanban board

In **Deals** (board view):

- Each column is a stage; the header shows probability, number of deals and total value.
- **On mobile**, the board shows **one stage at a time**. Swipe left or right to move to the next or previous stage. You can also use the arrows and the «etapa X / N» (stage X / N) indicator below the header.
- **Filter bar** below the title: search, product, edition and **First contact date** range. There is no stage filter (the columns already represent the stages).
- **Drag** a card to another column to move the deal to another stage. The change is saved instantly and the column counters and totals update on their own, without reloading the page. If the move cannot be saved (e.g. because of the target stage's entry conditions), the card returns to its original column and an **error notice** appears at the top of the screen.
- **Reorder the columns** by dragging a stage header by the dots icon; the new order is saved on drop.
- If there are several pipelines, you can also change the active pipeline from the header selector. With **Todos los pipelines**, the board groups columns **by stage name** and each card shows its **pipeline**; dragging a deal to another column moves it to the same-named stage **within its pipeline** (it does not change pipeline).
- Cards with **pending tasks** show a task icon in the top-right corner: **red** if any task is overdue, **blue** if all are on time or have no due date. **Hover** over the icon to see the next pending task (title, due date and assignee) without opening the deal page; if there are several pending ones, it also shows how many remain.
- The fields visible on each card (value, company, owner, close date, probability, execution duration, invoice number, contacts, products and editions) depend on the active pipeline's configuration — see [Managing pipelines](#managing-pipelines).
- From a deal's page you can also change stage (**Move to stage** buttons; the selector updates instantly) or **move it to another pipeline** (it will start in the first stage of the target pipeline).

### Closed stages (won / lost)

By default, stages marked as **closed** (e.g. *Won* and *Lost*) are **not shown**:

- On the **board** their columns do not appear.
- In the **list (table)** the deals in a closed stage do not appear, and the stage filter only lists open stages.

To see them, click **Show closed** in the Deals header (board or table). When enabled:

- The board adds the closed-stage columns.
- The table includes closed deals and the stage filter also lists the closed stages.

The state is kept in the URL (`?closed=1`) while you navigate, and it hides again when you remove the filter.

---

## 10. Saved views

In the **People**, **Companies** and **Deals** lists (board and table), the tabs at the top let you save combinations of filters and sorting:

1. Apply search and filters (for deals on the board: product, edition and first-contact range; on the table also stage and custom fields).
2. Type a name in **View name**.
3. Check **Shared** if you want the whole workspace to see it (otherwise it is personal).
4. Click **Save view**.

Saved views also appear as links under the corresponding entry in the sidebar. In **Deals**, those links open the **board** with the view active.

With a view active you can **Update view** if you change filters, **Rename**, mark it as shared or **Delete view**.

---

## 11. Custom fields

This section is **hidden by default**. An administrator must enable **Campos personalizados** (Custom fields) under **Settings → Funcionalidades** to see the menu entry and manage fields.

In **Custom fields** (admins only) you define extra attributes per record type.

### Available types

| Type          | Use |
|---------------|-----|
| Text          | Short text |
| Long text     | Long text |
| Number        | Number |
| Currency      | Amount |
| Date          | Date |
| Boolean       | Yes / No |
| Select        | One option from a list |
| Multi select  | Several options |
| URL           | Link |
| Email         | Email address |
| Record reference | Link to another person, company or deal in the workspace |
| Formula       | Automatically calculated value |

**Formula** fields evaluate an expression over other fields of the same record (e.g. sums or conditions). They are not edited by hand on the record page.

**Record reference** fields link the current record to another person, company or deal in the same workspace. When creating the field you choose the target object type; forms and lists show a selector with the available records, and on the record page the value is displayed as a link with an avatar.

Fields appear in create/edit forms, in the record's attribute panel and as columns/filters in the lists.

---

## 12. Magic columns

In the people, companies and deals tables, Cream adds automatically calculated columns:

| Column         | People / Companies / Deals | Description |
|----------------|----------------------------|-------------|
| Last activity  | All                        | Date of the last recorded activity |
| Notes          | All                        | Number of notes |
| Tasks          | All                        | Total number of tasks |
| Open tasks     | All                        | Pending tasks |
| Days in stage  | Deals only                 | Days in the current stage |

> Magic columns are available in the list **tables**; not yet on the kanban board cards.

---

## 13. Record page

### People

The contact header shows their name, company and main contact details. Use **Send email**, **Add note**, **Create task** or **Add deal** when you need them: the editors open on demand. **Edit** opens the grouped contact form; **Merge duplicates** and **Delete contact** are in the **•••** menu.

- **Activity** opens by default. The main column shows, in order: **Deals** (the ones you can see, with stage, date and products; five visible and the rest under **Show N more deals**; if there are more than five, **View deals (N)** opens the tab), **Next tasks** (overdue first, then upcoming; expand the rest or completed tasks when needed) and **History** (notes, emails, comments, contact changes and **stage changes on their deals**). A stage change reads as “Ana moved deal Name from Proposal to Negotiation”; when the stage is a win, “Ana won deal Name”. The deal name is a link. Those changes appear under the **All** and **Changes** filters. Use **Older / Newer** to paginate. In the context column, **Campañas enviadas** (Campaigns sent) lists the latest marketing campaigns this contact received; **Recorridos** (Journeys) shows enrollments (active, waiting, completed or cancelled) with the current step. **Ver más** (View more) opens the full history (see [§29](#29-marketing)).
- **Deals** contains the full list and the **All products** filter when there is more than one product, plus product interests and form submissions when enabled. Expand **Registrar interés** to add an interest.
- **Information** groups contact details, professional profile, ownership, relationships, custom fields, email preferences and, when submissions exist, **Formularios enviados** (Form submissions) with a **Ver consentimiento** link to the accepted policy and statement. Each editable block has its own **Edit** link. Expand **Add relationship** to link another person.
- **Files**, when enabled, contains the upload form and existing attachments.

Closing an editor or switching sections keeps its draft while you remain on the page. Leaving with unsaved drafts prompts you first. Drafts are not saved across a reload. Editing a block only submits that block; **Save changes** returns to Information, and **Cancel** leaves the contact unchanged.

On mobile, use the section tabs in a single column; note, task, comment and email editors fill the screen. Tabs also support arrow keys, Home and End, and editors close with Escape.

### Companies and deals

When you open a company or deal you will see:

**Left panel (attributes):** main data, custom fields, relationships between contacts (people only), lists it belongs to and (for deals) the pipeline and stage selector. On **people**, depending on enabled features, you may also see **Subscriptions**, **Lead score**, **Lifecycle**, **Product interests** and **Form submissions** (see [§29 Marketing](#29-marketing)).

> **On mobile** the record page shows one panel at a time: swipe left or right to switch between the attributes panel and the main column.

**Main column:**

| Section      | Description |
|--------------|-------------|
| **Colaboradores** | Deals only: salespeople with shared access (see the [Deals](#deals) section) |
| **Products** | Deals only: product lines |
| **Notes**    | Free-text notes; they remain in the history |
| **Comments** | Team comments; mention with `@name` typed by hand (generates a notification) |
| **Attachments** | Files attached to the record |
| **Send email** | Send an email from the record (see [Email](#15-email-from-records)) |
| **Tasks**    | Tasks linked to the record; when creating one, use `@` in the title to autocomplete and assign to a teammate |
| **Timeline** | Automatic history: creation, field changes (with diff), stage changes, contacts, products, notes, tasks, **contact merges**, **company merges**, **sent emails**, opens, clicks and replies |

### Version history (deals only)

From a deal's page, the **Version history** button opens the deal's change log:

1. It shows **field changes** (value, name, probability…), **notes**, **comments**, **stage** changes, **contacts**, **products**, completed tasks, etc., ordered by date.
2. Field-change rows are links: click one to see the deal's **snapshot** at that instant (value, stage, probability, close date, etc.).
3. From there you can go back to the current deal or browse the rest of the history.

The **Timeline** on the deal page shows the same kind of events (latest 50 entries); **Version history** gathers the entire browsable history and lets you reconstruct the deal's state at a specific date.

---

## 14. CSV import and export

In the **People**, **Companies** and **Deals** lists (table view):

- **Import:** upload a CSV file to create records in bulk.
- **Export:** download a CSV with the visible records according to the current filters (for deals it includes stage, product, edition and first-contact range if active).

Use the export as a reference for the format expected by imports.

---

## 15. Email from records

From the detail page of a **person**, **company** or **deal**, the **Send email** section lets you write and send an email to the contact without leaving Cream. Every send is linked to the record and to the team's history.

### How to access

For a person, click **Send email** in the header. For a company or deal, scroll down to the **Send email** section in the main column.

### Sending an email

1. Fill in **To** (recipient) and **Subject**. Write the body with the **rich text editor** or with **HTML** (tables, images, a full document). If you switch from HTML to the rich text editor and the content uses tags that would be lost, you will see a warning and can cancel.
2. Click **Send email**.
3. The email stays in the history with the **Sending** label until it goes out (from the workspace address via SMTP, or from **your Gmail** if you have it connected). When delivery finishes, the label becomes **Sent**. If sending fails, the label is **Failed to send**: open the email and click **Retry send** to send it again. If the recipient, subject or body is missing, Cream says so and the draft stays in the editor.
4. An entry of the form *"Your name sent “Subject” to recipient@…"* appears in the record's **Timeline**.

For a person, read emails in **History → Emails**, with their subject, status and expandable body; use **Older / Newer** to paginate. On companies and deals, the **last 10 emails** appear below the form. Expanding an email shows the message with its formatting: line breaks, lists and the original HTML. Both views include sent emails and, with Gmail, received replies.

### Open and click tracking

Sent emails include automatic tracking:

- When the recipient **opens** the message, the email shows the **Opened** label in the sent list, the open is recorded in the record's **Timeline** and you receive an open **notification**.
- When the recipient **clicks** a link in the message, the click is also recorded in the **Timeline**.

> **Notes**
> - Sending uses the server's mail (SMTP) configuration; tracking requires the application to be reachable from the Internet (already configured in production).
> - If **Send emails from records through Gmail** is on, the email leaves from your Gmail and appears in Sent, including in development. Otherwise, in development the email is not actually sent: it shows up in **Mailbin** (`/mailbin`).
> - Tracking depends on the recipient's email client loading images; if images are blocked, the open may not be detected.

### Scheduling a send (Send later)

You can leave an email ready to go out **later**:

1. Write the email (or insert it from a template).
2. In **Send later**, pick a date and time.
3. Click **Send email**. The email is **scheduled** and will be sent automatically at that time.

In the record's email list, scheduled emails show the **Scheduled** label with their date/time and a **Cancel** button to cancel them before they go out. If you leave **Send later** empty (or pick a time in the past), the email is sent immediately.

### Follow-up reminder (Follow up)

So you don't forget to insist if they don't reply:

1. When sending, in **Follow up** choose a period (e.g. *in 2 days*, *in 1 week*).
2. After that period, if you **have not marked the email as replied**, you will receive a **notification** reminding you to follow up.

In the email list, emails with a pending reminder show the **Follow up \<date\>** label and a **Mark replied** button: click it when the contact replies and the reminder is cancelled (it is marked as **Replied**). The period is counted from the actual send time (also for scheduled emails).

### Who sees emails

Emails you send **from a client's record** (person, company or deal) are stored on that record. Any **workspace member** who can open the record sees:

- the email list (sent and **Received** if applicable): subject, recipient or sender, body and labels such as **Sending**, **Sent**, **Opened**, **Replied** or **Received**
- the related activity in the **Timeline** (sends, opens, clicks, detected replies)

The same applies to **Campaign** sends when each recipient is tracked on their record in the CRM.

**There are no per-user private emails** within the same workspace: anything sent from a record is part of the team's shared history for that client. Visibility of **deals** depends on the role (see [Roles](#roles)); people and companies remain visible to the whole workspace.

| What | Do other workspace members see it? |
|-----|-------------------------------------------|
| Email sent from the client's record | Yes |
| **Opened**, **Replied**, **Follow up** status | Yes |
| Activity in the record's **Timeline** | Yes — send, open, click, reply |
| Your personal Gmail inbox | No |
| Emails sent **outside Cream** | No |
| Full text of the client's reply (with **full reply logging**) | Yes — it appears as a **Received** email on the record |
| Reply text without the full-body permission | No — it is only marked **Replied** |
| Data from **other workspaces** | No |

**Gmail connected:** each person connects **their own** account in **Gmail** (sidebar menu). Cream does **not** show a colleague's inbox. Reply detection reads headers from your Gmail only to mark replies on records where **you** sent the email; the result (**Replied**, timeline) is visible to the team on the client's record.

### Gmail connected

If you connect your account in **Gmail** (sidebar menu), you can choose the permission level:

- **Connect for sending only** — sending from records only.
- **Connect for sending and reply detection** — sending + reply detection (thread headers).
- **Connect with full reply logging** — sending + detection + saving the **text** of replies on the record.
- If you connected with fewer permissions, **Enable reply detection** or **Enable full reply logging** extend the permissions **without disconnecting**.

When you click **Connect with full reply logging** (or **Enable full reply logging**), Google usually asks for **two permissions**: *Send email on your behalf* and *View your messages and settings*. This is expected: the second one covers the reading needed to save the body of replies.

> **Important — reply text (Received):** if you previously enabled only header-based detection and later full logging, Google may mix incompatible permissions. In **Gmail connection**, if you see an orange warning, click **Enable full reply logging** again, accept in Google and then **Sync now**. Without that step you may see **Replied** but not the **Received** email with the text.

Options after connecting:

- **Send emails from records through Gmail** — emails you send from a record go out from your Gmail address and appear in your Sent folder.
- **Detect replies in your inbox** — Cream checks the Gmail threads of the emails you sent. When someone replies, the email switches to **Replied** automatically, the follow-up reminder is cancelled, you receive a **notification** and it is recorded in the **Timeline**.
- **Enable full reply logging** (if you didn't grant it when connecting) — re-authorizes with Google to read the body of replies and save them on the record.
- **Sync now** — forces an immediate sync (requires inbox read permission); in production there is also a periodic automatic sync.

When you have **full reply logging** active and the connection is correct, the client's replies appear in the record's email list with the **Received** label, the sender in **From:** and an expandable body — visible to the whole workspace on that record (see [Who sees emails](#who-sees-emails)).

### Gmail add-on (linking threads to deals)

From the **CReaM add-on in Gmail** (sidebar when opening an email) you can:

1. **Authorize** — if Google has not yet allowed CReaM to read the thread, accept that permission. Then **Connect with CReaM** to authorize with your CReaM account (OAuth).
2. If the thread is **already linked** to a deal, you see a **deal summary** with
   stage, pipeline, company, value, owner, contacts, close date, pending tasks
   and products, plus an **Open in CReaM** link. From that summary you can **Edit
   deal** (stage, value and close date), **Add note**, **Add task** and **Edit
   task** (title, due date and mark complete) without leaving Gmail. To link
   another deal or create a new one, click **Link another deal**.
3. If the thread is **not linked yet**, choose the destination **Workspace** and
   **Pipeline** (the **Example** workspace and your default pipeline are
   proposed). New deals are created in the first stage of the pipeline.
4. **Link the thread** to an existing deal (suggestions and search are limited
   to the selected workspace).
5. **Create a new deal** from the thread. Enter the **deal name** and the
   **company**. If the email domain (for example `ing.es`) matches a company,
   the add-on **suggests** it. If the name does not exist, it asks whether to
   **create** the company and stores that domain on it. All messages are
   imported into its **Emails** section and the card switches to the deal
   summary.

To install it (users):

1. Open the internal **CReaM Gmail** link provided by the Example administrator,
   or go to [Internal Marketplace apps](https://workspace.google.com/marketplace/mydomainapps).
2. Click **Instalar** (Install) and accept the requested Gmail permissions.
3. Open Gmail, select a thread and click the **CReaM** icon in the right sidebar.
4. If the add-on shows **Authorize**, accept the Gmail permission and return to Gmail.
5. Click **Connect with CReaM**, sign in at `crm.example.com` and authorize access.

**Example administrators:** the complete guide to publishing the add-on on Marketplace,
installing it for the whole domain and troubleshooting is in
[`deploy/GMAIL_ADDON_SETUP.md`](deploy/GMAIL_ADDON_SETUP.md).

The add-on is private to the Example domain. Each person connects their own
account; do not share authorization links or tokens.

### Email templates

**Templates** save you from rewriting frequent emails (introduction, follow-up, etc.).

- **Create and manage:** go to **Plantillas** (Templates) from the sidebar menu. Each template has a **name**, **subject** and **body**, and you can mark it as **shared** with the whole workspace or keep it personal. You can edit the **body** with the **rich text editor** (bold, italic, color, lists, links, etc.) or with **HTML** (tables, images, full documents). If you switch from HTML to the rich text editor and the content uses tags Quill cannot preserve, you will see a warning and can cancel before losing formatting.
- **Layouts:** on the same screen you can create reusable **layouts** (header, footer, shared styles). A layout is HTML with `{{ content }}` or `{content}` where each template body is inserted. When creating or editing a template, pick an optional layout from the **Layout** dropdown.
- **Predefined templates (Example):** the organization workspace includes eight templates for the course cycle (first contact, confirmed booking, payment reminders, closing, etc.). You can edit them from **Plantillas** if you are an administrator.
- **Variables:** use `{first_name}`, `{last_name}`, `{name}`, `{company}` and `{email}` in the subject or body; when inserted they are replaced with the record's data. Texts in square brackets such as `[Nombre del curso]` or `[fechas]` are placeholders you must fill in manually after loading the template.
- **Preview:** when creating or editing a template or layout, and when composing an email on a record, you will see a **Vista previa** (Preview) block with optional variables (`{first_name}`, `{name}`, etc.). Leave them blank to use sample values or fill them in to check the result. Click **Vista previa** to open the rendered email in a new tab (without sending it).
- **Use in an email:** in the **Send email** section of a record (Person, Company or Deal), the menu starts on **Sin plantilla** (No template): you write the subject and body yourself. Choosing a template fills the subject and body with the variables already substituted for that contact. An HTML template, or one with a layout, opens in **HTML** mode so tables and the document are kept. You can switch back to **Sin plantilla** to clear them and write the email by hand. If there are no templates yet, you will see a link to create them.

### Bulk sending

For bulk communication with consent and metrics use **Campaigns** + **Segments** ([§29](#29-marketing)): choose audience, subscription type, template, scheduling and A/B tests.

> **Mail merge** (manual send to saved view, list or IDs) is **disabled** in the menu; see [Coming soon](#30-coming-soon). **Send email** from a record page remains available one record at a time.

---

## 16. Automations

**Automations** run an action automatically when an event occurs, optionally only if certain conditions are met.

### How to access

**Automations** entry in the sidebar menu; click **New automation**.

### Setting up an automation

1. **Name:** a descriptive name.
2. **When this happens** — the event that triggers it:
   - *Deal stage changed* — a deal changes stage.
   - *Record created* — a person, company or deal is created.
   - *Task completed* — a task is completed.
3. **Only if** (optional) — add `field = value` conditions that must be met for it to run. For example, on "deal changes stage" you can require `to = Won` (only when moving to that stage). Without conditions, it always runs.
4. **Do this** — the action:
   - *Create task* — creates a task (title and due date) on the record.
   - *Send email* — sends an email to the record (subject and body); requires the record to have an email address.
   - *Notify Slack* — posts a message to Slack.
5. Check **Active** and save.

### Notes

- **Inactive** automations do not run.
- *Notify Slack* does nothing until the Slack integration is enabled (see [Coming soon](#30-coming-soon)).

### Stage triggers (AI)

In addition to automations, each **pipeline stage** can have **triggers** that run when a deal enters it (regardless of whether you move it on the kanban, with the stage buttons on the detail page or by editing the deal). Unlike automations, their actions are shown **in your browser**: a brief notification (toast), a modal alert, a confirmation with a follow-up action or an **informational panel inside the deal's detail page**.

**Setting them up:** in **Pipelines → edit pipeline**, each saved stage shows a lightning icon (⚡) with the number of triggers; click it to manage that stage's triggers. A stage can have several triggers.

Each trigger has a name, an **Activo** (Active) switch and an execution mode:

- **Agente IA** (AI agent): write an instruction in natural language (e.g. *"Summarize the deal's status and show it in the panel; if the value exceeds €10,000, alert me with a toast"*). The AI queries the deal, its company and its contacts (read-only, it never modifies data) and responds with the interface actions. Requires the AI assistant to be configured.
- **Función nativa** (Native function): choose a predefined function from the catalog (e.g. *Mostrar toast* (Show toast) or *Celebración de deal ganado* (Won deal celebration)). It consumes no AI and works without an API key. Some functions have **parameters**: when you pick them, the form shows their fields (e.g. *Mostrar toast* asks for the text and style of the alert). Fields marked with * are required.

**History:** by clicking a trigger's name (or **Runs**) you see its latest executions, with status, deal, duration, errors and the details of what the AI did.

The alerts are only seen by **the user who moved the deal**; if the stage change is made by an integration (API/MCP), the execution is recorded in the history without showing anything on screen. The deal panel is saved and remains visible on the detail page until another trigger replaces it.

---

## 17. Configurable alerts

**Alerts** notify automatically when a **date** is reached (e.g. the end date of an edition on a deal line) and, optionally, when **additional conditions** about the deal or its company are met. Only **administrators** can create and edit them.

### How to access

**Alertas** entry in the sidebar menu; click **Nueva alerta** (New alert).

### Configure an alert

1. **Name:** descriptive text (shown in the notification).
2. **Date field:** when to evaluate the rule:
   - *Fin de edición* (Edition end) — a deal line whose edition end date has been reached.
   - *Inicio de edición* (Edition start) — edition start date on a deal line.
   - *Fecha de cierre esperada del deal* (Deal expected close date) — deal field.
3. **Offset (days):** `0` = same day; negative values notify in advance (e.g. `-7` = one week before).
4. **Additional conditions** (optional; all must be met): on the same create or edit screen, click **Añadir condición** (Add condition) and define rules on deal, company or contact fields (same system as pipeline stage entry conditions: field, operator and value). Common examples:
   - *Información fiscal de la empresa* (Company fiscal information) → *está vacío* (is blank)
   - *Abierto (no ganado ni perdido)* (Open — not won or lost) → *es igual a* (equals) → `true`
5. **Recipient:** *Owner del deal* (Deal owner) or *Administradores del workspace* (Workspace admins).
6. Check **Activa** (Active) and save.

### Notification channels (each user)

In **Settings → Profile**, **Alertas** section, each member chooses:

- **Notificación in-app (campana)** (In-app notification) — enabled by default.
- **Email** — disabled by default.

These channels are used for **alerts** configured by the administrator, **lead form submissions** (the owner) and **calendar bookings** (the host). If you disable both, you will not receive any of those notices.

### Notes

- Each rule notifies **only once** per deal and recipient; it does not repeat on following days.
- Alerts are evaluated **once per day** on the server.
- Alerts appear in **Notifications** with a link to the deal.

---

## 18. Webhooks

This section is **hidden by default**. Enable it under **Settings → Funcionalidades** to see **Webhooks** in the menu.

In **Webhooks** you configure URLs that Cream will call when events occur (e.g. creation or change of a deal).

- **New webhook:** destination URL and subscribed events.
- You can **enable/disable**, **edit** or **delete** each webhook.

Useful for integrating Cream with other systems (Zapier, your own scripts, etc.).

---

## 19. Notifications

**Notifications** in the sidebar menu shows workspace alerts: **comment** mentions, **alerts** configured by the administrator, lead form submissions, **calendar bookings** (the host), etc. Mentions in a **task** title assign the task but do not generate an alert for now. **Alerts**, **form submissions** and **bookings** follow your channels in **Settings → Profile → Alertas** (bell and/or email).

- The counter in the menu indicates unread notifications.
- **Mark read** on each alert or **Mark all read** to clear the inbox.
- If the alert includes a **View** link, it takes you to the related record.

---

## 20. Team and invitations

**Team** is available to all workspace members. Use the search box to find members by name or email; the list is paginated.

### For all members

- Browse the **Members** list with each person's name, email and role.

### For admins only

In **Team**, administrators can also:

#### Inviting members

1. Your colleague's email.
2. Role: **Admin**, **Director comercial** (Sales director) or **Vendedor** (Salesperson).
3. **Send invitation** — an email with a link is sent (or the link is displayed to copy).

#### Managing members

- Change a member's role (dropdown selector).
- Remove a member from the workspace.
- See **Pending invitations**, resend or cancel invitations.

Invitees accept with the link they received and create an account, or sign in if they already have one.

---

## 21. Workspace settings

### My profile (Profile)

Available to **all members** under **Profile** ( **Mi perfil** menu group, or click your name at the bottom of the sidebar). Personal preferences **in the active workspace**:

1. **Personal details** — your **name** (shown in mentions and activity), **language** (Español / English) and optional **time zone**. If you leave time zone blank, Cream uses the workspace default. Datetimes (activity, emails, etc.) display in your zone; calendar dates (task due date, expected close) are not shifted. Account email is read-only.
2. **Default pipeline** — pipeline selected at sign-in, in the sidebar selector and in the Gmail add-on ([§3](#3-navigation)).
3. **Sales director briefing** — checkbox to show or hide the AI block on the dashboard ([§4](#4-dashboard)). Only shown if an admin enabled it in workspace **Settings** and AI is configured on the server.
4. **Alertas** (Alerts) — **In-app notification (bell)** and **Email** channels for configured alerts, **form submissions** (if you are the owner) and **calendar bookings** (if you are the host). If you disable both, you will not receive those notices ([§17](#17-configurable-alerts), [§19](#19-notifications)).

### Workspace settings (Settings)

In **Settings** (**admins** only):

### General

- Change the **workspace name**.
- **Workspace time zone** — default for members without a personal zone and for “today” in alerts and briefings (default `Europe/Madrid`).
- **Salespeople can view other users' deals** — when enabled, salespeople see all deals in the workspace on lists, boards and detail pages (not only their own or shared as collaborators).
- **Salespeople can edit other users' deals** — when enabled, salespeople can update, move and delete any deal in the workspace. Enabling edit also allows viewing those deals.

By default both options are off: salespeople only see and edit their own deals and those explicitly shared with them as collaborators.

- **Sales director briefing (AI)** — enables the daily team briefing on the dashboard (requires `CREAM_AI_API_KEY` on the server).

### Funcionalidades (Features)

Enable optional menu and settings sections for this workspace (off by default):

- **Reports** — reports and CSV export.
- **Atribución** (Attribution) — UTM campaign report.
- **Puntuación de leads** (Lead scoring) — scoring rules and lifecycle on contact records.
- **Webhooks** — outgoing HTTP integrations.
- **Campos personalizados** (Custom fields) — extra fields on people, companies and deals.
- **GA4 measurement ID** (`G-…`) — this workspace's Google Analytics 4 property; used by the `{% google_analytics %}` partial in templates (e.g. booking acknowledgment). If blank, the tag outputs nothing.

### OKM

Connect the corporate knowledge base (Google Shared Drive) for the contextual chat and AI briefings:

1. Enable **OKM chat for this workspace**.
2. Enter the **Google Shared Drive ID** (from the Drive URL).
3. Paste the **service account JSON** with read access to that drive. Once saved, the JSON is not shown again; the configured account email is displayed. Leave the field blank on later edits to keep the current key.

Each workspace can use a different drive and service account.

### Mailjet

Connect **this workspace's** Mailjet account for campaigns and journeys (admins only):

1. In Mailjet, copy the **API Key** and **Secret Key** (Account settings → SMTP and SEND API settings).
2. In **Settings**, **Mailjet** section, paste the keys, the verified **from email**, and optionally the sender name.
3. To also send invitations, alerts, bookings, reports and emails from records through Mailjet, enable **Usar Mailjet para el correo transaccional**.
4. Click **Conectar Mailjet**. Keys are not shown again; leave the fields blank to keep the stored values.
5. When you save, Cream automatically registers sent, open, click, bounce, spam, unsub and blocked events in Mailjet (Version 2). The **webhook URL** shown below is for reference if you need to verify it in Mailjet.

Each workspace has its own URL (it includes a token). Without Mailjet connected, campaigns use SMTP/Mailbin. Transactional email uses Mailjet only when the checkbox is on; otherwise SMTP/Mailbin.

- **Desconectar** removes this workspace's credentials.

### Beehiiv

Syncs Beehiiv publications with Cream subscription types (admins only). Beehiiv still sends each newsletter; Cream mirrors subscribe/unsubscribe into the MQL pool. Each Beehiiv publication has its own webhook URL.

1. In Beehiiv, copy the account **API Key**.
2. In **Settings**, **Beehiiv** section, paste the key and click **Conectar Beehiiv** or **Guardar Beehiiv**. The API key is not shown again; leave the field blank to keep the stored value.
3. Under **Add publication**, choose the **Cream subscription type** (e.g. Newsletter), the **Publication ID** (`pub_…`) and optionally the **Webhook signing secret** (`whsec_…`) from that publication in Beehiiv → Settings → Webhooks (Scale plan+).
4. Copy that publication's **webhook URL** and register it in Beehiiv for `subscription.created`, `subscription.confirmed` and `subscription.deleted`.
5. Repeat steps 3–4 for each Beehiiv publication you want to sync.
6. Click **Sincronizar ahora** to import existing subscribers. Hourly auto-sync runs when enabled.

**Bidirectional:** subscribe/unsubscribe in Cream for a type linked to Beehiiv (form, person record or preference center) is pushed to the matching publication. Changes originating in Beehiiv are not pushed back.

- **Desconectar** removes Beehiiv settings for this workspace (does not delete imported people or subscriptions).

---

## 22. API tokens and MCP

In **API tokens** you generate access tokens to connect **MCP** clients (Claude, Cursor and other AI agents) or the **REST API v1** to your workspace.

### How to access

**My profile → API tokens** in the sidebar.

### Create a token

1. In **Token name**, enter a descriptive name (for example `My MCP client`).
2. Click **Create token**.
3. Copy the value under **Your new token (copy it now):** — it is shown **only once**. It starts with `cream_`.
4. Store it somewhere safe. Do not share it or paste it into public chats.

Each token is tied to **your user** and to the **workspace that was active** when you created it. The agent can only see and change what you can in that workspace.

**Revoke token** (trash icon) invalidates a token. Use it if the token leaked or you no longer use that client.

### Connect an MCP client

The MCP server address is your Cream URL plus `/mcp`. If you open Cream at `https://your-domain/`, the path is:

```
https://your-domain/mcp
```

In local development it is usually `http://localhost:3030/mcp`.

#### With an API token (recommended)

1. Create a token as above and copy it.
2. In the client (Cursor, Claude Desktop, etc.) add a remote MCP server with that URL and the token in the authorization header.

Example for Cursor (`~/.cursor/mcp.json` or the project's `.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "cream": {
      "url": "https://your-domain/mcp",
      "headers": {
        "Authorization": "Bearer cream_YOUR_TOKEN"
      }
    }
  }
}
```

Replace `https://your-domain/mcp` with your instance URL and `cream_YOUR_TOKEN` with the value you copied.

In Claude Desktop the configuration is the same (`mcpServers` in Claude's settings file).

3. Reload the MCP servers or restart the client. You should see Cream's tools (list deals, create tasks, summarize records, and so on).

#### Without pasting the token (sign-in)

Some clients can connect with **just the URL** (`https://your-domain/mcp`). They will ask you to sign in to Cream and authorize access. You do not need an API token in that case.

### Notes

- The token has the same access as your user in that workspace. Treat it like a password.
- If you switch workspace, create a new token while that workspace is active.
- The MCP AI tools (`summarize_record`, `suggest_next_steps`, `draft_email`, `natural_language_search`, `enrich_record`) require the AI assistant to be enabled; see [AI assistant](#24-ai-assistant).

---

## 23. Reports

This section is **hidden by default**. Enable it under **Settings → Funcionalidades** to see **Reports** in the menu.

**Reports** let you measure your activity by combining a metric, a grouping and a period, and save the combinations you use most.

### How to access

**Reports** entry in the sidebar menu (when enabled under **Settings → Funcionalidades**).

### Building a report

1. **Record** — which data: *Deal*, *Person* or *Company*.
2. **Measure** — what to measure: *Count* and, for deals, *Total value* or *Average value*.
3. **Group by** — how to group: by stage, owner, company, industry or month of creation (the options adapt to the chosen type).
4. **Period** — *All time*, this month, quarter or year.

The report is recalculated instantly and displayed as a table with bars and a total.

### Saving and reusing

Type a name and click **Save** to save the current combination. Saved reports appear at the bottom of the page: open them with a click or delete them with **Delete**.

### Exporting to CSV

Click **Export CSV** to download the current report (label and value of each row) as a CSV file.

### Scheduled email delivery

You can receive a report by email on a recurring basis:

- When **saving**, choose *Email daily / weekly / monthly* (or *Don't email*) in the selector.
- On each saved report, the frequency dropdown lets you **change it** at any time (*Not emailed / Daily / Weekly / Monthly*).

Cream will email you the report at that frequency. *(Scheduled delivery runs in production; in development you can test the email from Mailbin.)*

---

## 24. AI assistant

When the AI assistant is enabled and configured (`CREAM_AI_API_KEY`), you can use it on **person**, **company** and **deal** detail pages, and also via MCP/API.

### On a record's detail page

At the top of the main column you will see the **AI Assistant** section:

| Action | What it does |
|--------|----------|
| **Summarize** | Summarizes the record using notes, comments, emails, tasks and recent activity. Shows risks, next steps and missing data. |
| **Next steps** | Proposes concrete actions. Task-type suggestions include a **Create task** button. |
| **Draft email** | Generates a draft subject and body and inserts the text into the **Send email** composer (it does not send automatically). |
| **Suggest fields** | Suggests improvements to the record's fields based on the existing context (no external data). |

Optionally you can provide an **Email goal** before generating a draft (e.g. "Follow up after demo").

> **Notes**
> - Discarded generations are not saved on the record.
> - If you accept a task suggestion, it is recorded in the **Timeline** as an AI-suggested task.
> - Requires a provider compatible with the OpenAI Responses API (`CREAM_AI_API_KEY`; default `https://api.openai.com/v1/responses`).

### Natural search

At **`/ai_search`** you can use phrases such as:

- `stalled deals` — open deals that have been in the same stage for 7+ days
- `overdue tasks` — pending overdue tasks
- `pending follow up` — emails with an active follow-up reminder
- `won deals` — won deals
- `no contact` — records with no activity in 14 days

If the phrase does not match a known pattern, keyword search is used.

### MCP / integrations

The MCP tools `summarize_record`, `suggest_next_steps`, `draft_email`, `natural_language_search` and `enrich_record` reuse the same logic as the interface.

---

## 25. Knowledge chat

In the **Example** workspace (when it is enabled and configured on the server), you will see a **floating chat button** in the bottom-right corner of any screen.

### What it does

The chat is an **agent-based assistant** that combines:

- The **context of the page** you are on (if applicable).
- Example's **OKM corporate knowledge** (clients, sales, strategy, companies and people in Google Drive).
- The **CRM data** (record search, tasks, pipeline).
- **Persistent memory** of preferences and relevant facts across conversations.

It can also **propose changes in Cream** (create tasks, add notes, update records, move deals, complete tasks). Those changes are **not applied on their own**: the chat shows a confirmation card and you must click **Confirmar** (Confirm) to execute them.

### Context depending on the page

| Page | Context it uses |
|--------|------------------|
| **Company** | The company's CRM record + OKM search for that client |
| **Person** | The person's record, their company and related OKM material |
| **Deal** | The deal's record, company, contacts and sales material in OKM |
| **Everything else** (dashboard, lists, etc.) | General Example knowledge based on your question |

The panel header indicates the active context (e.g. *Contexto: Acme Corp*) or *Conocimiento general de Example* (General Example knowledge) when no record is associated.

### Usage

1. Click the chat button to open the panel.
2. Type your question and press **Enviar** (Send) (or Enter).
3. The assistant answers using the CRM, the OKM and the saved memory.
4. If it proposes an action in Cream, a card with **Confirmar** / **Cancelar** (Confirm / Cancel) will appear.
5. **Nueva** (New) clears the current conversation.
6. You can **expand** the panel to full screen with the header icon.
7. The conversation is preserved as you navigate between pages (same browser session); reloading the tab loses it.

### Requirements

- Workspace with **OKM chat** enabled in **Settings** and a valid OKM configuration (Shared Drive ID + service account).
- `CREAM_AI_API_KEY` configured on the server.
- Database with the **pgvector** extension (for agent memory with llmemory).

---

## 26. Stripe payments

If your organization charges through Stripe (for example from another application), Cream can import those payments and help you **reconcile them with your deals**: each payment is linked to an existing deal or Cream proposes creating a new one.

### How to access

Sidebar menu → **Stripe**. The payments inbox opens; from there, the **Stripe settings** button leads to the connection configuration.

### Connecting Stripe (admins only)

1. In the Stripe dashboard create a **restricted key** with read-only permission on *Charges* (recommended over the full secret key).
2. In **Stripe settings**, paste the key into **API key**, add a label if you like and click **Connect Stripe**. Cream validates the key against Stripe before saving it.
3. Enable **Import new payments automatically** so new payments are imported every 15 minutes, or use **Sync now** at any time. The first sync brings in the full payment history.

If a sync fails (for example, a revoked key), the error appears on the settings page. **Disconnect** removes the connection and the imported payments (activities already recorded on deals are kept).

### The payments inbox

The **Stripe payments** page has three tabs:

| Tab | Contents |
|---------|-----------|
| **To review** | Payments pending reconciliation |
| **Matched** | Payments already linked to a deal |
| **Ignored** | Dismissed payments (recoverable with **Restore**) |

Each row shows the date, amount, customer (name and email), description and the **deal suggestion** with its confidence level. Clicking a row opens the **payment detail**, with all the information Stripe provides: phone and billing address, payment method (card with brand and last 4 digits, Bizum, Link…), risk-check outcome, the payment metadata, a link to the **Stripe receipt** and a "Full Stripe data" dropdown with the full object exactly as Stripe returns it. From the detail you can also reconcile, ignore or create the deal.

Suggestion confidence levels:

- **high** — the payment carries the deal reference in the metadata, or the amount and currency match a single deal (open or won; in case of a tie the open one wins) for that person.
- **medium** — the person has a single candidate deal (open or won), but the amount does not match.
- **low** — the person was identified but there are several candidate deals (or none). Lost deals are never suggested.
- No suggestion — the payment's email does not correspond to any person in the CRM.

### Reconciling a payment

For each pending payment you can:

- **Accept** — accept the suggested deal.
- **Search deal…** — an autocomplete search to link manually: type part of the deal or company name and pick from the results (**open and won** deals; lost ones do not appear). Choosing one enables the **Link** button.
- **Create deal** — opens the new deal form pre-filled with the payment data (name, company and contact if the person was identified); when you save it, the payment is linked automatically.
- **Ignore** — dismiss the payment (tips, test payments, etc.).

When reconciling, the deal records the **payment received** activity with the amount in its timeline. Cream does not change the deal's stage automatically: if the payment closes the sale, move it to the winning stage yourself.

### Notes

- Viewing the inbox and reconciling payments is available to any member; configuring the connection is for **admins**.
- To make matching foolproof, the application that charges can write the deal id into the Stripe payment metadata under the key `cream_deal_id`.
- Refunds made **after** a payment is imported are not reflected; *Refunded* is only marked if the payment was already refunded when imported.

---

## 27. Lead capture forms

**Lead capture forms** let you receive leads from external pages. Each form is a public Cream page you can link to or embed in an `<iframe>`.

### How to access

In the sidebar menu, open **Formularios** (Forms).

### Setting up a form

1. Click **Nuevo formulario** (New form).
2. Provide the **name**, the **slug** (it will appear in the public URL `/f/slug`), the form **template** and whether the form is **Activo** (Active).
3. Under **Destino del envío** (Submission destination), choose **Deal (ventas)** / Deal (sales) or **MQL (marketing)**. Deal creates or reuses an opportunity (flow below). MQL captures the person, consent and submission history **without creating a deal** (see [§29 MQL pool](#mql-pool)). For MQL destination you can set the **subscription type** (defines the expected checkbox field key) and **marketing consent text** that overrides the type's default label. Cream warns if the form template schema does not include that field.
4. Under **CRM y asignación** (CRM and assignment) — Deal destination only: **pipeline**, optional **stage**, **owner** (receives notification and follow-up task), optional **product** and pipeline routes by field value.
5. Configure the **first task** (text and days until due; 0 = same day) and the **email template** to the lead (or **Sin email** / No email).
6. Optional: set a **redirect URL after submission** (e.g. `https://example.com/thanks`) to send the visitor to a page on your site. If left blank, Cream's thank-you page is shown (`/f/slug/success`).
7. Optional: define **additional hidden fields** (one per line, e.g. `producto`, `landing`). Their values are passed as query params in the public or iframe URL, e.g. `/f/slug?producto=curso-ia`. They are saved with the submission and shown on the deal under **Formulario de origen** (Source form) or in the contact's history.
8. Check **Recoger datos de empresa** (Collect company data) if the form should ask for the company name and tax ID (CIF). When enabled, submissions with an empty company name still succeed server-side (a placeholder company is used); mark the field `required: true` in the template if you want to enforce it in the browser.
9. Optional: check **Exigir email corporativo** (Require work email) on lead magnets or other forms where you want to reject personal addresses (Gmail, Hotmail, Yahoo, Outlook, iCloud, etc.). The visitor sees an error and cannot submit until they use an email whose domain is not on the known free-provider list. Cream does not verify that the company exists; it only blocks known personal email domains.
10. Save. In the list you will see the **public URL**, the **privacy policy** link (`/f/slug/privacy`) and the **iframe code** ready to copy.

### Form detail page (View)

From the list, **Ver** (View) opens the form detail:

- **Destino Deal** or **Destino MQL** badge and link to the public URL.
- **MQL captados** (MQL captured) — people who submitted with MQL destination from this form: submission count, first and last capture, and whether they are **eligible** for marketing now.
- **Envíos recientes** (Recent submissions) — all submissions (Deal or MQL) with a **Detalle** (Detail) link to the full submission record, including the **Consentimiento aceptado** (Consent accepted) block (versioned policy, hash and texts).

### Form templates (administrators)

The **layout and fields** of each public page are defined in **Liquid** templates stored in the workspace, not in the form record itself.

1. From **Formularios** (Forms), click **Plantillas de formulario** (Form templates) — administrators only.
2. Filter by **Páginas** (Pages — full forms), **Reservas** (Bookings — acknowledgment after confirming at `/b/…`), **Parciales** (Partials — contact fields, GDPR consent, analytics…) or **Landing page** (marketing pages at `/p/workspace-slug/landing-slug`; see [§29](#29-marketing)). Each workspace stores its own templates in the database; they are not tied to server source files.
3. **Edit** opens a syntax-highlighted Liquid editor. Lead form pages use tags such as `{% field %}`, `{% partial 'contact_fields' %}`, `{% form_open %}`, and variables like `{{ lead_form.name }}`. **Booking acknowledgment** templates may use `{% partial 'google_analytics' %}` (or `{% google_analytics %}`) for GA4 when the workspace has a **GA4 measurement ID** set under **Settings → Workspace** ([§21](#21-workspace-settings)); `{{ evento }}` is the event type slug (no personal data).
4. **New template**: enter a short **name**, choose **type** (lead form, booking acknowledgment or landing) and, if applicable, check **Es un parcial** (Is a partial).
5. After creating or changing a **lead page** template, select that name in **Plantilla del formulario** (Form template) when configuring a capture form. The `privacy` template defines the policy linked from each public form. **Booking acknowledgment** templates are selected under **Reservas** ([§28](#28-calendar-bookings)).

If a page template does not exist in the workspace, the public URL `/f/slug` will return an error.

### Privacy policy and consent

- Each public form links to a **privacy policy** page (`/f/slug/privacy`). Content is defined in **Plantillas de formulario** (Form templates) → `privacy` template (editable by administrators).
- Visitors must check the **data protection consent** (GDPR) box to submit. Templates may optionally include marketing checkboxes with `{% subscription_opt_in slug: "newsletter" %}` (or another subscription type slug); if accepted, the subscription for the matching type **checkbox field key** is recorded (see [§29](#29-marketing)). You can also add `{% subscription_opt_in_all %}` (or the `subscribe_all_opt_in` partial) to offer **subscribe to all active types** in the workspace with a single checkbox (`lead[subscribe_all]`).
- When the form loads, Cream stores an **immutable version** of the policy and checkbox text. Each submission is linked to that version (date, URL, hash and accepted content). Open **Ver consentimiento** from the contact record (**Information** → **Formularios enviados**), from the deal (**Information** → **Formulario de origen**), from **MQLs** (Forms column), or **Formularios → Ver → Envíos recientes → Detalle**. On the deal, expanding the submission also shows the **Consentimiento aceptado** block.

### What happens when a form is submitted (Deal destination)

- A **person** is created or reused by email (source "Formulario web"). If the person already existed, only blank fields are filled in (name, last name, phone, job title…).
- If that person already has an **open deal** in the form's pipeline, that deal is **reused**: new form data is added to the submission (without creating another deal or another follow-up task). If you configured a **stage**, the deal advances to it only when it is in an earlier stage (it never moves backwards). If there is no open deal in that pipeline (for example, only won or lost deals, or deals in another pipeline), a new deal is created in the configured stage or, if none is set, in the pipeline's **first stage**, with the form's configured **first task** (default: **Contactar lead** / Contact lead, due the next day) assigned to the owner.
- The submission data (form fields, source page, UTM, browser, IP…) is saved and visible on the deal's page, under **Formulario de origen** (Source form).
- The lead receives the configured email; the owner is notified according to their channels in **Settings → Profile → Alertas** (bell and/or email), with the data and a link to the deal.

### What happens when a form is submitted (MQL destination)

- The **person** is created or updated and the **submission** is saved with MQL destination (no deal).
- If the visitor accepts the marketing permission configured on the form, the **subscription** to the chosen type is created or updated, with the same policy version traceability as the submission.
- Submission history and product interests appear on the contact record. From there you can **Convertir a SQL** (Convert to SQL) when there is commercial interest (see [§29](#29-marketing)).

### Notes

- Inactive forms do not accept submissions.
- If the configured stage has **entry conditions** and the deal does not meet them, it stays in its current stage and the submission is still saved.
- If the form does not ask for a company, the person is associated with the workspace's generic **Particulares** (Individuals) company (unless the person already existed with another company).
**Example forms (demo workspace only, after `db:seed`):**

- **Contacto** (`/f/contacto`) — standard contact, help type, message, optional newsletter and GDPR; routes deals by `help_type`.
- **Request demo** (`/f/demo`) — contact + company (when the form collects company), message and optional newsletter.
- **Newsletter** (`/f/newsletter`) — minimal capture with optional subscription.
- **Reserva** (`/f/reserva`) — product edition, contact, message and GDPR (reservation pattern with open editions).

In a real workspace, administrators create and edit templates under **Forms → Form templates**; there is no fixed server-side list.
- Any workspace member can manage forms; **editing Liquid templates** is administrators only.

---

## 28. Calendar bookings

**Calendar bookings** let you offer a Calendly-like experience on a public Cream page: the visitor picks a meeting type, checks real availability in Google Calendar, books, and receives an email invitation (with Google Meet if applicable).

### Connecting Google Calendar

In the sidebar menu, open **Reservas** (Bookings) and click **Conectar Google Calendar** (Connect Google Calendar) (or **Google Calendar** if you are already connected). Authorize calendar access (`calendar.readonly` and `calendar.events`). Each host connects their own account; appointments are created in their calendar.

If permissions change in Google or your calendars stop loading, go to **Google Calendar** from Reservas and click **Reconectar Google Calendar** (Reconnect Google Calendar) (or **Actualizar permisos** (Update permissions) if a permission is missing). There is no need to disconnect the account.

**Google Cloud (administrator):** in the same OAuth project used by Gmail, also enable the **Google Calendar API** (`calendar-json.googleapis.com`). Without it, the OAuth connection may complete but will fail when listing calendars.

### Setting up a public page

All the configuration is done from **Reservas** (no need to use seeds or preloaded data).

**Public page**

| Field | Description |
|-------|-------------|
| Nombre (Name) | Internal title of the page |
| Slug | Identifier in the public URL (`/b/slug`) |
| Anfitrión (Host) | User whose Google Calendar is checked for availability and receives the appointments |
| Pipeline CRM | Pipeline where the person and deal are created upon booking |
| Reutilizar deal existente (Reuse existing deal) | If the person already has a deal in the first stage of this pipeline, the booking is linked to that deal; otherwise a new one is created |
| Mensaje de bienvenida (Welcome message) | Text in the public page header |
| Avatar URL / Logo URL | Optional profile images |
| Zona horaria (Time zone) | Time zone of the host’s **weekly hours**. Visitors see slots converted to their zone; Google Calendar stores the same instant. |
| Ventana de reserva (días) (Booking window, days) | How many days ahead dates can be chosen |
| Calendarios (Calendars) | Google calendars where slots are checked; drag to reorder — the first one marked writable receives the bookings ("Recibe nuevas citas" badge) |
| Plantilla de acuse (Acknowledgment template) | Optional. After booking, opens `/b/slug/recibido?evento=type-slug` with that Liquid template (no name, email or phone in the URL). If blank, confirmation stays in Cream (Meet, `.ics`) |
| Página activa (Page active) | If unchecked, the public URL does not accept bookings |

**Event types** (at least one is required; drag the ⋮⋮ handle to change the order)

| Field | Description |
|-------|-------------|
| Slug | Identifier of the type in the direct URL (`/b/page-slug/type-slug`) and the API |
| Duración (min) (Duration, min) | Duration of the appointment |
| Nombre / Descripción (ES y EN) (Name / Description, ES and EN) | Texts on the public page depending on the visitor's language |
| Franjas horarias semanales (Weekly time slots) | Bookable ranges per day; "+ Franja" adds blocks; "Horario laboral por defecto" (Default working hours) fills in an example |
| Incremento de slots (min) (Slot increment, min) | Spacing between offered slots |
| Antelación mínima (h) (Minimum notice, h) | Minimum hours before the appointment to be able to book |
| Buffer antes / después (min) (Buffer before / after, min) | Free time around each appointment |
| Tipo de ubicación (Location type) | Google Meet, Presencial (In person) or A coordinar (To be arranged) |
| Dirección (presencial) (Address, in person) | Location if the meeting is in person |
| Color en calendario (Calendar color) | Color of the event in Google Calendar |
| Visible | Whether it appears on the public page |
| Plantilla de acuse (Acknowledgment template) | Optional. Overrides the page acknowledgment template for this event type |

Use **Añadir tipo** (Add type) to create new types or the trash icon to remove them. Save the page to apply the changes.

Copy the **public URL** and share it with clients. If the page has several types, use the **direct event type URL** (in the **Reservas** list under **URLs directas por tipo**, or when editing a type under **URL directa del tipo**) so visitors go straight to that type's calendar without the selection screen.

### What happens when someone books

- **Real availability** is checked against the configured calendars (`primary` by default).
- Upon confirmation, the **event is created in Google Calendar** with the person who booked, optional guests (up to 5), and the host as attendees.
- In Cream, the **person** is created or reused (by email) and the **deal** is created or reused in the specified pipeline according to **Reuse existing deal**, with a follow-up task for the host when the deal is new.
- The host is notified according to their channels in **Settings → Profile → Alertas** (bell and/or email), with the booking details and a link to the deal. The email attaches an `.ics` file so the meeting can be added to a calendar.
- On the **deal** and **contact** record pages, the **Activity** timeline logs the booking (guest, meeting type and date/time), including when an existing deal is reused.

### Public page (visitor)

Three-step flow: choose event type → calendar and time (the time zone selector converts the host’s slots into the visitor’s zone; date and time always include the IANA label, e.g. `Europe/Madrid`) → form and confirmation. If an **acknowledgment template** is configured, confirming opens that page (`/b/slug/recibido?evento=type-slug`); otherwise Cream shows confirmation with a Meet link and `.ics` download (times in UTC). With a **direct event type URL** (`/b/page-slug/type-slug`), the visitor skips the first step and lands on that type's calendar.

---

## 29. Marketing

The **marketing hub** connects web capture, email consent, bulk sends, segmentation, automated journeys, lead scoring, web tracking and UTM attribution. It builds on **lead capture forms** ([§27](#27-lead-capture-forms)) and **Mailjet** configuration in **Settings** ([§21](#21-workspace-settings)) for campaigns and open/click metrics.

### How to access

In the sidebar (depending on features enabled in your workspace). **Atribución** (Attribution) and **Puntuación de leads** (Lead scoring) are optional and hidden by default — enable them under **Settings → Funcionalidades**:

| Menu | Purpose |
|------|---------|
| **Suscripciones** (Subscriptions) | List types (newsletter, general, etc.) |
| **Campañas** (Campaigns) | Bulk sends to segments |
| **Segmentos** (Segments) | Filtered person audiences |
| **Atribución** (Attribution) *(optional)* | UTM report |
| **Recorridos** (Journeys) | Automated sequences |
| **Puntuación de leads** (Lead scoring) *(optional)* | Scoring rules and lifecycle |
| **Formularios** (Forms) | Public capture (Deal or MQL) |
| **MQLs** | Marketing-qualified contact pool |

### MQL pool

Contacts with **active marketing permission** (at least one active subscription to an active type, valid primary email and not suppressed). By default any type counts (e.g. **General** or **Newsletter** imported from Beehiiv). Narrow with the **subscription type** filter. The pool is independent of scoring lifecycle: a customer with permission can remain in the pool while having open opportunities on other products.

**How to access:** **MQLs** menu.

**Steps:**

1. Open **MQLs**. The table shows person, lifecycle (scoring), score, source forms (with **Ver consentimiento**), pending interests and visible opportunities.
2. Filter by search, **subscription type**, **open opportunity** (any / yes / no), **product** (of the opportunity), **product interest** or **source form**.
3. From a row with a pending interest, click **Convertir a SQL** (Convert to SQL) to create or link an opportunity for that product (pipeline, task and owner).

**On a person's record:**

- **Product interests** — record a commercial signal manually (product + description) or from an MQL form with a product. States: pending, converted or dismissed.
- **Form submissions** — submission history grouped by form, on **Deals** and **Information**, with a **Ver consentimiento** link (answers, destination, accepted policy and statement).
- **Campañas enviadas** (Campaigns sent) — on **Activity**, the latest marketing campaigns received and **Ver más** (View more) for the history with delivery events.
- **Recorridos** (Journeys) — on **Activity**, this contact's enrollments (active, waiting, completed or cancelled), with the current step and enrollment date. **Ver más** (View more) opens the full history.

**Notes:**

- **Convert to SQL** requires permission to create deals. If an open opportunity already exists for the same product, Cream offers to link instead of duplicating.
- Scoring lifecycle (*mql*, *sql*, etc.) **does not** indicate an open deal; check **Visible opportunities** or the contact record.
- Journeys can be configured with **Exit journey if open opportunity for product** to pause commercial nurturing.

### Subscriptions and consent

**Subscription types** (menu **Suscripciones**):

1. Click **Nuevo tipo** (New type).
2. Enter **name**, **slug**, **description** (shown in the contact preference center) and **order**.
3. Optional: **Checkbox field key in forms** — `lead[key]` name that activates this subscription when checked (e.g. `newsletter_opt_in`). Must be unique within the workspace.
4. Optional: **Default checkbox label** — shown in Liquid templates unless the template or MQL form overrides it.
5. Optional: **Exclude from subscribe all** — the type is omitted from `{% subscription_opt_in_all %}` (still available via its own checkbox).
6. Check **Activo** (Active) and save. Cream creates default types such as *general* (`marketing_consent`) and *newsletter* (`newsletter_opt_in`) when you use the module.

**On a person's record** (**Information** → **Email preferences**):

- Each type shows its status: **Suscrito** (Subscribed), **Dado de baja** (Unsubscribed) or **Pendiente** (Pending).
- **Suscribir** / **Subscribe** or **Dar de baja** / **Unsubscribe** changes permission manually (with confirmation).
- Copy the **preference center** URL and share it with the contact.

**Preference center (contact's public page):**

- The contact selects which lists to receive and clicks **Guardar preferencias** (Save preferences).
- **Darse de baja de todas las comunicaciones** (Unsubscribe from all communications) suppresses the address for marketing (without affecting CRM transactional email unless suppressed for bounce/spam).

**Two different consents on forms:**

| Consent | What it is | Where configured |
|---------|------------|------------------|
| **Data protection (GDPR)** | Required to submit any form | `consent_fields` partial in templates |
| **Marketing / newsletter** | Optional; activates a subscription | `{% subscription_opt_in slug: "…" %}` tag in templates (uses the type's field key) + type on MQL form |
| **All subscriptions** | Optional; activates active types that are not excluded | `{% subscription_opt_in_all %}` tag or `subscribe_all_opt_in` partial (field `lead[subscribe_all]`). Skips types marked in **Subscriptions** or listed in `exclude: "slug1, slug2"` on the tag |

Subscriptions created from a form store the same **privacy policy version** as the submission (see [§27](#27-lead-capture-forms)).

### Campaigns

1. Menu **Campañas** → **Nueva campaña** (New campaign): name, goal, start date, **UTM** parameters, and under **Contenido del email** (Email content) write the send or pick an optional **Plantilla base** (Base template) to copy subject and body as a starting point. Content is stored on the campaign, not as a new global template.
2. In the same block you can pick a **layout**, switch **editor enriquecido** (rich text) / **HTML**, use `{first_name}`, `{name}`, `{company}`, `{email}` or Liquid `{{ name }}`, and open **Vista previa** (Preview) before saving.
3. Open the campaign. Under **Enviar campaña** (Send campaign) choose:
   - **Person segment** (required; shows how many recipients match).
   - **Subscription type**: only contacts **subscribed** to that type receive the send.
   - **Schedule send** (optional): date and time; leave blank for immediate send when you click **Encolar envío** (Queue send).
4. **A/B test (optional):** subject and body for variants A and B with weights (%). If you fill A/B subjects, they replace the campaign content subject.
5. **Send test to your email:** uses content saved on the campaign; optionally try a different subject or body.
6. After sending, review **Historial de envíos** (Send history). With A/B you can **Marcar ganadora** (Mark winner) and **Enviar ganadora al resto** (Send winner to the rest) to those who did not receive it.

**Plantillas** (Templates) in the sidebar remain available as reusable bases for campaigns, record emails and forms.

**On a person's record** (**Activity** → **Campañas enviadas**):

- You see the **latest 5** campaigns sent to that contact (date, campaign name, subject and whether it was opened or clicked).
- **Ver más** (View more) opens the full history with delivery events (open, click, bounce…).
- The list uses the same send log as the campaign; it does not include one-to-one emails or journey steps without a campaign.

**Requirements:** Mailjet connected under **Settings → Mailjet** (Cream registers Event Tracking when you save; see [§21](#21-workspace-settings)). Without Mailjet, sends use server SMTP/Mailbin.

### Segments

1. Menu **Segmentos** → **Nuevo segmento** (New segment).
2. Choose **record type** (people) and set **filters**: search, lifecycle, email, score, recent email opens, form submitted, visited URL, open opportunity, product interest, commercial history, source form, etc.
3. Check **Excluir direcciones suprimidas** (Exclude suppressed addresses) to respect bounces and global opt-outs.
4. After saving, **preview** shows how many records match (updates when you save changes).
5. Optional: **Compartido con el equipo** (Shared with the team) so others can use it in campaigns.

Segments feed **Campaigns** and can trigger **Journeys**.

### Journeys

Automated per-contact sequences.

1. Menu **Recorridos** → **Nuevo recorrido** (New journey): name, **entry trigger**, max re-enrollments (0 = once only) and **Activo** (Active).
2. **Entry triggers:** form submitted, segment entry, lifecycle change, marketing email click, booking created or **manual**.
3. Set the **entry condition** for the trigger (specific form, segment, booking page, lifecycle transition…).
4. Optional: **Product (commercial exit)** and **Salir del recorrido si hay oportunidad abierta del producto** (Exit journey if open opportunity for product) — stops nurturing when there is already an open deal for that product.
5. Add **steps** (ordered by position):

| Step | Action |
|------|--------|
| **Enviar email** (Send email) | Write the step email (optional base template, layout, Quill/HTML, preview) + subscription type (respects consent) |
| **Esperar** (Wait) | Pause N minutes from when the contact reaches the step (60 = 1 h, 1440 = 1 day). Optional: **Hasta las HH:MM** (Until, workspace time) holds the contact until the next time the clock reads that time; **Solo días laborables** (Weekdays only) moves Saturdays and Sundays to Monday at the same time |
| **Condición** (Condition) | Branch on contact field |
| **Establecer campo** (Set field) | Change lifecycle |
| **Añadir a lista** (Add to list) | Add contact to a CRM list |
| **Crear tarea** (Create task) | Sales task due in N calendar days, counted in the workspace time zone |
| **Ajustar puntuación** (Adjust score) | Add or subtract points |
| **Notificar** (Notify) | Alert a team user |

> **When each step runs.** Steps run in order and immediately once the contact enters the journey (or a wait ends), in 10-minute cycles, at any time of day and any day of the week; there are no business hours unless you set them with a **Esperar** (Wait) step. Examples: **Esperar 1440** = one day later, same time; **Esperar 1440 + Hasta las 10:00** = next day at 10:00; **Esperar 0 + Hasta las 09:30 + Solo días laborables** = next weekday at 09:30 (today if it is not yet 09:30). Place the step right before **Enviar email**. On the journey page, **Próxima ejecución** (Next run) shows date and time in your time zone (see [§20](#20-team-and-invitations)).

6. For **manual** journeys, open the journey page → **Inscribir contacto manualmente** (Enroll contact manually).
7. From the journey page you can **Pausar** / **Activar** (Pause / Activate), view active enrollments, each contact's current step and the **next run** (date and time).
8. For **Activo** (Active) or **En espera** (Waiting) enrollments, use **Cambiar paso** (Change step) to move the contact to another step. The journey continues from there and will run that step (it may resend an email or restart a wait). Admins only.

**On a person's record** (**Activity** → **Recorridos** / Journeys):

- You will see the contact's **latest 5** enrollments (journey, status, current step and enrollment date).
- **Ver más** (View more) opens the full history, including completed or cancelled enrollments, and the next run if waiting.
- The journey name links to its page (admins only).

### Lead scoring

1. Menu **Puntuación de leads** → **Nueva regla** (New rule): name, event type (email opened, click, form, web visit, deal created…), points (+/-), decay in days (0 = no decay) and additional conditions.
2. **Active** rules are evaluated on marketing events; the contact's **lead score** and **lifecycle** update (full recalculation also runs nightly).
3. Lifecycle stages on the person record: *subscriber* → *lead* → *mql* → *sql* → *opportunity* → *customer* → *evangelist*.

> **Important:** scoring lifecycle **does not** indicate an open sales **deal**. For operational sales, check the contact's **Deals**.

### Web tracking and landing pages

**Tracking snippet:** add this script to your site (served by Cream):

```html
<script src="https://YOUR-CREAM-DOMAIN/cream.js" async></script>
```

It records visits and UTM parameters; when a capture form is submitted, Cream tries to link prior anonymous activity to the identified contact.

**Landing pages:** in **Formularios → Plantillas de formulario**, create a template with type **Landing page** and set the **public slug**. URL: `/p/workspace-slug/landing-slug`. Content is Liquid, like lead forms.

### Attribution

Menu **Atribución**:

1. Filter by **UTM source**, **UTM medium**, **UTM campaign** and **period** (month, quarter, year).
2. The table groups by channel: **Visitas** (Visits), **Leads**, **MQL**, **Deals** and **Ingresos** (Revenue).
3. Click **Leads**, **MQL** or **Deals** numbers to open filtered lists for that channel.

Campaigns can define UTMs propagated to email links; forms and web tracking feed the same report.

### Notes

- Any member can use campaigns, segments, journeys and attribution; **Settings → Mailjet** is **admins** only.
- Campaign and journey sends **do not reach** contacts unsubscribed from the chosen type or **suppressed** addresses (bounce, spam, global opt-out).
- **Forms** and detailed capture: [§27](#27-lead-capture-forms).

---

## 30. Coming soon

These features exist in the code but are **not available** in the interface until their implementation is complete (controlled by `CreamFeatures`):

| Feature   | Current status |
|-----------------|---------------|
| **Mail merge**  | Classic bulk send to saved view, list or manual IDs; practically replaced by **Campaigns** + **Segments** |
| Slack           | Partial notifications (deal stage changes only) |
| AI automations  | Proactive hooks in automations (summarize on deal close, scoring, etc.) |

When enabled, they will appear in the sidebar menu and the corresponding sections of this manual should be updated.

---

## Maintaining this manual

This file is maintained by the developers whenever visible functionality changes. See the `cream-user-manual` skill in `.claude/skills/cream-user-manual/SKILL.md`.
