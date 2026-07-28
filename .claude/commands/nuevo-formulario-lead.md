---
description: Crear un formulario público de captación de leads operativo (ERB, email, seed, specs)
argument-hint: "slug nombre [pipeline] — describe campos extra en el mensaje si hace falta"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskQuestion
---

Crea un **formulario público de leads** completo y operativo en Cream. El usuario invoca
`/nuevo-formulario-lead` con el slug, nombre y descripción de campos; tú implementas todo
lo necesario siguiendo los patrones existentes.

## Antes de codear: recoger especificación

Si `$ARGUMENTS` o el mensaje del usuario no bastan, pregunta (AskQuestion o texto) hasta tener:

| Dato | Ejemplo |
|------|---------|
| **slug** (URL `/f/slug`) | `liderando-ia` |
| **name** (título visible) | `Liderando con IA` |
| **template_key** | igual que slug sin guiones raros: `liderando_ia` |
| **pipeline por defecto** | `Proyectos` (nombre en workspace Example) |
| **pipeline_routes** | solo si hay desplegable que enruta (como contacto) |
| **require_phone** | sí/no (contacto = sí) |
| **show_how_heard_in_base** | sí/no (contacto = no; va al final del partial) |
| **collects_company** | sí/no |
| **Campos extra** | tipo, label, `field`, required, options si select |
| **Email al lead** | key, name, subject, body (placeholders `{first_name}`, `{name}`, `{email}`) |
| **Responsable** | por defecto: admin del workspace en seed |

Campos **ya incluidos** en el wrapper (no repetir en el ERB salvo reordenación tipo contacto):

- Ocultos: `_hidden_fields`, honeypot, time-trap, UTM
- Base: Nombre, Email, Teléfono (opcional/obligatorio según config), ¿Cómo nos has conocido? (opcional en base)
- Consentimiento: newsletter + RGPD
- Turnstile si hay env vars

## Archivos a crear o tocar

### 1. Plantilla ERB del formulario

`app/views/public/lead_forms/templates/_<template_key>.html.erb`

Solo campos **específicos** del formulario. Usa partials existentes:

```erb
<%# select libre %>
<div>
  <%= f.label :edition, "Edición", class: "label" %>
  <%= f.select :edition, options_for_select([["Marzo 2026", "marzo_2026"]]), { include_blank: "Elige" }, class: "input w-full", required: true %>
</div>

<%# textarea %>
<%= f.text_area :message, rows: 4, class: "input w-full resize-y" %>

<%# pregunta cualificadora %>
<%= render "public/lead_forms/qualifying_question", f: f, label: "¿Qué curso te interesa?", field: :qualifying_answer, required: true %>

<%# empresa (si collects_company) %>
<% if lead_form.collects_company? %> ... company_name, company_cif ... <% end %>

<%# how_heard al final (patrón contacto) %>
<%= render "public/lead_forms/how_heard_field", f: f %>
```

Patrones de referencia:

- [`_contacto.html.erb`](app/views/public/lead_forms/templates/_contacto.html.erb) — help_type + message + how_heard
- [`_curso.html.erb`](app/views/public/lead_forms/templates/_curso.html.erb) — qualifying_question

### 2. Wrapper — ajustar locales si hace falta

[`_form_wrapper.html.erb`](app/views/public/lead_forms/_form_wrapper.html.erb) pasa a `base_fields`:

```erb
require_phone: lead_form.require_phone?
show_how_heard: lead_form.show_how_heard_in_base?
```

Si el nuevo formulario necesita otro comportamiento, **extiende** [`LeadForm`](app/models/lead_form.rb):

```ruby
def require_phone?
  contacto_template? || template_key.in?(%w[mi_formulario])
end

def show_how_heard_in_base?
  !contacto_template? && template_key != "otro_caso"
end
```

No dupliques lógica en el ERB del wrapper.

### 3. Strong params

Añade nombres de campo nuevos en [`Public::LeadFormsController#lead_params`](app/controllers/public/lead_forms_controller.rb).

Si el formulario usa `help_type` con rutas de pipeline, ya está soportado.

Validaciones extra en [`LeadFormSubmissionProcessor`](app/services/lead_form_submission_processor.rb) solo si hay reglas de negocio (p. ej. contacto exige phone + help_type).

### 4. Seed Example

Añade una entrada en `FORMS` de [`db/seeds/lead_forms_example.rb`](db/seeds/lead_forms_example.rb):

```ruby
{
  slug: "liderando-ia",
  name: "Liderando con IA",
  template_key: "liderando_ia",
  active: true,
  collects_company: false,
  default_pipeline: "Cursos",
  pipeline_routes: {}, # o { "curso" => "Cursos", ... } con nombres de pipeline
  email_template: {
    key: "liderando_ia_lead",
    name: "Liderando IA — acuse de recibo",
    subject: "Example | Hemos recibido tu solicitud — Mi formulario",
    body: <<~BODY.strip
      Hola {first_name}:
      ...
    BODY
  }
}
```

`LeadFormsExample.seed!` ya itera `FORMS` y crea plantilla + LeadForm de forma idempotente.

### 5. Tests

Añade ejemplo mínimo en [`spec/requests/public/lead_forms_spec.rb`](spec/requests/public/lead_forms_spec.rb) o un archivo `spec/requests/public/lead_forms_<slug>_spec.rb`:

- GET renderiza campos clave
- POST con `contacto_lead_params` adaptado (incluye `_ts` válido vía [`LeadFormHelper`](spec/support/lead_form_helper.rb)) crea deal

Mock HTTP (Turnstile) y mails como en specs existentes.

### 6. Documentación

Si cambia UX visible, actualiza [`MANUAL_USUARIO.md`](MANUAL_USUARIO.md) y [`USER_MANUAL.md`](USER_MANUAL.md) §25 y `Última revisión:`.

## Pipeline routes (formulario tipo contacto)

Si hay desplegable `help_type` que enruta pipeline:

1. Usa `LeadForm::CONTACTO_HELP_OPTIONS` o define constante nueva si las opciones difieren.
2. En seed: `pipeline_routes: { "curso" => "Cursos", ... }` (nombres de pipeline del workspace).
3. `LeadForm#resolve_pipeline(help_type:)` ya enruta; el partial puede reutilizar el de contacto.

## Checklist final (obligatorio)

Ejecuta y corrige hasta que pasen:

```bash
bin/rubocop app/models/lead_form.rb app/controllers/public/lead_forms_controller.rb \
  app/services/lead_form_submission_processor.rb db/seeds/lead_forms_example.rb \
  spec/requests/public/ spec/services/lead_form_submission_processor_spec.rb

bundle exec rspec spec/requests/public/ spec/services/lead_form_submission_processor_spec.rb spec/services/turnstile_verifier_spec.rb
```

Para cargar en dev (workspace Example):

```bash
bin/rails runner "load 'db/seeds/lead_forms_example.rb'; w=Workspace.find_by(slug: ENV.fetch('CREAM_ORGANIZATION_WORKSPACE_NAME', 'Example').parameterize); u=w.briefing_actor; LeadFormsExample.seed!(workspace: w, user: u)"
```

Verifica URL: `http://localhost:3030/f/<slug>`

## Resumen al usuario

Al terminar, indica:

- URL pública e iframe (desde CRM → Formularios)
- Campos creados y pipeline asignado
- Key de plantilla de email
- Comando seed / si hace falta `bin/rails db:seed`
