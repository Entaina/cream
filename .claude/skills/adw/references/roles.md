# Roles y realizaciones — catálogo de capacidades de cream

Los **roles son servicios**: cada uno actúa sobre artefactos en etapas concretas y se **realiza** con una capacidad concreta de la sesión (subagente, skill o CLI). Este fichero es el **catálogo que consume el motor `adw`**: para orquestar una etapa, mira aquí qué la realiza. Añadir una herramienta nueva al sistema = actualizar este fichero, no la skill orquestadora.

> No asumas que una capacidad existe: verifícala en tu sesión (skills disponibles, subagentes, CLIs en PATH) antes de usarla. Las skills `cream-*` son las convenciones canónicas del repo; consúltalas, no las dupliques.

## Roles × etapa × realización

| Rol | Etapas | Servicio | Realización en cream |
|---|---|---|---|
| **Product Owner** | Intake, Release | triar, aceptar, mover cards | CLI `basecamp` (skill `basecamp`) + [`task-triage.md`](task-triage.md) + [`board.md`](board.md) |
| **Backend dev** | Understand, Implement | materializar el plan en el servidor (rutas→controllers→modelos→jobs→servicios) | subagente `general-purpose` guiado por [`task-plan.md`](task-plan.md)/[`task-resolve.md`](task-resolve.md) + skills `cream-architecture`, `cream-dev`; API → `cream-api`; MCP → `cream-mcp` |
| **Frontend dev** | Understand, Implement | UI Hotwire/Turbo/Stimulus + ViewComponent + design-system | subagente `general-purpose` + skill `cream-architecture § UI/Design system` (tokens `ink`/`line`/`canvas`/`accent`, `app/components/`, importmap/Stimulus) |
| **QA** | Validate, Review | gates locales + verificación de criterios con evidencia + review adversarial | [`task-test.md`](task-test.md), [`task-review-issue.md`](task-review-issue.md) (evidencia con skill `cream-playwright`), [`task-review-tech.md`](task-review-tech.md) + subagente `code-reviewer` (fan-out por dimensión, loop-until-clean, tope 3) |
| **Documentador** | Document | doc de cierre (manuales de usuario, OpenAPI, MCP) en la rama | [`task-document.md`](task-document.md) + skills `cream-user-manual` (`USER_MANUAL.md`/`MANUAL_USUARIO.md`), `cream-api` (`docs/openapi.yaml`), `cream-mcp` |
| **Integrador** | Submit, Release | rama → PR → CI → merge → borrado de rama → smoke → card | skill `git` (Conventional Commits) + `gh` (`pr create`/`checks`/`merge`/`run watch`) + `basecamp` + skill `cream-playwright` (smoke en prod) |

## CLIs y herramientas asumidas

| Herramienta | Uso | Verificación |
|---|---|---|
| `git` (+ skill `git`) | ramas de feature, commits Conventional | `git --version` |
| `gh` | PRs, checks, merge, runs | `gh --version`, `gh auth status` |
| `basecamp` (skill `basecamp`) | leer/mover/comentar cards | `basecamp me` |
| `aws` (CLI) | subir media de evidencia a R2 vía [`scripts/evidence-r2.sh`](../scripts/evidence-r2.sh) | `aws --version` |
| `pw` (skill `cream-playwright`, `npx -y @playwright/cli`) | evidencia visual + smoke en prod | ver skill `cream-playwright` |
| `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, `bin/importmap`, `bundle exec rspec` | gates ([`gates.md`](gates.md)) | correr en el repo |
| Workflow tool | orquestación dinámica (fan-out, pipeline, loops) | disponible en la sesión de Claude Code |

## Subagentes (`agentType`) para workflows dinámicos

| agentType | Cuándo | Notas |
|---|---|---|
| `Explore` | primar contexto (fan-out de lectura del código afectado) | solo lectura; devuelve la conclusión, no vuelca ficheros |
| `Plan` | diseñar la estrategia de implementación de una tarea | usa junto a [`task-plan.md`](task-plan.md) |
| `general-purpose` | implementar (backend/frontend), aplicar patches | pásale la ruta de la task-skill relevante en el prompt |
| `code-reviewer` | review técnico adversarial por dimensión | fan-out: un subagente por dimensión de [`task-review-tech.md`](task-review-tech.md) |

> Cuando un subagente deba seguir una skill-herramienta, **pásale la ruta en el prompt** (p. ej. "sigue `.claude/skills/adw/references/task-review-tech.md`, dimensión: multitenancy"). Son markdown en disco, legibles aunque el subagente no tenga el Skill tool.

## Skills `cream-*` como fuente de convenciones (referencia, no duplicar)

- **`cream-architecture`** — dominio (Company/Person/Deal, workspaces), multitenancy (`current_workspace`, Pundit `WorkspaceRecordPolicy`, `UserContext`), UI, design-system, deploy. Autoridad de "Finishing a change".
- **`cream-dev`** — arrancar/construir/depurar en local (docker compose DB, `bin/dev`, Tailwind, seeds, credenciales), lint local, y auto-deploy en push a `main`.
- **`cream-api`** — REST API v1 (`app/controllers/api/v1/`, `docs/openapi.yaml`, auth por tokens).
- **`cream-mcp`** — servidor MCP (`/mcp`, OAuth/PKCE, tools IA).
- **`cream-playwright`** — verificación en navegador con `pw` (login seed desde `.env`, rutas clave, smoke en producción).
- **`cream-user-manual`** — mantener `USER_MANUAL.md` (EN) y `MANUAL_USUARIO.md` (ES) al día con la funcionalidad visible.
