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
| People | CRUD | `?q=` búsqueda; nested `person_emails_attributes`; `internal_notes` (texto libre) |
| Person attachments | `POST /people/:person_id/attachments` | `{ attachment: { filename, content (Base64), content_type?, name? } }` o multipart `attachment[file]`; requiere `:attachments` |
| Companies | CRUD | `?q=` búsqueda |
| Deals | CRUD | `?q=`; stage change vía `move_to_stage!`; create acepta `notes[]`, `email` (Base64 o multipart) y `tasks_attributes` |
| Deal notes | `POST /deals/:deal_id/notes` | `{ note: { title, body } }` |
| Deal emails | `POST /deals/:deal_id/emails` | `{ email: { to_address?, subject, body, attachments[] } }` — JSON (Base64) o `multipart/form-data` (`email[attachments][]`); Gmail si hay conexión, si no SMTP |
| Tasks | CRUD + `POST /tasks/:id/complete_and_replace` | `taskable_type`/`taskable_id`; `completed` dispara side effects; complete_and_replace exige `{ next_task: { title, due_on } }` y es transaccional (Gmail add-on) |
| Gmail add-on | `GET gmail/context`, `POST gmail/threads/status`, `POST gmail/threads/link` | Requiere `:gmail_addon`. La instalación en la organización de Google Workspace está más abajo |
| Marketing | Ver tabla abajo | Paridad operativa con MCP marketing (lectura + acciones clave); presenter en [`api_presenter.rb`](../../../app/services/marketing/api_presenter.rb) |

### Marketing (`/api/v1/marketing/…` y rutas anidadas en people)

| Recurso | Rutas | Flag / permisos |
|---------|-------|-----------------|
| MQL pool | `GET marketing/mqls` | `:mql_pool`, miembro |
| Alta de MQL | `POST marketing/mqls` | `:mql_pool` + `:marketing_consent`, miembro. `{ mql: { email, company_id\|company_name, first_name, …, internal_notes, product_id, interest_description }, subscriptions: [{ subscription_type_id, consent_text, consent_source, consent_obtained_at?, consent_ip? }] (≥1, obligatorio; cada entrada es el consentimiento de ese tipo y guarda su evidencia), notes: [{title, body}], attachments: [...] }` (JSON Base64 o multipart). Transaccional; find-or-create por email (201 / 200); pasa a `mql` sin degradar; servicio [`Marketing::MqlCreator`](../../../app/services/marketing/mql_creator.rb) compartido con MCP `create_mql` |
| Persona marketing | `GET people/:id/marketing` | `PersonPolicy#show?` |
| Suscripción | `PATCH people/:id/subscription` | `:marketing_consent`, `PersonPolicy#update?`. `{ subscription: { subscription_type_id, action: subscribe\|unsubscribe, consent_text, consent_source, consent_obtained_at?, consent_ip? } }`; para `subscribe` la evidencia (`consent_text`, `consent_source`) es obligatoria (422 si falta); una suscripción activa conserva su evidencia original; validación compartida con MCP/MQL en [`Marketing::ConsentEvidence`](../../../app/services/marketing/consent_evidence.rb) |
| Intereses | `GET/POST people/:person_id/product_interests` | `:mql_pool` |
| Conversión MQL→SQL | `POST marketing/mql_conversions` | `:mql_pool`, `ProductInterestPolicy#convert?` |
| Tipos suscripción | `GET marketing/subscription_types` | `:marketing_consent`, admin |
| Suscripciones | `GET marketing/subscriptions` | `:marketing_consent`, miembro. Filtros `subscription_type_id`, `status` (`subscribed\|unsubscribed\|pending`, 422 si no es válido), `person_id`, `limit`; incluye `person` y `consent_evidence`; solo personas visibles para el usuario; MCP `list_subscriptions` |
| Campañas | `GET marketing/campaigns`, `GET marketing/campaigns/:id` | `:marketing_campaigns`, admin |
| Envíos campaña | `POST marketing/campaigns/:id/sends`, `POST …/sends/:id/cancel` | admin; encola `CampaignSendJob` |
| Segmentos | `GET marketing/segments`, `GET marketing/segments/:id` | `:marketing_segments`, admin |
| Recorridos | `GET marketing/journeys`, `GET marketing/journeys/:id`, `POST …/enroll` | `:journeys`, admin |
| Scoring | `GET marketing/scoring_rules` | `:lead_scoring`, admin |
| Atribución | `GET marketing/attribution` | `:marketing_attribution`, admin |
| Plantillas / formularios | `GET marketing/email_templates`, `GET marketing/lead_forms` | `:email_templates` / ninguno |

