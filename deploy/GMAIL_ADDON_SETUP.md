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

The `scriptId` is in [`gmail_addon/.clasp.json`](../gmail_addon/.clasp.json).

### 1.2. OAuth callback URI

The add-on uses the `apps-script-oauth2` library (v43 in `appsscript.json`). The
callback is **`/usercallback`**, not a Web app (`/exec`).

In Apps Script run **`logCreamRedirectUri`** and copy the URI:

```
https://script.google.com/macros/d/TU_SCRIPT_ID/usercallback
```

### 1.3. Register the OAuth client in CReaM

```bash
curl -X POST "https://crm.example.com/oauth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "client_name": "CReaM Gmail add-on",
    "scope": "api",
    "redirect_uris": [
      "https://script.google.com/macros/d/TU_SCRIPT_ID/usercallback"
    ]
  }'
```

Save the returned **`client_id`**. A single client works for the whole organization.

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
5. **Data Access**: scopes from the manifest. `gmail.addons.current.message.readonly` is what lets the add-on read the other messages in the open thread. `gmail.readonly` is also required so calendar messages and `.ics` files can be loaded through the Gmail API.

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

**Icons** (generated from the Cream design system):

```bash
bundle exec ruby script/fetch_design_system_icons.rb
```

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

### 3.1. Allow internal Marketplace apps

Google Admin Console → **Apps → Google Workspace Marketplace apps → Settings**

Enable (depending on your organization's policy):

- **Allow users to install and run any internal app from Marketplace**

If the organization uses an **allowlist**, add CReaM to the allowed list or install it
as an administrator (§3.2).

### 3.2. Install for the whole domain (recommended)

Google Admin Console → **Apps → Google Workspace Marketplace apps → Apps list**

1. **Install app**
2. Search for **CReaM** or open the published listing URL
3. **Admin install** → choose **the whole organization**, an **OU** or **groups**
4. Accept the permissions

Alternative for users: open

```
https://workspace.google.com/marketplace/mydomainapps
```

(signed in with `@example.com`) and install CReaM.

### 3.3. Verify it is available

| Where | What to expect |
|-------|-------------|
| Store Listing (GCP) | Status **published** + listing URL |
| `mydomainapps` | CReaM listed as an internal app |
| Admin → Apps list | CReaM among the domain's installed apps (after admin install) |
| Gmail → open thread | CReaM icon in the right sidebar |

If the listing is in draft but not published, it **will not appear** anywhere.

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

If you change the Script ID or the `/usercallback` URI, register a new OAuth client
(§1.3) and update `CREAM_CLIENT_ID`.

---

## Common problems

| Symptom | Likely cause | Solution |
|---------|----------------|----------|
| **Se necesita autorización para realizar esta acción** / Authorization is required to perform that action | The user has not granted `gmail.readonly` (added so the add-on can load the full thread and calendar invites). Apps Script then aborts instead of showing a consent dialog | Deploy the version that shows **Authorize** before any Gmail API call. The user opens CReaM, clicks **Authorize** and accepts the prompt. Confirm `gmail.readonly` is on Google Auth Platform → Data Access. After an admin install, the admin must accept the new permission |
| **not_connected** when creating/linking a deal | No OAuth or invalid token | **Connect with CReaM**; check the Script Properties |
| **not_connected** after a few hours (older add-on) | Expired access token cleared session on first API 401 | Deploy the latest add-on (`clasp push` + new deployment version); it refreshes automatically. Reconnect only if it persists |
| **not_connected** after connecting | Wrong `client_id` or redirect URI | Re-run `logCreamRedirectUri`, register OAuth again |
| **Code challenge is required** | Misconfigured PKCE | OAuth2 library v43; `generateCodeVerifier()` only when requesting the authorization URL |
| **Redirect URI mismatch** | URI other than `/usercallback` | Register exactly the URI from `logCreamRedirectUri` |
| Icon does not appear in Gmail | `gmail-addon-icon.png` not deployed | Deploy CReaM; verify `https://crm.example.com/gmail-addon-icon.png` |
| Add-on disappears after a new deployment | Installation points to another deployment | Update the existing deployment; do not create a new one |
| Marketplace SDK: "No host applications" | Web app-type deployment, not Add-on | Create an **Add-on**-type deployment |
| I do not see the app among private apps | Draft only, not published | Store Listing → **Publish** |
| Admin cannot find the app | Restrictive Marketplace policy | §3.1 Settings + admin install |
| Persistent **401** (after add-on refresh retry) | Revoked refresh token or wrong `api` scope | **Disconnect** → **Connect with CReaM**; check OAuth registration with `"scope": "api"` |

---

## Security

- Do not share `.clasprc.json` with personal tokens, OAuth keys, or `cream-backup.json`.
- The add-on `client_id` is public in the Script Properties; security relies on per-user OAuth.
- The add-on is **Private**: only `example.com` users can install it.

---

## Quick URL reference

| Resource | URL |
|---------|-----|
| CReaM | https://crm.example.com |
| Add-on icon | https://crm.example.com/gmail-addon-icon.png |
| Register OAuth | `POST https://crm.example.com/oauth/register` |
| Internal Marketplace apps | https://workspace.google.com/marketplace/mydomainapps |
| Enable Marketplace SDK | https://console.cloud.google.com/apis/library/appsmarket-component.googleapis.com |
| SDK configuration | https://console.cloud.google.com/apis/api/appsmarket-component.googleapis.com/googleapps_sdk |
