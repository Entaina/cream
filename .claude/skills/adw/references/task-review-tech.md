# task-review-tech — Revisión técnica adversarial

> Skill-herramienta del motor `adw`, realización de la mitad **técnica** del artefacto Review. Analiza el diff de la rama actual contra `main` (o un scope/dimensión) e intenta **refutar** que los cambios son correctos. **Sin estado y sin acciones outward**: solo revisa y reporta; no corrige, no commitea, no comenta, no mueve cards. Consumible por el motor, por un subagente que revise UNA dimensión en fan-out adversarial (recibe esta ruta + la dimensión), o standalone.

## Contrato

**Inputs**
- **Qué revisar** (por defecto): el diff `git diff origin/main...HEAD`, más `--stat` y `git log origin/main..HEAD --oneline` para contexto.
- **Scope opcional**: subconjunto de ficheros, rango de commits o diff provisto en el prompt.
- **Dimensión opcional** (modo fan-out): si el prompt indica UNA dimensión (p. ej. "solo multitenancy"), revisa exclusivamente esa en profundidad.
- **Contexto opcional**: plan o descripción de la card, para juzgar cambios no relacionados (unintended changes).

**Outputs** — veredicto estructurado en el mensaje final:
- **Resumen**: 2-4 frases sobre el estado general.
- **Hallazgos**, cada uno con **Severidad** (`blocker` | `should-fix` | `nit`), **Ubicación** (`fichero:línea`), **Explicación** (por qué es un problema, con evidencia observada) y **Sugerencia** (corrección concreta).
- **Veredicto global**: `PASS` (sin blockers) o `FAIL` (≥1 blocker), con conteo por severidad.

**Precondiciones observables** — repo git con rama distinta de `main` y ≥1 commit de diferencia (`git log origin/main..HEAD` no vacío), o un diff/scope explícito en el prompt. Si no hay cambios, repórtalo y termina; no inventes trabajo.

## Severidad (enum canónico)

| Severidad | Efecto |
|---|---|
| **`blocker`** | Correctitud, seguridad, fuga entre workspaces, funcionalidad rota, datos. Invalida `M-review_passed` → `WorkItem.goto(Implement)`. **No se abre PR.** |
| **`should-fix`** | Deuda técnica, manejo de errores ausente, cobertura insuficiente, convención violada. Se corrige o se justifica explícitamente; **no se ignora en silencio**. |
| **`nit`** | Estilo, naming menor, sugerencia opcional. |

## Dimensiones de review (cream)

Cada dimensión se verifica intentando **REFUTAR**, no confirmar.

1. **Corrección** — la lógica hace lo que el cambio pretende; sin condiciones invertidas, nil no manejados, migraciones peligrosas ni regresiones. Manejo de errores donde hace falta.
2. **Convenciones (KISS/YAGNI, least-tiers)** — la solución modifica las menores capas posibles, sin abstracciones especulativas ni features no pedidas; nombres y estructura siguen las del proyecto; sin cambios no relacionados (config, dependencias, assets) sin justificación. Canónico: skill `cream-architecture`.
3. **Seguridad** — sin credenciales hardcodeadas, SQL injection, XSS ni exposición de datos sensibles. Autorización con Pundit: `authorize` en acciones y `policy_scope` en listados; mutaciones admin-only donde aplique (`admin?`). El job `scan_ruby` (Brakeman + bundler-audit) es el gate; esta dimensión anticipa lo que Brakeman marcaría y lo que no ve (lógica de autorización).
4. **Multitenancy** — aislamiento **explícito** por `current_workspace` (`Current.workspace`). Toda query sobre modelos CRM debe scoparse por el workspace (`current_workspace.deals`, `policy_scope(...)`, `WorkspaceRecordPolicy`); nada cruza workspaces ni confía en ids de params sin scoping. Los modelos CRM incluyen `CrmRecord` (`belongs_to :workspace`); verifica que las asociaciones nuevas también lo respetan.
5. **UI / design-system** (si el cambio toca frontend) — sin hex literales ni `#000` (principio "gris, nunca negro": usa `ink`/`ink-soft`/`ink-faint`); usa los tokens del `@theme` (`ink`, `line`, `canvas`/`canvas-soft`/`canvas-tint`, `accent`) y las clases de componente (`.btn-primary`, `.input`, `.card`, `.table-base`); ViewComponent en `app/components/` para piezas reutilizables; Stimulus/Turbo, no JS ad-hoc. Canónico: skill `cream-architecture § UI/Design system`.
6. **Tests** — lo nuevo tiene cobertura (model/request/system según capa, RSpec); los specs scopean datos por el workspace del usuario firmado y mockean HTTP + jobs (nunca servicios reales ni workers de fondo); tests de autorización cross-workspace cuando hay superficie de seguridad; system specs (`type: :system`) para flujos de UI.

## Procedimiento

1. **Delimita el scope**: obtén el diff (`git diff origin/main...HEAD`), el stat y el log. Si el prompt fija scope o dimensión, restringe a eso.
2. **Entiende la intención**: lee el plan/card si se proveyó; si no, infiérela de los mensajes de commit. La necesitas para juzgar corrección y unintended changes.
3. **Postura ADVERSARIAL**: para cada dimensión aplicable, pregunta "¿cómo demuestro que esto está mal?" — busca el caso que rompe, el workspace que se cuela, el `#000` escondido, el spec que no scopea. No confirmes; refuta.
4. **Verifica cada hallazgo contra el código real** antes de reportarlo: lee el fichero alrededor de la línea, comprueba si un guard/callback/policy ya cubre el caso, ejecuta greps de apoyo. **Nada de hallazgos especulativos**: si no puedes evidenciarlo, no lo reportes o márcalo como duda de baja confianza en el resumen.
5. **Clasifica con criterio**: blocker solo si afecta correctitud, seguridad o aislamiento de datos. Un hallazgo "probablemente menor" no se ignora: `should-fix` o `nit` con su justificación.
6. **Emite el veredicto** con el formato del Contrato. Sin acciones outward.

## Reglas

- **Referencias canónicas** (consulta, no dupliques): skill `cream-architecture` (multitenancy, UI, design-system, convenciones), `cream-dev` (lint, entorno), `cream-api`/`cream-mcp` (si el diff toca API/MCP).
- Solo lectura: `git` de consulta, `Read`, `Grep`, `Glob`. No modifiques el working tree ni el estado remoto.
- Si el diff es enorme, prioriza por riesgo (seguridad/multitenancy primero) y dilo en el resumen; no finjas cobertura exhaustiva.
- Nunca inventes convenciones, rutas ni columnas: si algo no está en el repo ni en las referencias, márcalo `TODO: confirmar`.
