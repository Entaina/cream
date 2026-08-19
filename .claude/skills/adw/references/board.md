# Tablero Basecamp de cream — coordenadas, columnas y mecánica del CLI

El **WorkItem** central se materializa como una **card** en el card table de cream. Este fichero es la autoridad de las coordenadas del tablero, el mapeo columna→milestone y la mecánica del CLI `basecamp` (skill `basecamp`).

## Coordenadas

| Dato | Valor |
|---|---|
| Account (organización) | `4211550` |
| Project (bucket) | `47758733` — proyecto **CReaM** (`https://crm.entaina.ai`) |
| Card table | `10010150685` (título "Card Table", `Kanban::Board`) |
| URL del tablero | https://app.basecamp.com/4211550/buckets/47758733/card_tables/10010150685 |
| URI de card | `.../buckets/47758733/card_tables/cards/{id}` |

> El proyecto tiene **una sola** card table, así que `--card-table 10010150685` es opcional; incluirlo es seguro y a prueba de futuro. Las coordenadas por defecto se resuelven desde `.basecamp/config.json` (ver skill `basecamp`), por eso los comandos de abajo usan solo `--in 47758733` cuando basta.

## Columnas → milestone (izquierda → derecha)

| # | Columna | ID | Tipo Kanban | Milestone / rol en el flujo |
|---|---|---|---|---|
| 1 | **Triage** | `10010150686` | `Kanban::Triage` | M-triaged — intake, cards nuevas sin clasificar |
| 2 | **Not now** | `10010150687` | `Kanban::NotNowColumn` | M-deferred — parking/hold (equivalente a "On Hold"); **invalida `M-in_progress`** |
| 3 | **TODO** | `10010150688` | `Kanban::Column` | M-ready — aceptada, en cola para desarrollo |
| 4 | **Operation** | `10056309622` | `Kanban::Column` | *carril de ops/mantenimiento* — fuera del flujo de desarrollo core (ver nota) |
| 5 | **In progress** | `10010150692` | `Kanban::Column` | M-in_progress — composite `Understand→Document`; precond. `M-assigned` |
| 6 | **Test** | `10056329911` | `Kanban::Column` | M-deployed_prod — **automático** tras merge + CI post-merge verde + smoke en prod; pendiente de QA en producción |
| 7 | **Done** | `10010150694` | `Kanban::DoneColumn` | M-verified — **gate humano**; card `completed: true`, `parent.type: "Kanban::DoneColumn"` |

**Flujo core de desarrollo:** `Triage → TODO → In progress → Test → Done`.

### Notas sobre columnas especiales

- **`Triage`** (`Kanban::Triage`) es la columna de intake; las cards nuevas aterrizan aquí. Es una columna especial fija (no se puede crear otra).
- **`Not now`** (`Kanban::NotNowColumn`) es el carril de aparcamiento/hold. Este tablero **no** tiene sub-secciones "On Hold" por columna; `Not now` juega ese papel. Mover una card aquí con un comentario explicativo **invalida `M-in_progress`** (detiene el desarrollo) sin des-asignar.
- **`Done`** (`Kanban::DoneColumn`) es la completion column. **No** hay columnas separadas "To Deploy" / "Staging": cream despliega a producción en el merge a `main`, así que el flujo termina en `Test` (QA en producción) → `Done`.
- **`Operation`** es un carril lateral no estándar (trabajo operativo/mantenimiento, confirmación de fechas, tareas administrativas). **No forma parte del flujo de desarrollo GSM core**: el motor `adw` no mueve cards de/hacia `Operation` por su cuenta. Si un evento apunta a una card en `Operation`, PARA y pregunta cómo tratarla (probablemente inline, no un WorkItem de desarrollo completo).

## Mecánica del CLI `basecamp` (skill `basecamp`)

> Todos los comandos son de la CLI `basecamp` (autenticada por OAuth). Usa `--json`/`--jq` para parsear; **nunca** pipees a un `jq` externo (usa el `--jq` incorporado). Consulta la skill `basecamp` para la superficie completa.

**Leer estado (percepción):**
```bash
basecamp cards columns --card-table 10010150685 --in 47758733 --json   # las 7 columnas + ids
basecamp cards show <card_id> --json                                    # columna (parent), assignees, contenido
basecamp cards list --column 10010150692 --in 47758733 --json          # cards en "In progress"
```

**Reclamar el WorkItem (`WorkItem.claimed`, automático tras `M-ready` sin dudas):**
```bash
basecamp cards update <card_id> --assignee "$(basecamp me --jq '.data.identity.id')"   # → M-assigned
basecamp cards move   <card_id> --to "In progress" --in 47758733                        # → M-in_progress
```

**Publicar el plan (`M-plan_drafted`) — comentario en la card:**
```bash
basecamp cards comment <card_id> --content "<plan en HTML/markdown>"     # observable de M-plan_drafted
```

**Movimientos de card (associations):**
```bash
basecamp cards move <card_id> --to "Not now"     --in 47758733   # aparcar (invalida M-in_progress)
basecamp cards move <card_id> --to "Test"        --in 47758733   # automático tras M-ci_postmerge_green + smoke
basecamp cards move <card_id> --to "Done"        --in 47758733   # 🚦 gate humano, tras M-verified
```

> El nombre de columna en `--to` es case-sensitive respecto a lo que devuelve `basecamp cards columns`. Si un `move` por nombre falla, usa el **ID** de columna de la tabla de arriba.

### Movimientos automáticos vs con gate humano

- **Automáticos (sin gate):** `→ In progress` (al reclamar), `→ Test` (tras CI post-merge verde + deploy + smoke). Describen la realidad del mundo.
- **Con gate humano:** `→ Done` (requiere QA verificada en producción). El motor `adw` propone el movimiento y PARA hasta la confirmación.

> ⚠️ Basecamp no registra cuándo una card cambia de columna; `updated_at` cambia con cualquier edición, así que no sirve para reconstruir la cronología del flujo. Percibe el estado por la **columna actual** (`parent`), no por timestamps.

## Ejemplo de cards por columna (referencia de percepción)

- **Triage**: "Reordenar los bloques del dashboard" (`10136504108`), "Automatización de emails de seguimiento para leads" (`10123288012`)
- **Not now**: "Hacer un CLI de CReaM" (`10064540887`)
- **TODO**: "Enviar archivos adjuntos con los mails" (`10218692591`)
- **In progress**: "Privacy link" (`10181193595`), "Fallos en formularios" (`10181186754`)
- **Test**: "No llegan los correos" (`10181195046`) — cards a la espera de verificación en producción
- **Done**: "Dark mode" (`10068908791`), "Plantillas de mails" (`10087757396`)

*(IDs de ejemplo capturados en el momento del port; verifica siempre el estado real con `basecamp cards show`.)*
