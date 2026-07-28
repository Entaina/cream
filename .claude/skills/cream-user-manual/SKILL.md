---
name: cream-user-manual
description: >-
  Mantener MANUAL_USUARIO.md y USER_MANUAL.md al día con la funcionalidad
  visible de Cream CRM. Usar cuando se añade, cambia, habilita o deshabilita
  una feature de usuario, se modifica la navegación, formularios, flujos o
  textos de la interfaz, o el usuario pide documentación para usuarios finales.
---

# Cream — Manual de usuario

Documentación para **usuarios finales** (no desarrolladores).

## Archivos canónicos (bilingüe)

- **Español:** [`MANUAL_USUARIO.md`](../../../MANUAL_USUARIO.md) (raíz del repo)
- **Inglés:** [`USER_MANUAL.md`](../../../USER_MANUAL.md) (raíz del repo)
- Ambos ficheros deben mantenerse **sincronizados**: todo cambio en uno se replica en el otro (mismas secciones, mismo índice, mismas anclas equivalentes).
- **No duplicar** en README ni en otras skills: enlazar a estos ficheros.

## Cuándo actualizar (obligatorio)

Actualiza `MANUAL_USUARIO.md` **y** `USER_MANUAL.md` en la **misma tarea** que cambia la funcionalidad visible, antes de dar la tarea por cerrada:

| Cambio en código | Acción en el manual |
|------------------|---------------------|
| Nueva pantalla, menú o acción | Nueva subsección o fila en la tabla correspondiente |
| Cambio de flujo (formulario, filtros, permisos) | Reescribir el paso a paso afectado |
| Feature flag `enabled: true` en `cream_features.rb` | Mover de «Próximamente» a sección propia; quitar del menú condicional la nota de no disponible |
| Feature flag `enabled: false` o eliminación | Mover a «Próximamente» o eliminar la sección |
| Solo refactor interno sin cambio de UX | No tocar el manual |
| Cambio solo de API/backend sin UI | Solo actualizar si afecta a tokens, webhooks o integraciones documentadas |

## Workflow

1. **Identificar** qué ve el usuario: sidebar (`shared/_sidebar`), vistas, formularios, mensajes flash.
2. **Consultar** flags en [`app/services/cream_features.rb`](../../../app/services/cream_features.rb) — documentar solo lo `enabled: true` salvo en «Próximamente».
3. **Editar** la sección del índice que corresponda; no añadir detalle de implementación (modelos, jobs, etc.).
4. **Actualizar** la línea `Última revisión:` al inicio del manual (fecha ISO `YYYY-MM-DD`).
5. **Revisar** el índice y los enlaces internos si añades o renombras secciones.

## Estilo

- Segunda persona o imperativo («Pulsa», «Selecciona»).
- Tablas para atajos, roles, tipos de campo y comparativas.
- Nombres de la UI **tal como aparecen en pantalla** (inglés si la interfaz está en inglés: «Dashboard», «Custom fields»).
- Sin jerga de desarrollo (Pundit, Stimulus, Solid Queue, etc.).
- Una sección «Próximamente» al final con features `enabled: false` y `menu: true` o visibles parcialmente.

## Plantilla para una feature nueva

```markdown
## N. Título de la feature

Breve párrafo de qué resuelve.

### Cómo acceder

Ruta en el menú o enlace desde dónde se abre.

### Pasos

1. …
2. …

### Notas

Limitaciones, permisos (admin/member), dependencias de otras features.
```

Tras añadir la sección, **insertar en el índice** y renumerar si hace falta.

## Coordinación con otras skills

- **`cream-streak-roadmap`:** al habilitar una feature Streak, actualizar el manual es el **paso 9** del workflow (después de specs y TRACKING.md).
- **`cream-architecture`:** la sección «Finishing a change» exige revisar el manual si hubo cambio de UX.
- **`cream-dev`:** no incluir credenciales ni URLs de producción en el manual de usuario salvo que sean públicas para el cliente.

## Acciones de Timeline documentables

Al añadir o cambiar eventos en `Activity` / `activity_sentence`, actualizar **MANUAL_USUARIO.md** §13 (Timeline) y §15 (Email) si afecta al usuario:

| Acción | Texto típico en UI |
|--------|-------------------|
| `email_sent` | «X sent “Asunto” to dest@…» |
| `email_opened` | «dest@… opened “Asunto”» |
| `email_clicked` | «Link clicked in “Asunto”» |
| `email_replied` | «Someone replied to “Asunto”» |

Los nombres de badges en la lista de emails (**Sent**, **Opened**, **Replied**, **Received**, **Scheduled**, **Follow up**) deben coincidir con `_email_section.html.erb`.

## Menciones `@usuario`

Documentar en **MANUAL_USUARIO.md** §7 (Tareas) y, si aplica, §13 (ficha) y §18 (Notificaciones):

| Superficie | UX visible | Manual |
|------------|------------|--------|
| Título de tarea | Desplegable al escribir `@`; asigna al mencionado; título resaltado | §7 «Mencionar y asignar con @» |
| Comentario | `@nombre` manual; resaltado; notificación | §13 fila Comments; §18 Notificaciones |
| Cambio futuro | Notificación al mencionar en tarea | Añadir a §18 cuando exista en código |

No documentar `MentionParser`, `mention_controller.js` ni helpers en el manual (solo comportamiento visible).

## Filtros de listados (referencia para §5 y §9)

Al cambiar filtros en código, actualizar la subsección **§5 «Filtros en deals»** y, si aplica, §9 (tablero) y §10 (vistas guardadas). Nombres de la UI en **inglés** tal como en pantalla.

| Tipo | Vista tabla | Tablero | Filtros |
|------|:-----------:|:-------:|---------|
| **Person** | sí | — | `company_id` (All companies), `cf`, `q` |
| **Company** | sí | — | `industry`, `cf`, `q` |
| **Deal** | sí | sí | Tabla: `stage`, `product_id`, `edition_id`, `first_contact_from` / `first_contact_to`, `cf`, `q`. Tablero: mismos **excepto** `stage` (columnas = etapas) |

Comportamiento visible a documentar:

- Filtros **combinables**; auto-submit al cambiar un control.
- **Clear** quita filtros activos.
- **Show closed** y paginación conservan filtros en la URL.
- Vistas guardadas y **Export** respetan los filtros de la vista tabla (incl. producto, edición y fechas en deals).

Partial compartido: `app/views/deals/_filters.html.erb` (`show_stage: false` en board).

## Checklist antes de cerrar la tarea

- [ ] ¿Cambió algo que un usuario vería o haría distinto? → manual actualizado
- [ ] ¿Se movió una feature entre activa / próximamente? → ambas secciones coherentes
- [ ] ¿Fecha `Última revisión` actualizada?
- [ ] ¿Índice y anclas `#` siguen siendo válidos?
- [ ] ¿`MANUAL_USUARIO.md` y `USER_MANUAL.md` siguen sincronizados?
