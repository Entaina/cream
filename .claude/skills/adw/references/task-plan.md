# task-plan — Clasificación y planificación de un WorkItem

> Skill-herramienta del motor `adw`. Convierte una descripción de trabajo en su **clasificación** (`feature`/`bug`/`chore`/`none`) y un **plan de implementación tipado**. **Sin estado y sin acciones outward**: solo clasifica, planifica y reporta. Consumible por el motor, por un subagente que reciba esta ruta, o standalone.

## Contrato

**Inputs**
- `descripcion` (obligatorio): texto que describe el trabajo (cuerpo de card/petición). Cualquier formato de texto vale.
- `type` (opcional): `feature` | `bug` | `chore`. Si se pasa, se salta la clasificación.
- `output` (opcional): path donde escribir el plan. Si no se indica, se devuelve solo como texto.

**Outputs**
- La clasificación (`feature` / `bug` / `chore` / `none`).
- El plan estructurado (plantilla del tipo): alcance, capas mínimas a tocar, ficheros reales verificados, pasos ordenados y verificables, riesgos, criterios de hecho y comandos de validación. Si `none`: solo la clasificación + una línea de motivo, sin plan.

**Precondiciones** — Estar en el working directory del repo (el plan cita ficheros reales). Si la descripción es ambigua en algo esencial, pregunta antes de planificar (o marca `TODO: confirmar` si se ejecuta desatendida).

## Clasificación

- `bug`: comportamiento incorrecto, error, fallo o algo que no funciona como se espera.
- `feature`: nueva funcionalidad, mejora de UX o capacidad que no existe.
- `chore`: trabajo técnico sin impacto funcional visible — refactor, dependencias, config, CI/CD, docs.
- `none`: no encaja o no es accionable.

## Plantilla del plan por tipo

**Esqueleto común (todos los tipos)**
```md
# <Tipo>: <nombre>

## Descripción
<qué se va a hacer y por qué>

## Alcance y capas a tocar
<capas mínimas afectadas (vista, controller, modelo, servicio, job, migración…) justificando por qué no menos — least-tiers>

## Archivos Relevantes
<viñetas con paths reales verificados y por qué. Ficheros nuevos en subsección h3 'Ficheros Nuevos'>

## Tareas Paso a Paso
<h3 + viñetas, en orden ejecutable, cada paso verificable. Incluir creación de tests durante el proceso
(request/model specs con RSpec; system specs con Capybara si afecta a UI). Último paso: Comandos de Validación>

## Riesgos
<qué puede romperse, regresiones, dependencias>

## Comandos de Validación
Secuencia canónica (ver task-test.md y gates.md):
- `bin/rubocop`
- `bin/brakeman --no-pager` && `bin/bundler-audit`
- `bin/importmap audit`
- `bin/rails db:test:prepare && bundle exec rspec` (o `bundle exec rspec <scope>`)

## Notas
<opcional: contexto adicional, consideraciones futuras>
```

**Si es `bug`** — la reproducción va PRIMERO:
- `## Pasos para Reproducir` (exactos, verificados contra el código) y `## Análisis de Causa Raíz`, antes de la solución.
- `## Propuesta de Solución` quirúrgica: el mínimo número de cambios que corrige el bug.
- Las tareas incluyen un test (RSpec) que reproduce el bug en rojo antes del fix y queda en verde después.

**Si es `feature`** — los criterios de aceptación son obligatorios:
- `## Historia de Usuario` (Como / Quiero / Para que) y `## Planteamiento del Problema`.
- `## Plan de Implementación` por fases si el tamaño lo justifica; si no, directamente tareas.
- `## Criterios de Aceptación`: específicos y medibles.
- `## Estrategia de Testing`: unitarios, request/integración y casos límite.

**Si es `chore`** — `## Definición de Terminado`: condición objetiva y completa de cierre.

## Procedimiento

1. **Clasificar** (si no vino `type`). Si es `none`, reporta y para.
2. **Explorar el código afectado ANTES de planificar**: consulta las skills `cream-architecture` (dominio, multitenancy, UI, design-system) y `cream-dev` (entorno); usa Grep/Glob/Read para localizar ficheros, patrones y tests existentes que el trabajo toca. Si es bug, reprodúcelo mentalmente sobre el código real y localiza la causa raíz.
3. **Redactar el plan** con la plantilla del tipo. Todo path citado debe existir (verifícalo) o ir en 'Ficheros Nuevos' — nunca inventes paths, rutas ni convenciones; ante lo desconocido, `TODO: confirmar`.
4. **Entregar**: escribe el plan en `output` si se indicó; devuelve siempre la clasificación, el plan (o su path) y un resumen de 2-3 líneas.

## Reglas

- **KISS / YAGNI / least-tiers-to-modify**: la solución más simple que funciona, sin planificar nada que no se necesite ya, tocando el mínimo de capas — justifícalo en "Alcance y capas a tocar".
- **Respeta las convenciones de cream** al planificar: multitenancy explícita por `current_workspace` + Pundit (`WorkspaceRecordPolicy`, `UserContext`, `policy_scope`); modelos CRM incluyen `CrmRecord`/`Trackable`; UI con ViewComponent + tokens del design-system; tests RSpec que mockean HTTP y jobs (nunca servicios reales). Ver skill `cream-architecture`.
- **Documentación de usuario**: si el cambio es visible, el plan debe prever la actualización de `USER_MANUAL.md` + `MANUAL_USUARIO.md` (skill `cream-user-manual`); si toca API, `docs/openapi.yaml` (skill `cream-api`).
- Sin acciones outward: no commits, no comentarios, no movimientos de cards — eso es del consumidor.
- El plan es autocontenido: quien lo ejecute no debe necesitar releer la descripción original.
