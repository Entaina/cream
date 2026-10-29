# Gmail add-on (CReaM) — Enablement for the organization

The add-on lets you **link a Gmail thread to a deal** or **create a new deal**
from the open email (like Streak). It is a **private** Google
Workspace Marketplace application, available only to `@example.com`.

- Code: [`gmail_addon/`](../gmail_addon/)
- CReaM: **https://crm.example.com**
- User manual: [`USER_MANUAL.md`](../USER_MANUAL.md) § "Gmail add-on"

## Summary: who does what

| Role | Responsibility |
|-----|-----------------|
| **Developer** | Push code, configure OAuth, publish in Marketplace SDK |
| **Google Workspace administrator** | Install the add-on for the domain and allow internal apps |
| **End user** | Connect their CReaM account (OAuth) and use the add-on in Gmail |

The organizational installation **does not replace** the OAuth connection: each user must
click **Connect with CReaM** once; the token is stored in their private
Apps Script properties.

---

## Prerequisites

- CReaM deployed at `https://crm.example.com` (includes `public/gmail-addon-icon.png`)
- Google Workspace account `@example.com` with administrator permissions (to publish and install)
- Node.js + [`clasp`](https://github.com/google/clasp): `npm install -g @google/clasp`
- **Apps Script API enabled**: [script.google.com/home/usersettings](https://script.google.com/home/usersettings)
- A **standard Google Cloud** project linked to the script (not the default Apps Script GCP project)

---

## Part 1 — Add-on development (Apps Script)

### 1.1. Push the code

```bash
cd gmail_addon
clasp login
clasp push
clasp open-script    # opens the editor (clasp open no longer exists in recent clasp)
```

Before the first push, copy [`gmail_addon/.clasp.json.example`](../gmail_addon/.clasp.json.example) to `gmail_addon/.clasp.json` (git-ignored) and set your `scriptId`, and replace `YOUR-CREAM-DOMAIN` in `appsscript.json` with your Cream domain.

### 1.2. OAuth callback URI

The add-on uses the `apps-script-oauth2` library (v43 in `appsscript.json`). The
callback is **`/usercallback`**, not a Web app (`/exec`).

In Apps Script run **`logCreamRedirectUri`** and copy the URI:

```
https://script.google.com/macros/d/TU_SCRIPT_ID/usercallback
```

### 1.3. Register the OAuth client in CReaM

On the production server, from `~/cream`:

```bash
docker compose exec -T web bin/rails "oauth:create_api_client[CReaM Gmail add-on,https://script.google.com/macros/d/TU_SCRIPT_ID/usercallback]"
```

Save the printed **`client_id`**. `POST /oauth/register` only issues `mcp` clients, so it cannot create this one. A single client works for the whole organization.

### 1.4. Script properties (required)

In Apps Script → **Project Settings → Script Properties**:

| Property | Value |
|-----------|--------|
| `CREAM_BASE_URL` | `https://crm.example.com` |
| `CREAM_CLIENT_ID` | `client_id` from step 1.3 |

Delete `CREAM_REDIRECT_URI` if it exists: the OAuth2 library computes `/usercallback` on its own.

Without these properties the add-on cannot authorize users.

### 1.5. Add-on icon in Gmail

In `appsscript.json`, `addOns.common.logoUrl` points to:

```
https://crm.example.com/gmail-addon-icon.png
```

Deploy CReaM **before** testing the icon; if the URL returns 404, Gmail does not
show the icon. The Marketplace assets are in `public/marketplace/` (see §2.4).

### 1.6. Test on your own (optional)

Only for the owner of the Apps Script project:

1. **Deploy → Test deployments → Install**
2. Gmail → open a thread → CReaM → **Connect with CReaM**
3. **Connected to CReaM** should appear; close the tab and go back to Gmail

---

## Part 2 — Google Cloud and Marketplace SDK

### 2.1. Standard GCP project

The default Apps Script GCP project **does not allow publishing** to Marketplace.

1. Create a project in [Google Cloud Console](https://console.cloud.google.com/) (e.g. "Addon CReaM").
2. Apps Script → **Project Settings → GCP → Change project** → enter the project **number** (not the textual ID).
3. **Google Auth Platform → Branding**: name "CReaM", support email.
4. **Audience → Internal** (only `example.com` users).
5. **Data Access**: scopes from the manifest. `gmail.addons.current.message.readonly` lets the add-on read the open message and the other messages in that same Gmail thread. Do not add `gmail.readonly`. A domain install does not share the Apps Script project, and requesting that scope sends users to the project file (**Necesitas acceso**, Lector/Editor).

Do not manually create a Web/Desktop-type "OAuth client ID": Apps Script generates its own when the project is linked.

### 2.2. Enable the Marketplace SDK

In the same GCP project:

```
https://console.cloud.google.com/apis/library/appsmarket-component.googleapis.com
```

Click **Enable**. It must be the **Google Workspace Marketplace SDK**, not the "Marketplace API".

Add-on configuration:

```
https://console.cloud.google.com/apis/api/appsmarket-component.googleapis.com/googleapps_sdk
```

If **Manage** does not open the form, check IAM permissions (Editor/Owner or the
*Workspace Marketplace App Configuration Admin* role).

### 2.3. Add-on deployment (only once; afterwards just update)

1. `clasp push`
2. Apps Script → **Deploy → New deployment**
3. Type: **Add-on** (not "Web app" or "API executable")
4. New version → **Deploy**
5. Copy the **Deployment ID** (not to be confused with the Script ID or the CReaM `client_id`)

**Important:** keep this Deployment ID. For updates, edit the same
deployment (**Deploy → Manage deployments → pencil → New version**).
Do not create new deployments unless you switch GCP projects.

### 2.4. App Configuration (Marketplace SDK)

On the SDK configuration page:

| Field | Value |
|-------|--------|
| **Visibility** | Private |
| **Installation** | Individual + admin install (recommended) or Admin only |
| **Integration** | Google Workspace add-on → Apps Script |
| **Deployment ID** | the one from step 2.3 |
| **Gmail** | Detected from the manifest (`addOns.gmail`); do not check Docs/Sheets/Drive |

Do not check **Web app** or editor add-ons.

Save with **Save draft** and continue with the listing.

### 2.5. Store Listing (Marketplace listing)

Fill in all required fields and click **Publish** ("Save draft" is not enough).

**Suggested texts**

- Name: `CReaM`
- Short description: *Link Gmail emails to CReaM deals or create opportunities from the thread.*
- Application website: `https://crm.example.com`
- Support URL: `https://crm.example.com`

**Icons** (already in the repo):

| Use in the listing | File |
|-----------------|---------|
| 32×32 | `public/marketplace/icon-32.png` |
| 48×48 | `public/marketplace/icon-48.png` |
| 96×96 | `public/marketplace/icon-96.png` |
| 128×128 | `public/marketplace/icon-128.png` |
| Card banner 220×140 | `public/marketplace/card-banner-220x140.png` |
| Screenshot | `public/marketplace/capture.png` (upload your own) |

**Draft reviewers** (optional if you publish directly):

- `@example.com` emails allowed to preview the draft
- **Opt-out URL**: an internal Google Form where they can request to stop being a reviewer

After **Publish**, the Store Listing tab should say **This app is published** and
show the **listing URL** (Marketplace listing URL).

---

## Part 3 — Enablement for the organization (administrator)

Publishing the listing and installing it for the organization are different steps.
A Cloud project Owner can publish the listing. Only a Google Workspace
**Marketplace administrator** can install it for the domain. That role is not the
super-admin role and it is not the Cloud project Owner.

### 3.1. Two lists, two meanings

| Place | What a listing there means |
|-------|----------------------------|
| [mydomainapps](https://workspace.google.com/marketplace/mydomainapps) | The private listing is **published**. People in the domain can install CReaM themselves. It does not mean an admin installed it for the organization. |
| Admin console → **Apps → Google Workspace Marketplace apps → Apps list** | Apps an administrator **installed for the organization** (Domain installed) or **allowlisted**. CReaM missing here means there is no domain install. The page requires the Marketplace administrator privilege; without it the list is empty. |

A **test deployment** (Apps Script → Deploy → Test deployments) appears in neither list. It runs for the script owner only. Any other account that opens it gets the Apps Script file page **Necesitas acceso** / **You need access**, with **Lector** / **Editor**. That page is Drive sharing for the script project, not the Gmail consent screen. Do not approve it and do not share the project. Viewer can read the source. Editor can change the code and the script properties (`CREAM_CLIENT_ID`).

### 3.2. Allow internal Marketplace apps

Google Admin Console → **Apps → Google Workspace Marketplace apps → Settings**

Enable (depending on your organization's policy):

- **Allow users to install and run any internal app from Marketplace**

If the organization uses an **allowlist**, add CReaM to the allowed list or install it
as an administrator (§3.3).

### 3.3. Install for the whole domain (recommended)

An account with the Marketplace administrator privilege:

1. Open [mydomainapps](https://workspace.google.com/marketplace/mydomainapps) signed in as that admin, or Admin console → **Apps → Google Workspace Marketplace apps → Apps list** → **Install app**.
2. Open **CReaM**.
3. **Admin install** → **the whole organization**, an **OU**, or **groups**.
4. Accept the permissions.

CReaM then shows under **Domain installed apps**. The org install does not replace the per-user CReaM connection: each person still clicks **Connect with CReaM** once (§4).

Users can also install it themselves from `mydomainapps`. That is an individual install. It does not create a domain **Grant access** button.

### 3.4. Scopes the installation grants

| Scope | What it covers |
|-------|----------------|
| `gmail.addons.execute` | Run the add-on |
| `gmail.addons.current.message.readonly` | The open message and the other messages in **that same Gmail thread**, including calendar text carried in the message body or `.ics` attachments GmailApp can read |
| `script.external_request` | Call the CReaM API |
| `script.scriptapp` | OAuth callback used by **Connect with CReaM** |

The manifest does **not** request `gmail.readonly`. That scope would let the add-on search the mailbox outside the open thread (same subject, `In-Reply-To` / `References`). Asking for it calls `ScriptApp.getAuthorizationInfo().getAuthorizationUrl()`, which opens the Apps Script **project file**. A domain install does not add users as viewers of that file, so they still see **Necesitas acceso** (Lector/Editor) after the organization install. Do not share the project to get past that page.

Cloud only declares scopes. It does not grant them, and it cannot hide that page.

### 3.5. A scope added after the domain install

Google does not email the admin. If a later version adds an OAuth scope and the app is already installed for the organization, **Data access** shows **Partially granted**. Admin console → the app → **Grant access**. That button is only in the Admin console, and only for a scope the published Marketplace listing already requests. It still does not give access to the Apps Script file. Do not use it as a way to add `gmail.readonly`.

### 3.6. Verify it is available

| Where | What to expect |
|-------|-------------|
| Store Listing (GCP) | Status **published** + listing URL |
| [mydomainapps](https://workspace.google.com/marketplace/mydomainapps) | CReaM listed as an internal app (published, not necessarily domain-installed) |
| Admin → Apps list → Domain installed | CReaM, only after §3.3 |
| Admin → Data access | **Granted** for the scopes in the published listing. `gmail.readonly` is not one of them |
| Gmail → open thread | CReaM icon in the right sidebar |

If the listing is in draft but not published, it will not appear on `mydomainapps` or in the admin list.

---

## Part 4 — Usage by each user

After the organizational installation, **each person** must connect their CReaM account:

1. Open Gmail → select an email
2. Right sidebar → **CReaM** icon
3. Click **Connect with CReaM** → sign in to `crm.example.com` → authorize
4. See **Connected to CReaM** → close the tab → go back to Gmail

In the add-on:

- **Destination:** workspace (Example by default) and pipeline (the profile's default)
- **Create deal from thread:** creates a deal in the **first stage** of the chosen pipeline
- **Link to deal / Search:** links the thread to an existing deal

The default pipeline is configured in CReaM → **Settings → Profile** (per workspace).

---

## Part 5 — Add-on updates

1. Deploy CReaM if assets in `public/` change (e.g. icons).
2. `cd gmail_addon && clasp push`
3. Apps Script → **Deploy → Manage deployments**
4. Edit the **same** deployment → **New version** → Deploy
5. **Do not change** the Deployment ID in the Marketplace SDK

Users **do not reinstall**; they keep their OAuth unless the `client_id` or scopes change.
A new OAuth scope on a domain install stays inactive until an admin grants it (§3.5). Do not add `gmail.readonly`: granting it does not stop the Apps Script access page.

If you change the Script ID or the `/usercallback` URI, register a new OAuth client
(§1.3) and update `CREAM_CLIENT_ID`.

---

## Common problems

| Symptom | Likely cause | Solution |
|---------|----------------|----------|
| **Necesitas acceso** / **You need access**, with **Lector** / **Editor** | The browser opened the Apps Script **project file**. A domain install does not share that file. The usual cause is a deployed version that still requests `gmail.readonly` via `getAuthorizationUrl()`, or a test deployment | Do not approve Viewer or Editor. Deploy a new version of the **same** deployment from a manifest without `gmail.readonly`. `/usercallback` after **Connect with CReaM** does not need project sharing |
| **Se necesita autorización para realizar esta acción** / Authorization is required to perform that action | The running deployment still calls the Gmail API with `gmail.readonly`, which this add-on no longer requests | Deploy the version without that scope. Do not send the user to the script project |
| **not_connected** when creating/linking a deal | No OAuth or invalid token | **Connect with CReaM**; check the Script Properties |
| **not_connected** after a few hours (older add-on) | Expired access token cleared session on first API 401 | Deploy the latest add-on (`clasp push` + new deployment version); it refreshes automatically. Reconnect only if it persists |
| **not_connected** after connecting | Wrong `client_id` or redirect URI | Re-run `logCreamRedirectUri`, create the OAuth client again (§1.3) |
| **Code challenge is required** | Misconfigured PKCE | OAuth2 library v43; `generateCodeVerifier()` only when requesting the authorization URL |
| **Redirect URI mismatch** | URI other than `/usercallback` | Register exactly the URI from `logCreamRedirectUri` |
| Icon does not appear in Gmail | `gmail-addon-icon.png` not deployed | Deploy CReaM; verify `https://crm.example.com/gmail-addon-icon.png` |
| Add-on disappears after a new deployment | Installation points to another deployment | Update the existing deployment; do not create a new one |
| Marketplace SDK: "No host applications" | Web app-type deployment, not Add-on | Create an **Add-on**-type deployment |
| I do not see the app among private apps | Draft only, not published | Store Listing → **Publish** |
| On `mydomainapps`, missing from Admin → Apps list | Published, not installed for the organization | §3.3 Admin install. `mydomainapps` only proves the listing is published |
| Admin → Apps list is empty | Account lacks the Marketplace administrator privilege | Use an account with that privilege. Cloud project Owner is not enough |
| **Partially granted** after a scope change | New scope declared on the listing, not granted for the domain | §3.5 **Grant access**. Cloud Console cannot do this. This does not apply to `gmail.readonly`: the add-on does not request it, and granting it does not remove the Apps Script access page |
| Admin cannot find the app | Restrictive Marketplace policy | §3.2 Settings + admin install |
| Persistent **401** (after add-on refresh retry) | Revoked refresh token or wrong `api` scope | **Disconnect** → **Connect with CReaM**; check the OAuth client was created with `oauth:create_api_client` (§1.3), which gives it the `api` scope |

---

## Security

- Do not share `.clasprc.json` with personal tokens, OAuth keys, or `cream-backup.json`.
- The add-on `client_id` is public in the Script Properties; security relies on per-user OAuth.
- The add-on is **Private**: only `example.com` users can install it.
- Do not share the Apps Script project with users. Domain install grants the right to run the deployment, not to open the source.

---

## Quick URL reference

| Resource | URL |
|---------|-----|
| CReaM | https://crm.example.com |
| Add-on icon | https://crm.example.com/gmail-addon-icon.png |
| Create the OAuth client | `bin/rails "oauth:create_api_client[name,redirect_uri]"` on the server (§1.3) |
| Internal Marketplace apps | https://workspace.google.com/marketplace/mydomainapps |
| Enable Marketplace SDK | https://console.cloud.google.com/apis/library/appsmarket-component.googleapis.com |
| SDK configuration | https://console.cloud.google.com/apis/api/appsmarket-component.googleapis.com/googleapps_sdk |
