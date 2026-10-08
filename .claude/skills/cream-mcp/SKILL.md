---
name: cream-mcp
description: >-
  Servidor MCP de Cream CRM — transporte HTTP, OAuth/PKCE, herramientas IA y
  convenciones en CreamMcp. Usar al añadir o modificar tools MCP, auth OAuth
  para clientes LLM, o depurar POST /mcp. No confundir con REST API v1 (skill
  cream-api). Skill de uso para agentes: [skills/cream/](../../../skills/cream/SKILL.md) (no está en `.claude/skills/`).
---

# Cream — MCP server

Expone el CRM a clientes IA (Claude Desktop, Cursor, inspector MCP, etc.) vía **Model Context Protocol**. No duplicar el modelo de dominio — ver skill `cream-architecture`. Para integraciones REST clásicas, ver skill **`cream-api`**.

## Transporte y rutas

| Ruta | Método | Uso |
|------|--------|-----|
| `/mcp` | `POST` | Único endpoint MCP (Streamable HTTP, stateless, JSON-RPC) |
| `/mcp` | `GET`, `DELETE` | `405 Method Not Allowed` |

Implementación:

- Controlador: [`McpController`](../../../app/controllers/mcp_controller.rb) — `MCP::Server::Transports::StreamableHTTPTransport`
- Servidor y tools: [`CreamMcp`](../../../app/mcp/cream_mcp.rb) + marketing en [`cream_mcp/marketing.rb`](../../../app/mcp/cream_mcp/marketing.rb) — `CreamMcp.server_for(user:, workspace:)`
- Gema: `mcp` (~> 1.1)

Hosts permitidos en el transport: `CREAM_APP_URL` y `CREAM_DOMAIN` (evita host header injection).

## Autenticación

Bearer token en `Authorization` (mismo modelo `ApiToken` que REST, flujo OAuth distinto):

| Token | Scope / binding | Workspace |
|-------|-----------------|-----------|
| `cream_…` | `ApiToken` del usuario | Fijado en el token |
| OAuth Doorkeeper | Scope **`mcp`** (no `api`) | `user.default_workspace` |

Sin token → `401` + header `WWW-Authenticate` con enlace a metadata OAuth (RFC 9728).

**Diferencia con REST API v1:** OAuth MCP no soporta `X-Cream-Workspace-Id`; OAuth REST usa scope `api`. Son dos scopes en el mismo Doorkeeper (`default_scopes :mcp`, `optional_scopes :api`).

Tokens de API se crean en la web (`/api_tokens`) — ver skill `cream-architecture` (sección API tokens).

## OAuth para clientes MCP

Metadata (público):

- `GET /.well-known/oauth-authorization-server` — RFC 8414
- `GET /.well-known/oauth-protected-resource` — RFC 9728 (recurso = URL de `/mcp`)

Registro dinámico de clientes (RFC 7591):

- `POST /oauth/register` — clientes **públicos**, PKCE obligatorio, scopes `mcp` o `api`

Flujo: registro → authorization code + PKCE → token con scope `mcp` → `POST /mcp`.

Config Doorkeeper: [`config/initializers/doorkeeper.rb`](../../../config/initializers/doorkeeper.rb) — `force_pkce`, sin client secret, refresh tokens, consent en layout Cream.

## Herramientas (tools)

Lista canónica: `CreamMcp.tools` en [`cream_mcp.rb`](../../../app/mcp/cream_mcp.rb) (CRM + IA) y `CreamMcp::Marketing.tools` en [`cream_mcp/marketing.rb`](../../../app/mcp/cream_mcp/marketing.rb). CRM: CRUD/listados, pipeline, **condiciones de etapa** (`list_stage_conditions`, `create_stage_condition`, `update_stage_condition`, `delete_stage_condition`; flag `:stage_conditions`), productos, notas (`add_note`; campo `internal_notes` en personas), adjuntos de persona (`add_person_attachment`), propuestas de deal (`add_deal_offer`: crea la oferta o añade una nueva versión si ya existe; servicio `Api::DealOfferUploader`), comentarios, tareas, emails, pagos Stripe, duplicados/merge, custom fields, historial de deals, tools IA (`summarize_record`, `natural_language_search`, etc.). Marketing (flags `CreamFeatures`): `list_mqls`, `get_person_marketing`, `list_product_interests`, `list_subscription_types`, `list_subscriptions`, `list_campaigns`/`get_campaign`, `list_segments`/`get_segment`, `list_journeys`/`get_journey`, `list_scoring_rules`, `get_attribution`, `list_email_templates`, `list_lead_forms`; acciones `create_mql` (alta directa de MQL con notas y adjuntos), `create_product_interest`, `convert_mql_to_sql`, `set_subscription`, `enroll_in_journey`, `send_campaign`, `cancel_campaign_send`. Sin credenciales ESP ni CRUD de configuración.

