---
name: cream-marketing
description: >-
  Hub de marketing HubSpot-like en Cream CRM — consentimiento por tipo, campañas,
  segmentos, recorridos (journeys), puntuación de leads, tracking web y atribución
  UTM. Usar al añadir o modificar modelos/servicios/vistas de marketing, flags
  CreamFeatures, rutas públicas, webhooks Mailjet, jobs recurrentes o tests de
  marketing.
---

# Cream — Marketing hub

Hub de marketing conectado a captación (`lead_forms`), email (`record_email` / Mailjet), personas y deals. Arquitectura general del CRM: skill `cream-architecture`. Flags y roadmap: skill `cream-streak-roadmap`.

## Feature flags (`CreamFeatures`)

Ocho flags en [`app/services/cream_features.rb`](../../../app/services/cream_features.rb). `:mql_pool` está `enabled: true` (activado tras validación 2026-09-09).

| Flag | Menú | Etiqueta UI | Gating |
|------|------|-------------|--------|
| `:mql_pool` | sí | MQLs | `MqlsController`, intereses, conversión MQL→SQL, formularios destino MQL |
| `:marketing_consent` | sí | Suscripciones | `SubscriptionTypesController`, preferencias públicas |
| `:marketing_campaigns` | sí | Campañas | `CampaignsController`, ESP, webhooks |
| `:marketing_segments` | sí | Segmentos | `SegmentsController` |
| `:marketing_attribution` | sí | Atribución | `MarketingAttributionController` |
| `:journeys` | sí | Recorridos | `JourneysController`, `JourneyEnrollmentsController`, `JourneyRunnerJob` |
| `:lead_scoring` | sí | Puntuación de leads | `ScoringRulesController`, `ScoringRecalculateJob` |
| `:web_tracking` | no | Web tracking | `Public::TrackingController`, landing pages |

Iconos menú: `:mail`, `:users`, `:bar_chart`, `:zap` (ver `CreamFeatures.menu_icon`).

## Modelos

Workspace-scoped (`WorkspaceRecordPolicy`):

| Modelo | Rol |
|--------|-----|
| `MailjetConnection` | Credenciales ESP por workspace (API Key, Secret, remitente, webhook token, `transactional_enabled`) |
| `BeehiivConnection` | API Key de cuenta + `sync_enabled`; `has_many :beehiiv_publications` |
| `BeehiivPublication` | Mapeo `publication_id` + webhook token/secret + `subscription_type`; URL `/e/beehiiv/:token` por publicación |
| `SubscriptionType` | Tipos de suscripción; `consent_field_key` + `default_consent_label` enlazan checkbox de formulario ↔ suscripción |
| `EmailSubscription` | Estado por persona + tipo (`subscribed` / `unsubscribed` / `pending`) |
| `EmailSuppression` | Bloqueo global por email (bounce, spam, baja total) |
| `Campaign` | Campaña con variantes A/B, segmento, plantilla, estado |
| `CampaignVariant` | Variante A/B con peso y plantilla Liquid |
| `CampaignSend` | Envío concreto (`pending`, `scheduled`, `sending`, `sent`, `failed`, `cancelled`) |
| `Segment` | Filtros demográficos + comportamiento (`filters` jsonb) |
| `SegmentMembership` | Persona ↔ segmento |
| `Journey` | Recorrido con `entry_trigger`, `entry_config`, `max_reenrollments` |
| `JourneyStep` | Pasos ordenados (`STEP_TYPES` abajo) |
| `JourneyEnrollment` | Persona en recorrido (`active`, `waiting`, `completed`, `cancelled`) |
| `ScoringRule` | Regla con condiciones, puntos, `decay_days` |
| `EmailEvent` | Eventos ESP (open, click, bounce, unsub…) |
| `PageView` | Visitas web (tracking) |
| `Marketing::ProductInterest` | Interés por producto (`pending` / `converted` / `dismissed`); tabla `marketing_product_interests` |