Fuera de este API (ver skill **`cream-mcp`** para `/mcp` y OAuth scope `mcp`): booking público, metadata OAuth compartida.

## Add-on de Gmail — instalación en la organización

El código está en [`gmail_addon/`](../../../gmail_addon/). La guía larga es [`deploy/GMAIL_ADDON_SETUP.md`](../../../deploy/GMAIL_ADDON_SETUP.md). Publicar la ficha privada del Marketplace e instalarla para la organización son pasos distintos. El mismo procedimiento está en el README y en la skill `cream-dev`.

El propietario del proyecto de Cloud puede publicar la ficha. Solo un **administrador de Marketplace** de Google Workspace puede instalarla para el dominio. Ese privilegio no es el de superadministrador ni el de propietario del proyecto de Cloud.

### Dónde aparece

| Sitio | Significado |
|-------|-------------|
| [mydomainapps](https://workspace.google.com/marketplace/mydomainapps) | La ficha privada está **publicada**. La gente del dominio puede instalarla por su cuenta. No significa que un administrador la haya instalado para la organización. |
| Consola de administración → **Aplicaciones → Aplicaciones de Google Workspace Marketplace → Lista de aplicaciones** | Apps que un administrador **instaló para la organización** o **permitió**. Si CReaM no está, no hay instalación de dominio. Sin el privilegio de administrador de Marketplace la lista sale vacía. |

Un **despliegue de prueba** (Apps Script → Implementar → Implementaciones de prueba) no sale en ninguna de las dos. Solo lo ejecuta el propietario del script. Cualquier otra cuenta ve **Necesitas acceso** con **Lector** / **Editor**. Esa página es el uso compartido del archivo del proyecto, no el consentimiento de Gmail. No hay que aprobarla ni compartir el proyecto. Lector puede leer el código. Editor puede cambiar el código y las propiedades del script (`CREAM_CLIENT_ID`).

### Instalar para el dominio

1. Entra con una cuenta de administrador de Marketplace.
2. Abre [mydomainapps](https://workspace.google.com/marketplace/mydomainapps), o Consola de administración → **Aplicaciones → Aplicaciones de Google Workspace Marketplace → Lista de aplicaciones** → **Instalar aplicación**.
3. Abre **CReaM** → **Instalación de administrador** → toda la organización, una OU o grupos.
4. Acepta los permisos.

Si la política bloquea las apps internas: Consola de administración → **Aplicaciones → Aplicaciones de Google Workspace Marketplace → Configuración** → permitir apps internas, o añade CReaM a la lista de permitidas.

CReaM pasa a **Aplicaciones instaladas en el dominio**. Cada persona sigue pulsando **Connect with CReaM** una vez. La instalación de la organización no sustituye ese OAuth con Cream. Instalarla cada usuario desde `mydomainapps` es una instalación individual y no crea el botón de dominio **Conceder acceso**.

### Scopes

| Scope | Qué cubre |
|-------|-----------|
| `gmail.addons.execute` | Ejecutar el addon |
| `gmail.addons.current.message.readonly` | El mensaje abierto y el resto de mensajes de **ese mismo hilo** de Gmail |
| `script.external_request` | Llamar al API de Cream |

El manifiesto no pide `gmail.readonly`. La instalación de dominio no comparte el proyecto de Apps Script. Pedir ese scope abre el archivo del proyecto (`getAuthorizationUrl()`), así que los usuarios siguen viendo **Necesitas acceso** (Lector/Editor) después de instalarlo para la organización. No compartas el proyecto. Con el hilo abierto basta para vincular o crear el deal.

Si una versión posterior añade otro scope OAuth, Google no avisa al administrador. **Acceso a los datos** pasa a **Concedido parcialmente** y se concede en la consola de administración ([gestionar el acceso a los datos](https://support.google.com/a/answer/172983)). Cloud no puede hacerlo, y esa concesión tampoco da acceso al archivo del script. Hay que publicar una versión nueva de la **misma** implementación. Hasta entonces Gmail sigue ejecutando el script antiguo, que abre la página de acceso de Apps Script.

## Crear deals por API

Validación de dominio: al crear un deal hace falta al menos una tarea con `due_on` hoy o posterior (`tasks_attributes` en el payload del deal). Notas opcionales en el mismo request (`notes` a nivel raíz) — transaccional con el deal. Email opcional (`email` a nivel raíz, misma forma que `POST /deals/:id/emails`, adjuntos Base64 en JSON o ficheros binarios en `multipart/form-data`) — transaccional; la entrega se encola tras el commit. Requiere `:record_email` si se envía `email`.

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
