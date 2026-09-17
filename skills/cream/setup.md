# Cream MCP — agent setup

Use this when **Cream MCP tools are not available** in the agent session (no `list_deals`, `search_records`, etc.).

## Prerequisites

- A running Cream instance (production URL or local `http://localhost:3030`).
- A user account with access to the target workspace.

## 1. Create an API token

1. Sign in to Cream.
2. Open **My profile → API tokens** in the sidebar.
3. Enter a name (e.g. `Cursor agent`).
4. Click **Create token**.
5. Copy the value immediately — it starts with `cream_` and is shown **once**.

The token is tied to **your user** and the **workspace active** when you created it. To use another workspace, switch context in the app (if applicable) and create a new token.

Revoke leaked tokens from the same screen (trash icon).

## 2. MCP endpoint

```
https://YOUR-DOMAIN/mcp
```

Local development:

```
http://localhost:3030/mcp
```

## 3. Cursor configuration

User file `~/.cursor/mcp.json` or project `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "cream": {
      "url": "https://YOUR-DOMAIN/mcp",
      "headers": {
        "Authorization": "Bearer cream_YOUR_TOKEN"
      }
    }
  }
}
```

Replace the URL and token. Reload MCP servers or restart Cursor.

## 4. OAuth alternative (no pasted token)

Some clients accept only the MCP URL. Opening `https://YOUR-DOMAIN/mcp` triggers sign-in and OAuth with scope **`mcp`**. Workspace is the user’s **default workspace** (OAuth MCP does not support `X-Cream-Workspace-Id`).

Metadata (public):

- `GET /.well-known/oauth-authorization-server`
- `GET /.well-known/oauth-protected-resource`

## 5. Verify connection

After configuration, the client should list Cream tools (40+ CRM + marketing). Call `list_pipelines` or `search_records` with a trivial query to confirm auth.

## Security

- Treat `cream_…` like a password — same permissions as you in that workspace.
- Do not commit tokens to git or paste into public chats.
- Prefer env-specific tokens per agent/machine.

## AI tools note

Tools `summarize_record`, `suggest_next_steps`, `draft_email`, `natural_language_search`, and `enrich_record` require the workspace **AI assistant** enabled and `CREAM_AI_API_KEY` on the server. Other tools work without AI.