**LeadForm** ampliado: `destination` (`deal` / `mql`), `subscription_type_id`, `marketing_consent_text`; `pipeline` opcional en MQL.

**LeadSubmission** ampliado: `deal` opcional, `capture_destination`, `submission_key` (idempotencia MQL), `privacy_policy_version_id`.

**PrivacyPolicyVersion** — snapshot inmutable de política + frase de consentimiento (`content_hash` SHA-256 por workspace). Captura en `Public::LeadFormsController#show` vía `Marketing::ConsentPolicySnapshot`; campo oculto `lead[privacy_policy_hash]`.

**Journey** ampliado: `product_id`, `stop_on_open_deal` (salida al abrir oportunidad del producto).

**Person** ampliada: `lifecycle_stage`, `lead_score`, `lead_score_decayed_at`; `has_many :email_subscriptions`, `:journey_enrollments`, `:segment_memberships`. Callback `enqueue_lifecycle_journey` → `Marketing::JourneyTrigger`.

**EmailMessage** ampliada: `campaign_variant_id`, `esp_message_id`; `has_many :email_events`.

Migraciones: `20260904100000_create_marketing_hub.rb`, `20260904110000_marketing_gap_closure.rb`, `20260904120000_marketing_improvements.rb`, `20260904140000_create_mailjet_connections.rb`, `20260904150000_add_transactional_enabled_to_mailjet_connections.rb`.

## Servicios (`app/services/marketing/`)

| Servicio | Responsabilidad |
|----------|-----------------|
| `SendGuard` | Comprueba supresión global + suscripción por tipo antes de enviar |
| `ConsentService` | Alta/baja por tipo; `unsubscribe_all!` desde preferencias |
| `PreferenceToken` | Token firmado para centro de preferencias / one-click unsub |
| `CampaignSender` | Envío masivo: dedupe emails, A/B Liquid (`EmailTemplate#render_custom_for`), errores ESP → `failed` |
| `Esp::Client` | Orquestador SMTP/Mailjet; usa `MailjetConnection` del workspace; `List-Unsubscribe` dinámico |
| `Esp::MailjetAdapter` | API Mailjet con credenciales del workspace; `esp_message_id`, pixel apertura |
| `Esp::SmtpAdapter` | Fallback dev (Mailbin) |
| `WebhookProcessor` | Mailjet webhook: supresión única, soft bounce no suprime, unsub → `ConsentService`, click → journey |
| `JourneyTrigger` | Entrada en recorridos; `entry_config` vacío = «cualquiera»; `enroll!(journey:, person:)` para inscripción manual acotada |
| `JourneyRunner` | Ejecuta pasos; `branch!` sin destino → completa enrollment; salta journeys/steps inactivos |
| `ScoringEngine` | Eventos, decay idempotente (`lead_score_decayed_at`), transición lifecycle por umbrales |
| `AttributionReport` | Dashboard UTM unificado; drill-down MQL (`MQL_STAGES` desde `ScoringEngine`) |
| `FilterResolver` / `ConditionEvaluator` | Filtros de segmentos y condiciones de scoring; claves MQL: `marketing_eligible`, `open_deal`, `interest_product_id`, `lead_form_id`, `capture_destination` |
| `MqlEligibility` | Elegibilidad del pool (≥1 suscripción activa subscribed + email principal + no suprimido; filtro opcional por tipo) |
| `Beehiiv::Client` / `SubscriberSync` / `PushService` / `WebhookProcessor` | Sync bidireccional por `BeehiivPublication` ↔ `subscription_type` mapeado |
| `MqlToSqlConverter` | Conversión transaccional de interés → deal (crear o vincular) |
| `JourneyExit` | Cancelar/bloquear recorridos con `stop_on_open_deal` |
| `JourneyStepMover` | Cambio manual de paso en inscripciones activas/en espera (admin) |
| `ConsentPolicySnapshot` | Versionar política + frase de checkbox por hash; find_or_create idempotente |
| `SegmentWatcher` | Detecta entrada en segmento → `JourneyTrigger.enqueue_segment_entry!` |
| `LiquidRenderer` / `LinkRewriter` | Personalización y tracking en campañas |

