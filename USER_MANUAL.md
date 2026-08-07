# User Manual — Cream

> 🇪🇸 [Versión en español](MANUAL_USUARIO.md)

Cream is a **workspace**-based CRM for managing **people**, **companies** and **deals** (opportunities), with notes, tasks, lists and an activity history shared across the team.

> **Last revision:** 2026-08-06 (public form Liquid templates)
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
22. [API tokens](#22-api-tokens)
23. [Reports](#23-reports)
24. [AI assistant](#24-ai-assistant)
25. [Knowledge chat](#25-knowledge-chat)
26. [Stripe payments](#26-stripe-payments)
27. [Lead capture forms](#27-lead-capture-forms)
28. [Calendar bookings](#28-calendar-bookings)
29. [Coming soon](#29-coming-soon)

---

## 1. Account and access

### Sign in

On the sign-in screen you can:

- **Sign in with Google** (if configured in your environment).
- Use an **email and password** registered in Cream.

If you forgot your password, use **Forgot password?** to receive a reset link by email.

### Create account

In **Create account** you enter your name, email, password and the workspace name. When you sign up:

- Your user is created.
- A new workspace is created with the given name (or «Name's Workspace» if you don't provide one).
- You are the **admin** of that workspace.

### Change your name

1. Open **Settings → Profile** (also from your name at the bottom of the sidebar).
2. In **Datos personales**, edit the **Nombre** field.
3. Click **Guardar**.

Your name updates in the sidebar, mentions and team activity. The email is shown in the same section, but it cannot be changed from there.

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

| Section        | Description |
|----------------|-------------|
| **Search...**  | Global search. Keyboard shortcut: `/` |
| **Notifications** | Workspace alerts (mentions, etc.) |
| **Dashboard**  | Workspace overview |
| **People**       | Contact people |
| **Companies**    | Companies |
| **Deals**        | Kanban board of opportunities |
| **Products**     | Product catalog |
| **Tasks**        | All workspace tasks |
| **Mail merge**   | Personalized email sending to several records |
| **Plantillas**   | Reusable email templates |
| **Alertas**      | Date-based alert rules with deal/company conditions |
| **Webhooks**     | Outgoing HTTP integrations |
| **Stripe**       | Payments imported from Stripe and their reconciliation with deals |
| **Pipelines**    | Sales pipeline configuration |
| **API tokens**   | Tokens for MCP / API clients |
| **Profile**      | User name and personal preferences in the workspace (pipeline, briefing, alert channels) |
| **Settings**     | Workspace configuration (admins only): name, deal visibility, sales director, OKM |
| **Team**         | Members and invitations |
| **Custom fields**| Extra fields per record type |
| **Lists**        | Custom lists (bottom of the menu) |

Menu entries that depend on disabled features do not appear until they are enabled (see [Coming soon](#29-coming-soon)).

### Customizing the menu

Next to the **Menu** title in the sidebar there is a gear icon. Clicking it enters **edit mode**:

- **Reorder:** drag a section by the grab icon (⋮⋮) to the position you want.
- **Hide or show:** use the eye icon on each section. Hidden entries no longer show in the normal menu, but remain visible (dimmed) while editing so you can restore them.

Changes are saved automatically for **your user** when you leave edit mode (click the gear again). Each person in the workspace has their own configuration; it does not affect Search, Notifications or the Lists section.

### Active pipeline

Below the workspace name, the sidebar shows the **active pipeline**. You can choose your default pipeline for that workspace in **Settings → Profile**. It is the one selected when you sign in and when you open the Gmail add-on. When you change the active pipeline:

- **Deals** (board and table) filter by that pipeline.
- **Dashboard** and **Reports** use that pipeline as the default filter in deal metrics.
- The **Todos los pipelines** (all pipelines) option removes the filter where applicable (the kanban board keeps showing the default pipeline, because its columns belong to a specific pipeline).

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

- **Director de ventas (sales director):** daily AI-generated briefing with guidance for the team, classified as **Urgente** (urgent) and **Importante** (important). It only appears in workspaces where an administrator has enabled it in **Settings** (checkbox *Briefing diario del director de ventas*), and it also requires AI to be configured on the server (`CREAM_AI_API_KEY`). Each user can turn it off for themselves in **Settings → Profile** (checkbox *Mostrar briefing del director de ventas en el dashboard*); you can also open Profile from your name at the bottom of the sidebar. To enrich the report, the director uses CRM read tools, the workspace **OKM** (if configured) and **persistent memory** (llmemory) with learnings from previous briefings. In addition, each user who has it enabled receives a **Para ti** (for you) block with direct guidance, **Aciertos** (congratulations on recent wins) and **A mejorar** (mistakes or omissions with a recommendation). If a deal already has a **next action** (an open task with a future date), the briefing does not ask for parallel actions nor flags it as inactive; at most it may suggest **moving that date up**. Deals without an open task can appear as pending a defined next step. If there is no briefing for the day yet, you can click **Generar ahora** (generate now); if one already exists, you can click **Regenerar** (regenerate) up to 5 times a day (the number of regenerations you have left is shown). Guidance items can link to deals, people, companies or tasks; in the team block, the ones assigned to you are highlighted.
- **Metric cards:** number of people, companies, open pipeline value and won revenue (deals in a *won* stage). Deal metrics respect the **active pipeline** (see above); people and companies cover the whole workspace.
- **Pipeline by stage:** bars showing the distribution of deals per stage. If you have an active pipeline, the chart and the deal cards use that pipeline; if you choose **Todos los pipelines**, the chart shows the workspace's default pipeline and the cards add up all deals.
- **Upcoming tasks:** upcoming pending tasks (mark them complete with one click).
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

- They represent sales opportunities with **value**, **currency**, **stage**, **probability**, **expected close date** and optional **invoice number** (*Nº factura*).
- They are linked to a **company** and an **owner**; **contacts** are optional.
- They can include **product lines** (catalog products with quantity and price).
- When **creating a deal** (`New deal`):
  - Choose **Pipeline** and **Stage** to decide which stage the opportunity enters.
  - In **Company**, type to search for the company and pick a suggestion; if it doesn't exist, use **+ Create "…"** to create it on the spot. **Contacts** are optional (you can create a new one with **New** without leaving the form).
  - In the **New contact** dialog you can enter **First name** (required), **Last name**, **Email**, **Phone**, **Contact source** (*Formulario web*, *Recomendado*, *Lo trae alguien del equipo* — web form, referral, brought in by a team member) and **First contact date**.
  - In **Products of interest** you can add catalog products with **Edition** (searchable picker: select an existing one or **+ Create "…"**) and quantity before saving.
  - You must define a **Next action** (a task with a future date) to be able to create the deal.
  - Optionally set **Nº factura** (invoice number) when you already have one; you can also add or change it later when editing the deal.
- They have a **Version history** that stores every change to the deal's attributes (value, name, probability, etc.) and lets you check what the deal looked like at a specific moment.
- When **editing** a deal and saving a stage change to **Won**, a brief celebration animation is shown on screen before returning to the record. If the new stage is **closed** but not a winning one (e.g. *Lost*), a defeat animation is shown. The same happens when changing stage with the **Move to stage** buttons on the deal page. It does not happen when moving cards on the kanban board. If the target stage has **entry conditions** that the deal does not meet, the change is rejected, an error notice is shown and the deal remains in its original stage.
- From a deal's page you can **Duplicar** (duplicate) the deal with one click: a copy is created with the same name plus «(copia)» (copy), company, contacts, stage, value, currency, probability, close date, owner, custom fields and in-progress tasks. The **invoice number is not copied**. Product lines, notes, attachments, emails and the activity history are not copied.
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
- **Table** (button on the board): table view with the same filters (including stage), saved views, custom fields and CSV import/export.

On the board, a saved view with a **stage** filter does not restrict the columns (stages already are columns); the other filters do apply.

---

## 6. Products

The **Products** catalog stores reusable products for creating lines in a deal. From a deal page — or when **creating a new deal** — you can add products with quantity, edition and unit price; the deal value can reflect those lines.

Each product can be tagged with a **B2B** or **B2C** **segment** when creating or editing it. In the product list you can filter and sort by segment.

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

**Lists** group records of a single type (Person, Company or Deal) with a name and a color. They appear at the bottom of the sidebar.

- Create a list with the **+** button next to «Lists».
- Add or remove records from the record page or from the list view.
- Useful for campaign segmentation, manual follow-up or ad hoc groupings.

---

## 9. Pipelines and kanban board

A **pipeline** defines the **stages** a deal moves through (name, color and close probability).

### Managing pipelines

In **Pipelines** you can:

- Create a new pipeline with its stages.
- Edit stages, probabilities and colors.
- **Reorder stages** by dragging the row by its handle (dots icon) while editing a pipeline; save the changes with **Save changes**.
- Mark a pipeline as the **default** (the one used by new deals and by the board when you choose *Todos los pipelines* — all pipelines).
- Choose which **fields are visible on board cards** (checkboxes when editing the pipeline): value, company, owner, close date, probability, **invoice number**, contacts, products and editions. Default: value, company, close date and owner.
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
- If there are several pipelines, you can also change the active pipeline from the header selector (the board always shows one specific pipeline).
- Cards with **pending tasks** show a task icon in the top-right corner: **red** if any task is overdue, **blue** if all are on time or have no due date. **Hover** over the icon to see the next pending task (title, due date and assignee) without opening the deal page; if there are several pending ones, it also shows how many remain.
- The fields visible on each card (value, company, owner, close date, probability, invoice number, contacts, products and editions) depend on the active pipeline's configuration — see [Managing pipelines](#managing-pipelines).
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

When you open a person, company or deal you will see:

**Left panel (attributes):** main data, custom fields, relationships between contacts (people only), lists it belongs to and (for deals) the pipeline and stage selector.

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

Open the record's detail page and scroll down to the **Send email** section (in the main column, next to Notes and Tasks).

### Sending an email

1. Fill in **To** (recipient), **Subject** and **Message body...**.
2. Click **Send email**.
3. The email is sent (from the workspace address via SMTP, or from **your Gmail** if you have it connected) and is saved in the record's history.
4. An entry of the form *"Your name sent “Subject” to recipient@…"* appears in the record's **Timeline**.

Right below the form you will see the **last 10 emails** for that record (sent and, with Gmail, received replies), with their subject and labels.

### Open and click tracking

Sent emails include automatic tracking:

- When the recipient **opens** the message, the email shows the **Opened** label in the sent list, the open is recorded in the record's **Timeline** and you receive an open **notification**.
- When the recipient **clicks** a link in the message, the click is also recorded in the **Timeline**.

> **Notes**
> - Sending uses the server's mail (SMTP) configuration; tracking requires the application to be reachable from the Internet (already configured in production).
> - In development, emails are not actually sent: they show up in **Mailbin** (`/mailbin`).
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

- the email list (sent and **Received** if applicable): subject, recipient or sender, body and labels such as **Sent**, **Opened**, **Replied** or **Received**
- the related activity in the **Timeline** (sends, opens, clicks, detected replies)

The same applies to **Mail merge** sends: each email appears on the corresponding record's page and is visible to the whole workspace team.

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

1. **Connect with CReaM** — authorize with your CReaM account (OAuth).
2. Choose the destination **Workspace** and **Pipeline**. When you open it, the
   **Example** workspace and your default pipeline for that workspace are proposed. New deals are
   always created in the first stage of the pipeline.
3. **Link the thread** to an existing deal (suggestions and search are
   limited to the selected workspace).
4. **Create a new deal** from the thread — it is created in the first stage of the
   selected pipeline and all messages are imported into its **Emails** section.

To install it (users):

1. Open the internal **CReaM Gmail** link provided by the Example administrator,
   or go to [Internal Marketplace apps](https://workspace.google.com/marketplace/mydomainapps).
2. Click **Instalar** (Install) and accept the requested Gmail permissions.
3. Open Gmail, select a thread and click the **CReaM** icon in the right sidebar.
4. Click **Connect with CReaM**, sign in at `crm.example.com` and authorize access.

**Example administrators:** the complete guide to publishing the add-on on Marketplace,
installing it for the whole domain and troubleshooting is in
[`deploy/GMAIL_ADDON_SETUP.md`](deploy/GMAIL_ADDON_SETUP.md).

The add-on is private to the Example domain. Each person connects their own
account; do not share authorization links or tokens.

### Email templates

**Templates** save you from rewriting frequent emails (introduction, follow-up, etc.).

- **Create and manage:** go to **Plantillas** (Templates) from the sidebar menu. Each template has a **name**, **subject** and **body**, and you can mark it as **shared** with the whole workspace or keep it personal. The **body** uses a rich text editor (bold, italic, color, lists, links, etc.); formatting is stored in an email-client-friendly way.
- **Predefined templates (Example):** the organization workspace includes eight templates for the course cycle (first contact, confirmed booking, payment reminders, closing, etc.). You can edit them from **Plantillas** if you are an administrator.
- **Variables:** use `{first_name}`, `{last_name}`, `{name}`, `{company}` and `{email}` in the subject or body; when inserted they are replaced with the record's data. Texts in square brackets such as `[Nombre del curso]` or `[fechas]` are placeholders you must fill in manually after loading the template.
- **Use in an email:** in the **Send email** section of a record (Person, Company or Deal), open **Insertar plantilla…** (Insert template…) and pick one. The subject and body are filled in automatically with the variables already substituted for that contact. You can edit the message with the same rich text editor before sending. If there are no templates yet, you will see a link to create them.

### Bulk sending (Mail merge)

**Mail merge** sends the same **personalized** email to several records at once.

#### How to access

**Mail merge** entry in the sidebar menu.

#### Steps

1. In **Recipients**, choose who to send to:
   - a **saved view** (all records matching its filters),
   - a **list**, or
   - **Enter record IDs manually** to provide comma-separated IDs.
   The text below the selector shows **how many recipients** will receive the email.
2. Optional: choose a **template**; if you use one, its body is sent (personalized per recipient). If not, compose the form's **Subject** and **Body** with the rich text editor.
3. Use variables such as `{name}` or `{first_name}` in the subject and body to personalize each send.
4. Click **Send mail merge**. Each email is recorded on the corresponding record's page, with open tracking just like an individual send.

> **Notes**
> - Emails are only sent to records with an email address (for deals, the first contact's email is used).
> - Each send is linked to its record and shares a batch identifier.

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
- *Notify Slack* does nothing until the Slack integration is enabled (see [Coming soon](#29-coming-soon)).

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

If you disable both channels, you will not receive alerts even when a rule lists you as a recipient.

### Notes

- Each rule notifies **only once** per deal and recipient; it does not repeat on following days.
- Alerts are evaluated **once per day** on the server.
- Alerts appear in **Notifications** with a link to the deal.

---

## 18. Webhooks

In **Webhooks** you configure URLs that Cream will call when events occur (e.g. creation or change of a deal).

- **New webhook:** destination URL and subscribed events.
- You can **enable/disable**, **edit** or **delete** each webhook.

Useful for integrating Cream with other systems (Zapier, your own scripts, etc.).

---

## 19. Notifications

**Notifications** in the sidebar menu shows workspace alerts: **comment** mentions, **alerts** configured by the administrator, lead form submissions, etc. Mentions in a **task** title assign the task but do not generate an alert for now.

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

In **Settings** (admins only):

### General

- Change the **workspace name**.
- **Salespeople can view other users' deals** — when enabled, salespeople see all deals in the workspace on lists, boards and detail pages (not only their own or shared as collaborators).
- **Salespeople can edit other users' deals** — when enabled, salespeople can update, move and delete any deal in the workspace. Enabling edit also allows viewing those deals.

By default both options are off: salespeople only see and edit their own deals and those explicitly shared with them as collaborators.

- **Sales director briefing (AI)** — enables the daily team briefing on the dashboard (requires `CREAM_AI_API_KEY` on the server).

### OKM

Connect the corporate knowledge base (Google Shared Drive) for the contextual chat and AI briefings:

1. Enable **OKM chat for this workspace**.
2. Enter the **Google Shared Drive ID** (from the Drive URL).
3. Paste the **service account JSON** with read access to that drive. Once saved, the JSON is not shown again; the configured account email is displayed. Leave the field blank on later edits to keep the current key.

Each workspace can use a different drive and service account.

---

## 22. API tokens

In **API tokens** you generate access tokens to connect **MCP** clients (Claude, Cursor, etc.) or the **REST API v1** to your workspace.

1. Provide a descriptive name.
2. **Create token** — the full value is shown **only once**; copy it before leaving the page.
3. **Revoke** (trash icon) invalidates an existing token.

Each token is tied to your user and to the workspace that was active when it was created.

---

## 23. Reports

**Reports** let you measure your activity by combining a metric, a grouping and a period, and save the combinations you use most.

### How to access

**Reports** entry in the sidebar menu.

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
2. Provide the **name**, the **slug** (it will appear in the public URL `/f/slug`), the form **template**, the **pipeline** where the deal will be created, the optional **stage** (after choosing the pipeline), the **owner** (receives the notification and the follow-up task), the **first task text** and **days until due** (from deal creation when the form is submitted; 0 = same day), and the **email template** that will be sent to the lead.
3. Optional: set a **redirect URL after submission** (e.g. `https://example.com/thanks`) to send the visitor to a page on your site. If left blank, Cream's thank-you page is shown (`/f/slug/success`).
4. Optional: define **additional hidden fields** (one per line, e.g. `producto`, `landing`). Their values are passed as query params in the public or iframe URL, e.g. `/f/slug?producto=curso-ia`. They are saved with the submission and shown on the deal under **Formulario de origen** (Source form).
5. Optional: select a **product** from the catalog if the form should attach a product line to the deal (e.g. course reservations). Visitors can override it with `?product_id=` in the URL. Reservation templates show that product's **open editions**.
6. Check **Recoger datos de empresa** (Collect company data) if the form should ask for the company name and tax ID (CIF). When enabled, submissions with an empty company name still succeed server-side (a placeholder company is used); mark the field `required: true` in the template if you want to enforce it in the browser.
7. Save. In the list you will see the **public URL** and the **iframe code** ready to copy.

### Form templates (administrators)

The **layout and fields** of each public page are defined in **Liquid** templates stored in the workspace, not in the form record itself.

1. From **Formularios** (Forms), click **Plantillas de formulario** (Form templates) — administrators only.
2. Filter by **Páginas** (Pages — full forms, e.g. `contacto`, `liderando_ia_reserva`) or **Parciales** (Partials — reusable blocks: contact fields, GDPR consent, etc.).
3. **Edit** opens a syntax-highlighted Liquid editor. Pages use tags such as `{% field %}`, `{% partial 'contact_fields' %}`, `{% form_open %}`, and variables like `{{ lead_form.name }}`.
4. **New template**: enter a short **name** (e.g. `my_form` for a page, or `my_block` for a partial) and check **Es un parcial** (Is a partial) if it is not a full page.
5. After creating or changing a **page** template, select that name in **Plantilla del formulario** (Form template) when configuring a capture form.

If a page template does not exist in the workspace, the public URL `/f/slug` will return an error.

### What happens when a form is submitted

- A **person** is created or reused by email (source "Formulario web"). If the person already existed, only blank fields are filled in (name, last name, phone, job title…).
- If that person already has an **open deal** in the form's pipeline, that deal is **reused**: new form data is added to the submission (without creating another deal or another follow-up task). If you configured a **stage**, the deal advances to it only when it is in an earlier stage (it never moves backwards). If there is no open deal in that pipeline (for example, only won or lost deals, or deals in another pipeline), a new deal is created in the configured stage or, if none is set, in the pipeline's **first stage**, with the form's configured **first task** (default: **Contactar lead** / Contact lead, due the next day) assigned to the owner.
- The submission data (form fields, source page, UTM, browser, IP…) is saved and visible on the deal's page, under **Formulario de origen** (Source form).
- The lead receives the configured email; the owner receives a notification with the data and a link to the deal.

### Notes

- Inactive forms do not accept submissions.
- If the configured stage has **entry conditions** and the deal does not meet them, it stays in its current stage and the submission is still saved.
- If the form does not ask for a company, the person is associated with the workspace's generic **Particulares** (Individuals) company (unless the person already existed with another company).
- The **Liderando con IA** form (`/f/liderando-ia`) asks for name, email, phone, company, whether it is for you or your team, how you heard about us, newsletter (optional, unchecked) and data-protection consent; it creates deals in the **Formación B2C** pipeline.
- The **Liderando con IA — Reserva** form (`/f/liderando-ia-reserva`) asks for edition, name, last name, email, phone, an optional free-text message and data-protection consent; it creates deals in the **Formación B2C** pipeline.
- The **Desarrollando con IA — Reservas** form (`/f/desarrollando-con-ia-reservas`) asks for edition (buttons), name, last name, email, phone with country prefix, an optional free-text question (“How can we help you?”) and data-protection consent; it creates deals in the **Formación B2C** pipeline.
- The **Trabajando con IA** form (`/f/trabajando-ia`) asks for name, email, phone, an optional question about which work task to solve with AI, how you heard about us, newsletter and GDPR consent; it creates deals in the **Formación B2C** pipeline.
- The **Desarrollando con IA** form (`/f/desarrollando-ia`) asks for name, email, phone, technical profile, audience (individual or team), how you heard about us, newsletter and GDPR consent; it creates deals in the **Formación B2C** pipeline.
- The **Demo Adoption** form (`/f/adoption`) asks for name, email, phone, an optional question about the organization's degree of AI adoption, how you heard about us, newsletter and GDPR consent; it creates deals in the **Proyectos** pipeline.
- The **Assessment · Índice de adopción** form (`/f/indice-adopcion-ia`) asks for name, email, phone, company, job title, size (number of employees), how you heard about us, newsletter and GDPR consent; it creates deals in the **Proyectos** pipeline.
- The **Entrenadores** form (`/f/entrenadores`) asks for name, email, an optional question about your main challenge with AI, newsletter (optional, unchecked) and data-protection consent; it does not ask for phone or how you heard about us; it creates deals in the **Entrenadores** pipeline.
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
| Mensaje de bienvenida (Welcome message) | Text in the public page header |
| Avatar URL / Logo URL | Optional profile images |
| Zona horaria (Time zone) | Default time zone of the page (dropdown list) |
| Ventana de reserva (días) (Booking window, days) | How many days ahead dates can be chosen |
| Calendarios (Calendars) | Google calendars where slots are checked; drag to reorder — the first one marked writable receives the bookings ("Recibe nuevas citas" badge) |
| Página activa (Page active) | If unchecked, the public URL does not accept bookings |

**Event types** (at least one is required; drag the ⋮⋮ handle to change the order)

| Field | Description |
|-------|-------------|
| Slug | Identifier of the type in the URL and the API |
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

Use **Añadir tipo** (Add type) to create new types or the trash icon to remove them. Save the page to apply the changes.

Copy the **public URL** and share it with clients.

### What happens when someone books

- **Real availability** is checked against the configured calendars (`primary` by default).
- Upon confirmation, the **event is created in Google Calendar** with invitations to attendees and optional guests (up to 5).
- In Cream, a **person** and a **deal** are created in the specified pipeline, with a follow-up task for the host.

### Public page (visitor)

Three-step flow: choose event type → calendar and time (with an ES/EN time zone selector) → form and confirmation with a Meet link and `.ics` download.

---

## 29. Coming soon

These features exist in the code but are **not available** in the interface until their implementation is complete (controlled by `CreamFeatures`):

| Feature   | Current status |
|-----------------|---------------|
| Slack           | Partial notifications (deal stage changes only) |
| AI automations  | Proactive hooks in automations (summarize on deal close, scoring, etc.) |

When enabled, they will appear in the sidebar menu and the corresponding sections of this manual should be updated.

---

## Maintaining this manual

This file is maintained by the developers whenever visible functionality changes. See the `cream-user-manual` skill in `.claude/skills/cream-user-manual/SKILL.md`.
