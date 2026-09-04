---
name: cream-playwright
description: Verify Cream screens in a real browser with playwright-cli — open, login, screenshot, interact. Use whenever validating UI changes, reproducing front-end bugs, or smoke-testing production after deploy.
---

# Cream — Browser verification with playwright-cli

Use `npx -y @playwright/cli@latest <command>` (alias it as `pw`). The browser session persists between commands via a daemon.

Credentials and base URL come from `.env` (`CREAM_APP_URL`, `CREAM_SEED_ADMIN_EMAIL`, `CREAM_SEED_ADMIN_PASSWORD`). See `cream-dev` skill for the full variable list.

## Typical session

```bash
set -a && source .env && set +a
pw() { npx -y @playwright/cli@latest "$@"; }
pw open
pw resize 1440 900
pw goto "$CREAM_APP_URL/"            # redirects to /session/new when logged out
pw fill "Email textbox" "$CREAM_SEED_ADMIN_EMAIL"
pw fill "Password textbox" "$CREAM_SEED_ADMIN_PASSWORD"
pw click "Sign in button"
pw screenshot --filename tmp/screenshots/dashboard.png
pw close                                   # when done
```

- Targets are natural-language descriptions resolved against the accessibility tree; run `pw snapshot` to list elements with refs if a target is ambiguous.
- Read screenshots with the Read tool to inspect them visually.
- Key routes: `/` dashboard, `/people`, `/companies`, `/deals` (table), `/deals/board` (kanban), `/tasks`, `/lists`, `/search`.
- Drag & drop on the kanban: `pw drag "<card>" "<column>"`.
- Server must be running (see cream-dev skill). Keep screenshots in `tmp/screenshots/` (gitignored).

## Verificar menciones en tareas

Tras cambios en `@` / autocompletado de tareas:

```bash
pw goto "$CREAM_APP_URL/tasks"
pw fill "Add a task..." "@"
pw snapshot   # debe listar miembros del workspace en listbox
```

Comprueba también el campo de título en una ficha (Person/Company/Deal) y el bloque «Next action» al crear un deal.

## Verificar filtros de deals

Tras cambios en la barra de filtros de deals (tabla o tablero):

```bash
pw goto "$CREAM_APP_URL/deals"
pw snapshot   # All stages, All products, All editions, fechas first_contact_*
pw goto "$CREAM_APP_URL/deals/board"
pw snapshot   # sin All stages; con product/edition/fechas
```

Combina filtros y comprueba que **Clear** restablece la lista; en tabla, **Export** debe respetar los filtros activos. El desplegable **All editions** agrupa ediciones por producto.

## Verificar ediciones por producto

Tras cambios en catálogo de productos, ediciones anidadas o picker en líneas de deal:

```bash
pw goto "$CREAM_APP_URL/products"
# Abrir un producto → debe verse sección Editions (sin pestaña global Editions)
pw goto "$CREAM_APP_URL/products/<id>/edit"
pw snapshot   # tabla Editions, botón New edition

pw goto "$CREAM_APP_URL/deals/<id>"
pw snapshot   # en Products: campo Edition por línea; al añadir producto, Edition deshabilitado hasta elegir producto
```

En una ficha de deal: selecciona producto en «Add product», escribe en Edition — deben listarse solo las ediciones de ese producto (no «+ Create» si ya existe). En una línea existente, el picker debe usar las ediciones del producto de esa fila.

## Verificar marketing hub

Tras cambios en campañas, segmentos, recorridos, scoring, suscripciones o atribución (flags `:marketing_*`, `:journeys`, `:lead_scoring`):

```bash
pw goto "$CREAM_APP_URL/subscription_types"
pw snapshot   # CRUD tipos de suscripción

pw goto "$CREAM_APP_URL/campaigns"
pw snapshot   # lista, formulario, KPIs en show

pw goto "$CREAM_APP_URL/segments/new"
pw snapshot   # filas de filtros + preview en vivo (segment_preview_controller)

pw goto "$CREAM_APP_URL/journeys/new"
pw snapshot   # selectores trigger + pasos dinámicos (journey_form_controller)

pw goto "$CREAM_APP_URL/scoring_rules"
pw snapshot   # reglas + botón recalcular

pw goto "$CREAM_APP_URL/marketing_attribution"
pw snapshot   # filtros UTM, totales, barras

pw goto "$CREAM_APP_URL/people/<id>"
pw snapshot   # lifecycle, lead score, suscripciones
```

Rutas públicas (sin login):

```bash
pw goto "$CREAM_APP_URL/p/<workspace_slug>/<landing-slug>"
pw snapshot   # landing scope por workspace

# Preferencias: generar token en consola o desde email de campaña de prueba
pw goto "$CREAM_APP_URL/cream.js"
pw snapshot   # script tracking
```

Detalle técnico: skill `cream-marketing`.

## Production smoke test

After auto-deploy (push to `main` → GHCR → server deploy path), verify against production:

```bash
set -a && source .env && set +a
export CREAM_APP_URL=https://crm.example.com
pw open && pw goto "$CREAM_APP_URL/up"   # expect green health page
pw goto "$CREAM_APP_URL/session/new"
# login with seeded admin credentials from server .env / local CREAM_SEED_*
```

Production deploy details: `cream-dev` skill and [`deploy/README.md`](../../../deploy/README.md).
