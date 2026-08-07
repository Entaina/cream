---
description: Crear un formulario público de captación de leads operativo (Liquid, email, seed, specs)
argument-hint: "slug nombre [pipeline] — describe campos extra en el mensaje si hace falta"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskQuestion
---

Crea un **formulario público de leads** completo y operativo en Cream. El usuario invoca
`/nuevo-formulario-lead` con el slug, nombre y descripción de campos; tú implementas todo
lo necesario siguiendo los patrones actuales (**Liquid en BD**, sin ERB público).

## Antes de codear: recoger especificación

Si `$ARGUMENTS` o el mensaje del usuario no bastan, pregunta hasta tener:

| Dato | Ejemplo |
|------|---------|
| **slug** (URL `/f/slug`) | `liderando-ia` |
| **name** (título visible) | `Liderando con IA` |
| **template_key** | igual que nombre corto: `liderando_ia` |
| **pipeline por defecto** | `Proyectos` (nombre en workspace Example) |
| **pipeline_routes** | solo si hay desplegable `help_type` (como contacto) |
| **collects_company** | sí/no |
| **product_id** | opcional; obligatorio lógico en formularios de reserva con edición |
| **Campos extra** | tipo, label, `name`, `required`, `options` si select |
| **Email al lead** | key, name, subject, body (`{first_name}`, `{name}`, `{email}`) |
| **Responsable** | por defecto: admin del workspace en seed |

Campos **reutilizables** vía parciales Liquid (`lib/lead_form_templates/public/lead_forms/partials/`):

- `contact_fields` — nombre, apellidos, email, teléfono (todos `required: true` en HTML)
- `contact_fields_with_prefix` — igual + teléfono con prefijo de país
- `how_heard_field`, `newsletter_opt_in`, `consent_fields`

Tags de sistema en cada **página** (no en parciales):

```liquid
{% form_open %}
{% hidden_fields %}
{% honeypot %}
…campos…
{% turnstile %}
{% submit 'Enviar' %}
{% form_close %}
```

## Archivos a crear o tocar

### 1. Plantilla Liquid (página)

`lib/lead_form_templates/public/lead_forms/<template_key>.liquid`

Patrones de referencia:

- [`contacto.liquid`](lib/lead_form_templates/public/lead_forms/contacto.liquid) — `help_type` + `message`
- [`curso.liquid`](lib/lead_form_templates/public/lead_forms/curso.liquid) — `qualifying_answer`
- [`liderando_ia_reserva.liquid`](lib/lead_form_templates/public/lead_forms/liderando_ia_reserva.liquid) — `open_editions` + `contact_fields_with_prefix`

Ejemplo mínimo:

```liquid
<div class="mx-auto max-w-xl">
  <h1 class="font-display text-2xl font-semibold mb-4">{{ lead_form.name }}</h1>
  {% form_open %}
  {% hidden_fields %}
  {% honeypot %}

  <div class="space-y-4">
    {% partial 'contact_fields' %}
    {% field type: "textarea", name: "message", label: "Mensaje", placeholder: "Opcional" %}
    {% partial 'how_heard_field' %}
    {% partial 'newsletter_opt_in' %}
    {% partial 'consent_fields' %}
  </div>

  {% turnstile %}
  {% submit 'Enviar' %}
  {% form_close %}
</div>
```

Select con catálogo existente: `{% field type: "select", name: "help_type", options: "contacto_help", blank: "Selecciona", required: true %}`.

Select con catálogo nuevo: añade constante en [`LeadForm`](app/models/lead_form.rb) + entrada en [`FieldRenderer::OPTION_SETS`](app/services/lead_form_templates/field_renderer.rb).

### 2. Importar plantillas al workspace

Tras crear/editar ficheros en `lib/lead_form_templates/`:

```bash
bin/rails 'lead_form_templates:import[WORKSPACE_ID]'
```

En dev (workspace Example): usar el id del workspace tras seed. Los specs usan `spec/support/public_lead_form_templates.rb`.

**No** añadir fallback filesystem en runtime — solo BD.

### 3. Strong params y campos reservados

Si el formulario usa campos **nuevos** (no en la whitelist):

1. Añadir a `LeadForm::SUBMISSION_FIELD_KEYS` en [`app/models/lead_form.rb`](app/models/lead_form.rb)
2. Añadir a [`Public::LeadFormsController#lead_params`](app/controllers/public/lead_forms_controller.rb)