### Tipos de paso (`JourneyStep::STEP_TYPES`)

`send_email`, `wait`, `branch`, `set_field`, `add_to_segment`, `create_task`, `adjust_score`, `notify`

### Triggers de entrada (`Journey#entry_trigger`)

`lead_form_submitted`, `segment_entry`, `lifecycle_changed`, `email_clicked`, `booking_created`, `manual`

### Eventos de scoring (`ScoringRule` / `ScoringEngine`)

`email_opened`, `email_clicked`, `email_sent`, `page_view`, `lead_submission`, `booking_created`, `deal_created`, `form_field`

## Controladores y rutas

### Admin (requieren auth + `RequiresFeature`)

```
resources :subscription_types, except: :show
resources :campaigns do
  member do
    post :send_campaign, :send_test, :cancel_send, :mark_winner, :send_winner_rest
    get :recipient_count
  end
end
resources :segments { member { get :preview } }
resources :journeys { member { post :enroll; patch :toggle_active }; resources :enrollments, only: :update }
resources :scoring_rules, except: :show { collection { post :recalculate } }
resource :marketing_attribution, only: :show
```

`PeopleController#toggle_subscription` — gestión de suscripciones desde ficha persona.

### Público (sin auth)

| Ruta | Controlador | Notas |
|------|-------------|-------|
| `GET /p/:workspace_slug/:slug` | `Public::LandingPagesController#show` | Landing scope por tenant |
| `GET/PATCH /e/preferences/:token` | `Public::EmailPreferencesController` | Centro de preferencias |
| `GET/POST /e/unsubscribe/:token` | one-click unsub con `?type=` |
| `POST /e/events?token=` | `Public::EmailEventsController#create` | Webhook Mailjet; el token es el `webhook_token` de `MailjetConnection` |
| `POST /e/beehiiv/:token` | `Public::BeehiivWebhooksController#create` | Webhook Beehiiv (Svix); token de `BeehiivPublication` |
| `POST /t` | `Public::TrackingController#create` | Eventos tracking |
| `GET /cream.js` | script cross-origin | Snippet embebible |

**Importante:** landing pages usan `/p/:workspace_slug/:slug` (no `/p/:slug` solo). URL en admin: `LeadFormTemplates` partial `_form.html.erb`.

**Plantillas de captación:** Liquid vive en DB por workspace (admin **Formularios → Plantillas de formulario**). Checkboxes de marketing: tag `{% subscription_opt_in slug: "…" %}` o `lead[consent_field_key]` alineado con **Suscripciones**; opt-in masivo con `{% subscription_opt_in_all %}` → `lead[subscribe_all]` (suscribe todos los tipos activos vía `ConsentService`). No reimportar plantillas del repo en producción — respetar ediciones del usuario; documentar cambios manuales en plantilla cuando el código añada tags o claves nuevas.

## Jobs (`config/recurring.yml`)

| Job | Schedule | Entorno |
|-----|----------|---------|
| `JourneyRunnerJob` | cada 10 min | production + development |
| `ScoringRecalculateJob` | daily 3am | production + development |
| `MarketingDataRetentionJob` | daily 4am | production + development |
| `BeehiivSyncSchedulerJob` | cada hora | production + development |
| `CampaignSendJob` | on-demand (`wait_until`) | programación de campañas |

`MarketingDataRetentionJob` purga `PageView` y `EmailEvent` más antiguos que `MARKETING_DATA_RETENTION_DAYS` (default 180).

## UI y convenciones

