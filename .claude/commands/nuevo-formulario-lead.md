---
description: Crear un formulario público de captación de leads operativo (Liquid en BD, email, seed opcional, specs)
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
| **slug** (URL `/f/slug`) | `solicitud-demo` |
| **name** (título visible) | `Solicitar demo` |
| **template_key** | identificador de plantilla Página en BD, p. ej. `solicitud_demo` |
| **pipeline por defecto** | `Proyectos` |
| **pipeline_routes** | solo si hay desplegable `help_type` (como contacto demo) |
| **collects_company** | sí/no |
| **product_id** | opcional; obligatorio lógico en formularios de reserva con edición |
| **Campos extra** | tipo, label, `name`, `required`, `options` si select |
| **Email al lead** | key, name, subject, body (`{first_name}`, `{name}`, `{email}`) |
| **Responsable** | por defecto: admin del workspace |

## Dónde vive la plantilla

**Runtime = BD del workspace.** Las plantillas se crean o editan en **Formularios → Plantillas de formulario** (admin). El repo solo incluye ejemplos demo en `lib/lead_form_templates/` (`contacto`, `demo`, `newsletter`, `reserva`).

- **Workspace real / producción:** crear la plantilla Liquid en la UI (o vía consola en `LeadFormTemplate`), guardar para recompilar `submission_schema`. **No** añadir ficheros al repo salvo que sea un nuevo ejemplo de demo.
- **Workspace demo (`db:seed`):** opcionalmente añadir página en `lib/lead_form_templates/public/lead_forms/` + entrada en [`db/seeds/lead_forms_example.rb`](db/seeds/lead_forms_example.rb) + import en seed.

Parciales reutilizables (demo repo o creados en BD como partials):

- `contact_fields`, `contact_fields_with_prefix`, `how_heard_field`, `newsletter_opt_in`, `subscribe_all_opt_in`, `consent_fields`

Tags de sistema en cada **página**:

```liquid
{% form_open %}
{% hidden_fields %}
{% honeypot %}
…campos…
{% turnstile %}
{% submit 'Enviar' %}
{% form_close %}
```

## Patrones de referencia (demo repo)

- [`contacto.liquid`](lib/lead_form_templates/public/lead_forms/contacto.liquid) — `help_type` + `message`
- [`demo.liquid`](lib/lead_form_templates/public/lead_forms/demo.liquid) — `collects_company` condicional
- [`reserva.liquid`](lib/lead_form_templates/public/lead_forms/reserva.liquid) — `open_editions` + contacto

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
    {% partial 'subscribe_all_opt_in' %}
    {% partial 'consent_fields' %}
  </div>

  {% turnstile %}
  {% submit 'Enviar' %}
  {% form_close %}
</div>
```

Select con opciones inline:

```liquid
{% field type: "select", name: "help_type", label: "¿En qué te ayudamos?", choices: "Curso|curso; Entrenamiento|entrenamiento", blank: "Selecciona", required: true %}
```

Marketing: `{% subscription_opt_in slug: "newsletter" %}` (clave desde **Suscripciones**).

### 3. Nombres de campo

Los campos del POST deben llamarse `lead[nombre_campo]` con `nombre_campo` en minúsculas (`FIELD_KEY_FORMAT`). No hace falta registrar el nombre en Ruby.

### 4. Validación servidor

Esquema en `LeadFormTemplate#submission_schema`, recompilado **al guardar** la plantilla en admin. Tras editar Liquid, guardar la plantilla. Si el esquema está vacío, hay fallback a render en vivo.

### 5. Configuración del LeadForm

En admin: **Formularios → Nuevo formulario** — el `template_key` debe existir como plantilla **Página** en el workspace.

Solo para demo: añadir a [`db/seeds/lead_forms_example.rb`](db/seeds/lead_forms_example.rb) y ejecutar `db:seed`.

### 6. Tests

`spec/requests/public/lead_forms_<slug>_spec.rb` o ampliar [`spec/requests/public/lead_forms_spec.rb`](spec/requests/public/lead_forms_spec.rb):

- GET renderiza campos clave
- POST con params de [`LeadFormHelper`](spec/support/lead_form_helper.rb) crea deal (incluye `_ts` válido)
- Mock Turnstile / jobs

Los specs importan plantillas demo al workspace fixture vía `import_lead_form_templates!`.

### 7. Documentación

Actualizar [`MANUAL_USUARIO.md`](MANUAL_USUARIO.md) y [`USER_MANUAL.md`](USER_MANUAL.md) §27 solo si el formulario es **de ejemplo demo** (bullet en la lista de 4).

## Formulario de reserva (producto + edición)

Ver [`reserva.liquid`](lib/lead_form_templates/public/lead_forms/reserva.liquid). Asignar **Producto** en el LeadForm; override con `?product_id=`.

## Pipeline routes

Claves de `pipeline_routes` = **value** de `choices:` en Liquid (`curso`, no «Curso»).

## Checklist final

```bash
bundle exec rspec spec/requests/public/ spec/services/lead_form_submission_processor_spec.rb
```

Verifica URL: `http://localhost:3030/f/<slug>`

## Resumen al usuario

- URL pública e iframe
- `template_key` y dónde se creó la plantilla (UI vs demo seed)
- Campos y pipeline asignado
- Key de plantilla de email