Cada tool:

1. Se define con `MCP::Tool.define(name:, description:, input_schema:, ...)`
2. Envuelve la lógica en `CreamMcp.with_authorization(server_context) { ... }`
3. Usa `CreamMcp.authorize!` / `policy_scope` (Pundit, mismo `UserContext` que la web)
4. Responde con `CreamMcp.respond_with(payload)` → JSON en texto

Side effects de dominio importantes:

- Cambio de etapa → `deal.move_to_stage!` (actividades, webhooks, stage triggers)
- Crear deal → requiere `next_action_title` + `next_action_due_on` en el tool `create_deal`
- URLs en respuestas → `CreamMcp.record_url` (necesita `CREAM_APP_URL`)

Tools IA (`summarize_record`, `suggest_next_steps`, `draft_email`, `natural_language_search`, `enrich_record`) requieren `:ai_assistant` + `CREAM_AI_API_KEY` (`CreamMcp.ai_assistant_enabled?`); si no, respuesta `ai_unavailable`.

## Añadir o cambiar una tool MCP

1. Definir la tool en [`app/mcp/cream_mcp.rb`](../../../app/mcp/cream_mcp.rb) o [`app/mcp/cream_mcp/marketing.rb`](../../../app/mcp/cream_mcp/marketing.rb) (schema + bloque). Usar prefijo `::Marketing::` para servicios/modelos del hub (evitar colisión con `CreamMcp::Marketing`).
2. Registrar el nombre en `CreamMcp.tools` o `CreamMcp::Marketing.tools`.
3. Actualizar `instructions` en `server_for` si cambia el routing guidance para el LLM.
4. Añadir cobertura en [`spec/requests/mcp_spec.rb`](../../../spec/requests/mcp_spec.rb) o [`spec/requests/mcp_marketing_spec.rb`](../../../spec/requests/mcp_marketing_spec.rb) — auth con `ApiToken`, helpers en [`spec/support/mcp_helpers.rb`](../../../spec/support/mcp_helpers.rb); **mockear HTTP externo y jobs**, nunca llamadas reales a APIs de terceros.
5. Si la tool duplica comportamiento REST, mantener paridad de reglas de negocio (p. ej. `move_to_stage!`, validaciones de deal).

No documentar MCP en [`docs/openapi.yaml`](../../../docs/openapi.yaml) — protocolo distinto (JSON-RPC sobre `/mcp`, no OpenAPI REST).

## Tests

- Spec principal: [`spec/requests/mcp_spec.rb`](../../../spec/requests/mcp_spec.rb); marketing: [`spec/requests/mcp_marketing_spec.rb`](../../../spec/requests/mcp_marketing_spec.rb)
- Helpers: [`spec/support/mcp_helpers.rb`](../../../spec/support/mcp_helpers.rb) — `initialize_payload`, `tools_list_payload`, `call_tool(name, args)` con header Bearer
- OAuth MCP: specs en [`oauth_authorization_spec.rb`](../../../spec/requests/oauth_authorization_spec.rb), [`oauth_registrations_spec.rb`](../../../spec/requests/oauth_registrations_spec.rb), [`well_known_spec.rb`](../../../spec/requests/well_known_spec.rb)

## Antes de cerrar un cambio MCP

1. Tool registrada + Pundit correcto + workspace scope.
2. Spec en `mcp_spec.rb` (y specs OAuth si tocas metadata/registro).
3. Sin secretos en logs ni en respuestas de tools.