- **`MarketingHelper`**: badges ES (`campaign_status_badge`, `send_status_badge`), labels de triggers/pasos/eventos, `describe_segment_filters`, `describe_step`.
- **Stimulus**: `journey_form_controller.js` (pasos dinámicos por tipo), `segment_preview_controller.js` (preview en vivo).
- **Patrón visual**: mismo que Alertas — `shared/_page_header`, `.card`, `.table-base`, empty states, confirm en acciones destructivas.
- **Ficha persona**: sección marketing (lifecycle, lead score, suscripciones, recorridos activos).

## Integraciones con el resto del CRM

| Origen | Hook marketing |
|--------|----------------|
| `LeadFormSubmissionProcessor` | `ConsentService.propagate_subscription_fields!` (por `SubscriptionType#consent_field_key`); `cream_aid` en metadata; journey `lead_form_submitted`; scoring `lead_submission` / `form_field` |
| `Person#enqueue_lifecycle_journey` | Journey `lifecycle_changed` |
| `WebhookProcessor` (click) | `JourneyTrigger.enqueue_email_clicked!` |
| `SegmentWatcher` | Journey `segment_entry` |
| `BookingCreator` | Journey `booking_created` (si persona vinculada) |
| `SendGuard` en journeys | `send_email!` respeta suscripción por `subscription_type_id` (default `general`) |

## Variables de entorno

| Variable | Uso |
|----------|-----|
| `CREAM_APP_URL` | Píxeles, links preferencias, tracking, URL de webhook Mailjet (obligatorio en prod) |
| `MARKETING_DATA_RETENTION_DAYS` | Retención page views / email events (default 180) |
| `SMTP_*` / `MAILER_FROM` | Fallback de instancia (Mailbin en dev). Campañas usan `MailjetConnection` si existe; transaccional solo si `transactional_enabled` |

Mailjet por workspace: **Settings** (admin) → `MailjetConnection` (`api_key`, `secret_key`, `from_email`, `from_name`, `webhook_token`, `transactional_enabled`). URL webhook: `https://<host>/e/events?token=<webhook_token>`.

Beehiiv por workspace: **Settings** (admin) → `BeehiivConnection` (`api_key`, `sync_enabled`) + N `BeehiivPublication` (`publication_id`, `webhook_signing_secret`, `subscription_type_id`, `webhook_token` único). URL webhook por publicación: `https://<host>/e/beehiiv/<webhook_token>`. Migración `20260910120000` backfill preserva token/URL de newsletter en prod. Push outbound desde `ConsentService` (por `subscription_type` mapeado) vía `BeehiivPushJob`; inbound no reempuja (`source` `beehiiv:*`).

## Tests

```
spec/services/marketing/*           # servicios (mock HTTP)
spec/requests/marketing_admin_spec.rb
spec/requests/public/email_preferences_spec.rb
spec/requests/public/landing_pages_spec.rb
spec/requests/public/tracking_spec.rb
spec/requests/public/email_events_spec.rb
```

Convenciones del proyecto:

- Mock `Net::HTTP` / adaptadores ESP — no llamar Mailjet real.
- `ActiveJob::Base.queue_adapter = :test` para `CampaignSendJob`, `JourneyRunnerJob`, etc.
- Suite marketing completa: `bundle exec rspec spec/services/marketing spec/requests/marketing_admin_spec.rb spec/requests/public/email_preferences_spec.rb spec/requests/public/landing_pages_spec.rb spec/requests/public/tracking_spec.rb spec/requests/public/email_events_spec.rb`

## Manual de usuario

Documentación visible: **MANUAL_USUARIO.md §29** y **USER_MANUAL.md §29** (Marketing). Actualizar vía skill `cream-user-manual` al cambiar UX.

## Verificación browser

Smoke tests con `cream-playwright` — sección «Verificar marketing hub».

## Finishing a change

1. Flags en `cream_features.rb` + fila en `TRACKING.md`
2. Specs (servicios + requests); rubocop
3. Manual §29 si cambió UX
4. `bin/rails db:migrate` en dev/prod al añadir columnas
5. Prod: cada workspace configura Mailjet en **Settings**; registrar en Mailjet la URL de webhook que muestra esa pantalla.
