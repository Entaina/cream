---
name: cream-api
description: >-
  REST API v1 de Cream CRM — auth, convenciones de controladores, OpenAPI y
  tests. Usar al añadir o modificar endpoints en app/controllers/api/v1/,
  documentar el API, o integrar clientes externos (tokens, OAuth, Gmail add-on).
---

# Cream — REST API v1

Documentación para **desarrolladores e integraciones**. No duplicar aquí el modelo de dominio — ver skill `cream-architecture`.

## Contrato OpenAPI

- Spec: [`docs/openapi.yaml`](../../../docs/openapi.yaml)
- YAML en vivo: `/api/openapi.yaml`
- Swagger UI (público, dev y producción): `/api/docs`
- **When adding or changing endpoints in `app/controllers/api/v1/`, update `docs/openapi.yaml` in the same PR.**

## Autenticación y workspace

`Api::V1::BaseController` (`ActionController::API` + Pundit + `requires_feature :api_v1`):

| Método | Uso |
|--------|-----|
| Bearer `cream_…` | Token creado en la web (`ApiToken`). Workspace fijado en el token. |
| Bearer OAuth | Doorkeeper, scope `api`. Usuario puede acceder a varios workspaces. |
| Header `X-Cream-Workspace-Id` | Solo relevante con OAuth: selecciona workspace; si falta, `default_workspace`. Con API token se ignora (403 si no coincide). |

Errores habituales: `401` sin token, `403` workspace no permitido, `404` recurso fuera del workspace o feature deshabilitada (`RequiresFeature` devuelve JSON en API).

## Convenciones de controlador

Seguir el patrón de [`PeopleController`](../../../app/controllers/api/v1/people_controller.rb) / [`TasksController`](../../../app/controllers/api/v1/tasks_controller.rb):

1. `policy_scope(current_workspace.<recurso>)` en list/show/update/destroy.
2. `authorize` en mutaciones.
3. Strong params con `params.require(:modelo).permit(...)`.
4. JSON con método privado `*_json` (hash manual, fechas ISO8601).
5. Errores: `{ errors: [...].full_messages }` → 422; destroy → `204 No Content`.
6. Asociaciones polimórficas: whitelist `Company|Person|Deal` + `policy_scope` al resolver parent.
7. Feature flags extra: `requires_feature :record_email`, `:gmail_addon`, etc. (hereda fix API de `RequiresFeature`).

## Endpoints actuales

Namespace `config/routes.rb` → `namespace :api > :v1`:

| Recurso | Rutas | Notas |
|---------|-------|-------|
| People | CRUD | `?q=` búsqueda; nested `person_emails_attributes` |
| Companies | CRUD | `?q=` búsqueda |
| Deals | CRUD | `?q=`; stage change vía `move_to_stage!`; create acepta `notes[]` y `tasks_attributes` |
| Deal notes | `POST /deals/:deal_id/notes` | `{ note: { title, body } }` |
| Deal emails | `POST /deals/:deal_id/emails` | `{ email: { to_address?, subject, body } }`; Gmail si hay conexión, si no SMTP |
| Tasks | CRUD | `taskable_type`/`taskable_id`; `completed` dispara side effects |
| Gmail add-on | `GET gmail/context`, `POST gmail/threads/status`, `POST gmail/threads/link` | Requiere `:gmail_addon` |

Fuera de este API (ver skill **`cream-mcp`** para `/mcp` y OAuth scope `mcp`): booking público, metadata OAuth compartida.

## Crear deals por API

Validación de dominio: al crear un deal hace falta al menos una tarea con `due_on` hoy o posterior (`tasks_attributes` en el payload del deal). Notas opcionales en el mismo request (`notes` a nivel raíz) — transaccional con el deal.

## Emails desde deals

Reutilizar la misma rama que [`RecordEmailsController`](../../../app/controllers/record_emails_controller.rb):

- `message.route_via_gmail?` → `SendViaGmailJob.perform_later`
- si no → `RecordMailer.tracked_email.deliver_later` + `track_sent!`

No llamadas HTTP reales a Gmail en tests — mockear jobs y mailer.

## Tests

- Request specs en `spec/requests/api/v1/`.
- Auth de referencia: `user.api_tokens.create!(name: "Test", workspace: workspace)` + header `Authorization: Bearer #{token.plaintext_token}`.
- Patrones OAuth: ver [`gmail_threads_spec.rb`](../../../spec/requests/api/v1/gmail_threads_spec.rb).
- Docs: [`spec/requests/api/docs_spec.rb`](../../../spec/requests/api/docs_spec.rb).

## Antes de cerrar un cambio de API

1. Controlador + rutas + spec de request.
2. Actualizar [`docs/openapi.yaml`](../../../docs/openapi.yaml) (paths, schemas, ejemplos si aplica).
3. `bundle exec rspec spec/requests/api/v1/` (y `spec/requests/api/docs_spec.rb` si tocas docs).