`help_type` y rutas de pipeline ya están soportados (`pipeline_routes` en admin del formulario).

### 4. Validación servidor

[`LeadFormSubmissionProcessor#validate_submission!`](app/services/lead_form_submission_processor.rb) es **genérica** — no ramificar por `template_key`.

Reglas actuales (no duplicar salvo requisito explícito):

| Campo | Servidor |
|-------|----------|
| `first_name`, `last_name`, `email` | Siempre obligatorios; email con `URI::MailTo::EMAIL_REGEXP` |
| `phone` | Obligatorio solo si el POST incluye clave `phone` |
| `company_name` | Obligatorio si `collects_company?` |
| `product` / `edition_id` | Si el formulario tiene `product_id` configurado |

`required: true` en Liquid = HTML5 únicamente para el resto de campos.

### 5. Configuración del LeadForm (admin / seed)

[`db/seeds/lead_forms_example.rb`](db/seeds/lead_forms_example.rb):

```ruby
{
  slug: "liderando-ia",
  name: "Liderando con IA",
  template_key: "liderando_ia",
  active: true,
  collects_company: false,
  default_pipeline: "Formación B2C",
  pipeline_routes: {},
  email_template: { key: "...", name: "...", subject: "...", body: "..." }
}
```

`LeadFormsExample.seed!` crea formulario + plantilla de email de forma idempotente.

En admin: **Formularios → Nuevo formulario** — el `template_key` debe existir como plantilla **Página** importada o creada en **Plantillas de formulario**.

### 6. Tests

Archivo `spec/requests/public/lead_forms_<slug>_spec.rb` o ampliar [`spec/requests/public/lead_forms_spec.rb`](spec/requests/public/lead_forms_spec.rb):

- GET renderiza campos clave
- POST con params de [`LeadFormHelper`](spec/support/lead_form_helper.rb) crea deal (incluye `_ts` válido)
- Mock Turnstile / jobs como en specs existentes

Processor: [`spec/services/lead_form_submission_processor_spec.rb`](spec/services/lead_form_submission_processor_spec.rb) solo si añades reglas de negocio nuevas en Ruby.

### 7. Documentación

Actualizar [`MANUAL_USUARIO.md`](MANUAL_USUARIO.md) y [`USER_MANUAL.md`](USER_MANUAL.md) §27 (bullet del nuevo formulario si es de ejemplo) y `Última revisión:`.

## Formulario de reserva (producto + edición)

1. Plantilla con bloque `edition_id` y `{% if product.blank %}`, `{% elsif open_editions.size == 0 %}`, etc. (ver `liderando_ia_reserva.liquid`).
2. En admin del **LeadForm**: asignar **Producto** (se envía oculto; override con `?product_id=`).
3. `open_editions` se calcula en [`LeadForm#open_editions_for`](app/models/lead_form.rb) — no hardcodear en la plantilla.

## Pipeline routes (formulario tipo contacto)

1. `LeadForm::CONTACTO_HELP_OPTIONS` en la plantilla (`options: "contacto_help"`).
2. Seed/admin: `pipeline_routes: { "curso" => pipeline_id, ... }` (nombres de pipeline del workspace).
3. `LeadForm#resolve_pipeline(help_type:)` enruta; el nombre del deal incluye la etiqueta del help type si viene en el POST.

## Checklist final (obligatorio)

```bash
bin/rails 'lead_form_templates:import[WORKSPACE_ID]'

bin/rubocop app/models/lead_form.rb app/controllers/public/lead_forms_controller.rb \
  app/services/lead_form_submission_processor.rb app/services/lead_form_templates/ \
  db/seeds/lead_forms_example.rb spec/requests/public/ \
  spec/services/lead_form_submission_processor_spec.rb

bundle exec rspec spec/requests/public/ spec/services/lead_form_submission_processor_spec.rb spec/services/turnstile_verifier_spec.rb
```

Verifica URL: `http://localhost:3030/f/<slug>`

## Resumen al usuario

Al terminar, indica:

- URL pública e iframe (desde CRM → Formularios)
- `template_key` y si hubo parciales nuevos
- Campos y pipeline asignado
- Key de plantilla de email
- Comando `lead_form_templates:import[…]` si el workspace aún no tenía la plantilla
