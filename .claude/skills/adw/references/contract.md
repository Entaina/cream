# Contrato de desarrollo — diseño artifact-centric (BALSA/GSM) para cream

> **Capa de proceso, no de referencia.** Este fichero define *cómo* se entrega trabajo en el CRM **cream** como un sistema **artifact-centric**: una unidad de entrega (`WorkItem`) viaja por 8 etapas hasta producción, y los **roles son servicios** (subagentes/skills/CLIs) que actúan sobre artefactos en etapas concretas. Las convenciones técnicas de cream (arquitectura, multitenancy, diseño, deploy) **se referencian** en las skills `cream-*`, no se duplican aquí.

Vocabulario BALSA/GSM (Nigam & Caswell 2003; Hull et al. 2010–2011): **Business Artifact** (entidad de negocio con datos + ciclo de vida) · **Stage** (etapa de actividad) · **Milestone** (objetivo de negocio, *alcanzable* e *invalidable* por eventos) · **Guard** (condición declarativa que abre una etapa o alcanza un milestone) · **Association** (propagación de eventos entre artefactos).

> **REGLA CERO**: nunca inventes nombres de columna, rutas, modelos o convenciones que no estén aquí o verificadas en el repo. Si algo es desconocido, márcalo `TODO: confirmar` y pregunta.

---

## Principios rectores

Canónico: skills `cream-architecture` (dominio, workspaces, multitenancy, diseño), `cream-dev` (entorno, lint, deploy).

- **KISS · YAGNI · least-tiers-to-modify**: la solución más simple, el menor número de capas tocadas.
- **Multitenancy explícita por `current_workspace`** (`Current.workspace`) + Pundit `policy_scope`/`authorize` con `UserContext` y `WorkspaceRecordPolicy`. Toda query CRM se scopea por el workspace; nada cruza tenants.
- **Sin texto hardcodeado sensible** ni secretos en el código; seeds de desarrollo para pruebas.
- Convenciones de UI y design-system (tokens `ink`/`line`/`canvas`/`accent`, ViewComponent, "gris, nunca negro") en `cream-architecture § Design system`.

---

## Modos de operación

Convenciones de proceso que fijan cómo se recorre el lifecycle, en **dos ejes ortogonales**:

| Eje | Por defecto | Alternativa |
|---|---|---|
| **Identidad del WorkItem** | Card directa | Modo issue |
| **Autonomía** | Autónomo hasta el PR | — |

> **No hay eje "camino de entrega".** cream **no tiene rama `production` ni entorno de staging**: hay un único camino `main`-first. Todo push/merge a `main` **despliega automáticamente a producción** (GHCR + SSH, ver `.github/workflows/docker.yml` y skill `cream-dev`). Un rollback es un **revert del PR** + redeploy, no una rama de hotfix.

### Identidad: card directa (por defecto)

El ciclo es `card → branch → PR`. `M-issue_created` se satisface trivialmente: la identidad del WorkItem **es** la card; sus encarnaciones GitHub son la rama y el PR. **No se crean issues de GitHub** ni se depende de ellas. El *modo issue* queda disponible para WorkItems que lleguen por esa vía.

### Autonomía: autónomo hasta el PR (por defecto)

`Understand`→`Submit` se recorre **sin gates humanos intermedios**. En la **frontera `Intake`→`Understand`**, tras confirmar `M-ready` **sin dudas**, el operador **reclama** el WorkItem: la card se **asigna** (`basecamp me` → `M-assigned`) y pasa a **In progress** (→ `M-in_progress`), **antes de planificar** (primar contexto, explorar código, redactar el plan o crear la rama). `Guard[understand]` exige `M-in_progress`: el desarrollo **no abre** sin ello. Con dudas → comentar / `Not now`, sin asignar ni mover.

El primer gate humano es el **merge**. Tras el merge, el push a `main` **despliega a producción**; al quedar el pipeline post-merge verde y pasar el smoke, la card pasa a **`Test`** de forma **automática** (describe la realidad: el cambio ya está en producción, pendiente de verificación de QA). El último gate humano es mover la card a **`Done`** tras verificar en producción. El `Guard[advance_any]` sigue vigente: un gate bloqueante en rojo no es un gate humano, es una condición dura — se para y se arregla.

La decisión de aceptación (`M-ready` vs `M-deferred`) se toma en el triage (`Intake`), realización: [`task-triage.md`](task-triage.md). Ante duda genuina → se publica la pregunta como comentario en la propia card y se PARA hasta la respuesta.

La ejecución de este contrato la orquesta la skill **`adw`** ([`../SKILL.md`](../SKILL.md)), que lo lee y lo ejecuta sin duplicar sus reglas.

---

## Artefactos de negocio

| Artefacto | Es | Regla propia en |
|---|---|---|
| **WorkItem** (central) | Unidad de entrega. Encarnaciones físicas: `card → (issue) → branch → PR`. Un artefacto, múltiples representaciones. | [`board.md`](board.md) |
| **Plan** | Descomposición técnica antes de tocar código. Observable: comentario en la card. | [`task-plan.md`](task-plan.md) |
| **Change** (=PR) | Cambios versionados que materializan el Plan en las capas. | skill `git`, `board.md` |
| **Evidence** | Prueba tipada según el cambio: visual (screenshots/vídeo con `cream-playwright`) o textual (tests/logs/curl). Obligatoria en todo PR, siempre como ficheros en `tmp/evidence/<ref>/`; media a R2. | [`evidence.md`](evidence.md) |
| **Review** | Veredicto adversarial (tech + issue), loop-until-clean. | [`task-review-tech.md`](task-review-tech.md), [`task-review-issue.md`](task-review-issue.md) |
| **Documentation** | Cierre documental del WorkItem: manuales de usuario (`cream-user-manual`) + OpenAPI/MCP si aplica, escritos **en la rama** y viajando dentro del PR. | [`task-document.md`](task-document.md) |
| **Gate Run** (soporte) | Resultado de una corrida de calidad (rubocop local / CI). | [`gates.md`](gates.md) |

> cream **no** tiene artefacto `Worktree`: el aislamiento del WorkItem es una **rama de feature** (`git switch -c <tipo>/<slug>` desde `main`), no un worktree con puertos/DB propios.

---

## Lifecycle del WorkItem = tablero de milestones

> **Las 8 etapas son *identidades*, no una secuencia numerada.** Una etapa no abre "porque venga después", sino porque su **Guard** es verdad. Los milestones **coexisten** y son **invalidables**; por eso hay loops (`Review.blocker ↺ Implement`) y retrocesos (`Not now ⊘ M-in_progress`). El *recorrido típico* de abajo es el **happy path**. `Document` se escribe en la rama **antes** de abrir el PR en `Submit`.

**Etapas (identidad):** `Intake` · `Understand` · `Implement` · `Validate` · `Review` · `Document` · `Submit` · `Release`.

**Recorrido típico** (happy path de una card nueva):

```
Intake → Understand → Implement → Validate → Review → Document → Submit → Release
                          ↑___________ Review.blocker ___________|
invalidaciones (retroceso): Not now ⊘ in_progress · unassign ⊘ assigned · CI(PR|postmerge) rojo ⊘ *_green
```

**Milestones por etapa:**

```
Intake      M-triaged ─ M-ready(sin dudas) ─ M-assigned ─ M-in_progress / M-deferred
Understand  ⟦Guard[understand]: M-in_progress⟧ ─ M-context_primed ─ M-plan_drafted
Implement   M-implemented ─ M-committed
Validate    M-gates_green_local ─ M-visual_validated ─ M-evidence_captured
Review      M-review_passed                              ⟲ blocker → Implement
Document    M-documented        (en la rama, antes del PR — el doc viaja en el Change)
Submit      M-pr_opened ─ M-ci_pr_green ─ M-merged ─ M-ci_postmerge_green
Release     M-deployed_prod (→ Test, automático) ─ M-verified (→ Done, gate humano)
```

> **Un solo artefacto, no todo el sistema.** Este tablero es la **proyección del `WorkItem`**. Los demás artefactos (`Change`, `Evidence`, `Review`, `Documentation`, `GateRun`) tienen lifecycles propios que avanzan en paralelo y se acoplan por *associations*: p. ej. `Evidence` se captura *mientras* corre `Validate`, y un `GateRun` en rojo invalida el avance de *cualquier* etapa (`Guard[advance_any]`).

El **tablero de Basecamp _es_ la visualización de los milestones**. `In progress` es una **columna composite**: esconde `{Understand, Implement, Validate, Review, Document}` tras un solo milestone (`M-in_progress`). Detalle de columnas/ids/movimientos: [`board.md`](board.md).

| Columna Basecamp (en orden) | Milestone / Etapa |
|---|---|
| `Triage` | M-triaged (Intake) |
| `Not now` | M-deferred (Intake) — parking/hold |
| `TODO` | M-ready (Intake) |
| `Operation` | *carril de ops/mantenimiento, fuera del flujo de desarrollo core* (ver `board.md`) |
| `In progress` | M-in_progress — composite `Understand→Document`; precond. `M-assigned` |
| `Test` | M-deployed_prod (Release) — **automático** tras merge + CI post-merge verde + smoke en prod |
| `Done` | M-verified (Release) — **gate humano**: QA verificada en producción |

---

## Roles × stage × guard

> Las etapas se listan en el **orden típico** (happy path); no son una secuencia rígida — cada una abre por su Guard. Catálogo de realizaciones: [`roles.md`](roles.md).

| Etapa | Rol | Guard que abre | Milestones | Realización |
|---|---|---|---|---|
| Intake | Product Owner | card en `Triage` | M-triaged, M-ready(sin dudas)∨deferred, **reclamar: M-assigned→M-in_progress** | CLI `basecamp` + [`task-triage.md`](task-triage.md) |
| Understand | Backend/Frontend dev | `Guard[understand]`: `M-in_progress` | M-context_primed, M-plan_drafted | **antes**: `basecamp` (reclamar); **luego** `Explore`/`Plan` + `git switch -c` + [`task-plan.md`](task-plan.md) |
| Implement | Backend/Frontend dev | M-plan_drafted ∧ rama de feature | M-implemented, M-committed | subagentes `general-purpose` + skills `cream-architecture`/`cream-dev`/`cream-api`/`cream-mcp` |
| Validate | QA | M-implemented | M-gates_green_local, M-visual_validated, M-evidence_captured | [`task-test.md`](task-test.md), [`task-review-issue.md`](task-review-issue.md), skill `cream-playwright` |
| Review | QA | M-gates_green_local ∧ M-visual_validated | M-review_passed (⟲ blocker→Implement) | [`task-review-tech.md`](task-review-tech.md), subagente `code-reviewer` |
| Document | Documentador | M-review_passed (pre-PR) | M-documented | [`task-document.md`](task-document.md) + skill `cream-user-manual` |
| Submit | Integrador | M-review_passed ∧ M-documented ∧ gates ∧ evidence | M-pr_opened…M-ci_postmerge_green | skill `git` + `gh` |
| Release | PO + Integrador | M-ci_postmerge_green ∧ QA prod | M-deployed_prod (auto→Test), M-verified (→Done) | CLI `basecamp` + skill `cream-playwright` (smoke) |

> 🔴 **REGLA DURA transversal `Guard[advance_any]`**: ningún stage avanza con un `GateRun` bloqueante en rojo. Ver [`gates.md`](gates.md).

---

## Guards por transición

| Guard | Abre / dispara | Condición declarativa |
|---|---|---|
| `Guard[understand]` | Intake → Understand | `M-in_progress` (⇒ `M-assigned` ⇒ `M-ready`): card **asignada** ∧ en **In progress**. **Sin `M-in_progress` NO se abre `Understand`**: nada de primar contexto, explorar código, redactar plan ni crear rama. `M-ready` = criterios de aceptación presentes ∧ **cero preguntas de clarificación pendientes**; con dudas → comentar / `Not now`, **NO** asignar ni mover. En modo card directa `M-issue_created` se satisface trivialmente. |
| `Guard[implement]` | Understand → Implement | `M-plan_drafted` ∧ **rama de feature creada** (`git switch -c <tipo>/<slug>` desde `main` actualizado; `<tipo>` ∈ feat/fix/chore, ver skill `git`). |
| `Guard[validate]` | Implement → Validate | `M-implemented` (código en la rama). |
| `Guard[review]` | Validate → Review | `M-gates_green_local` ∧ `M-evidence_captured` (**siempre**, del tipo adecuado — ver [`evidence.md`](evidence.md)) ∧ `M-visual_validated` (solo si hay cambio visible). |
| `Guard[document]` | Review → Document | `M-review_passed`. El doc/manuales se escriben **en la rama** y viajan dentro del PR. |
| `Guard[open_PR]` | Document → Submit | `M-review_passed` ∧ `M-documented` ∧ `M-gates_green_local` ∧ `M-evidence_captured`. |
| `Guard[merge]` | dentro de Submit | `M-pr_opened` ∧ `M-ci_pr_green` (jobs de CI verdes; `gh pr checks --watch`) ∧ rebase sobre `main` ∧ merge commit (`gh pr merge --merge`, **nunca fast-forward**). Post-merge: borrar la rama (`git push origin --delete <rama>` / `gh pr merge --delete-branch`). 🚦 **gate humano**. |
| `Guard[card→Test]` | association | `M-merged` ∧ `M-ci_postmerge_green` (pipeline de `main` verde tras el merge) ∧ deploy a prod completado ∧ smoke verde. **Automático**, describe la realidad (el cambio ya está en producción). |
| `Guard[card→Done]` | Release | `M-verified` (QA humano validado en **producción**). 🚦 **gate humano**. |

---

## Associations (eventos que se propagan)

### Eventos internos

| Evento | Propaga a |
|---|---|
| `WorkItem.claimed` (tras `M-ready` **sin dudas**) | alcanza `M-assigned` (`basecamp cards update <card> --assignee "$(basecamp me --jq '.data.identity.id')"`) → luego `M-in_progress` (`basecamp cards move <card> --to "In progress"`) — **automático, sin gate humano**, en la cola de `Intake`, **antes de PLANIFICAR**. Idempotente. Con dudas → `Not now`, NO reclamar. `Not now` **invalida `M-in_progress`**; `unassign` invalida `M-assigned`. |
| `Change.merged` | dispara borrado de la **rama** de feature. **No mueve la card.** |
| `M-ci_postmerge_green` (pipeline de `main` verde post-merge) ∧ deploy prod ∧ smoke | `move_card "Test"` — **automático, sin gate humano**: el push a `main` desplegó a producción; el movimiento describe la realidad. |
| `Review.blocker` | invalida `M-review_passed` → `WorkItem.goto(Implement)` (loop) |
| `Evidence.uploaded` | enriquece `Change` (embebe urls/paths en el cuerpo del PR) |
| `WorkItem.verified_prod` (QA humano OK en producción) | `move_card "Done"` + comentar en la card |

### Eventos externos (entradas del motor)

El sistema es **event-driven**: cualquier estímulo externo se interpreta como un evento GSM — alcanza o **invalida** milestones y con ello determina qué guards pueden abrirse. Lista **abierta** (ejemplos de mapeo, no taxonomía cerrada):

| Evento externo | Semántica GSM |
|---|---|
| Nueva card / card lista en Triage | abre `Intake` |
| Petición directa "entrega X" | journey completo desde el estado actual del WorkItem |
| Comentario en el PR pidiendo cambios | `Review.blocker` de origen humano → invalida `M-review_passed`; el trabajo resultante es un **patch acotado** (leer comentario → plan → implementar → validar → push → re-esperar CI), no re-recorrer el lifecycle |
| Pipeline del PR en rojo | invalida `M-ci_pr_green` → diagnóstico + fix en la rama ([`task-resolve.md`](task-resolve.md)) |
| Pipeline post-merge (`main`) en rojo | invalida `M-ci_postmerge_green` → fix-forward con prioridad; **la producción está rota** — la card NO va a Test hasta reverdecer |
| QA en producción rechaza (card en Test) | invalida `M-verified` → card a `Not now` con comentario, o reapertura del trabajo (nuevo patch → PR → merge → redeploy) |
| Conflicto al rebasar sobre `main` | bloquea `Guard[merge]`; si el conflicto no es trivial → gate humano |
| Bug urgente en producción | es el flujo normal acelerado (`main`-first → deploy automático). No hay rama de hotfix; prioriza el patch, mergea, y verifica en prod. Ante duda sobre criticidad → pregunta en la card y PARA |

---

## Verificación observable de milestones

**Un milestone solo se declara alcanzado si se verifica contra un observable del mundo** (comando/API), nunca por memoria de la sesión. El mundo (git, GitHub, Basecamp, filesystem) es la base de datos de estado — no hay tracker local.

| Milestone | Observable |
|---|---|
| `M-ready` | card en `TODO` con criterios de aceptación en su contenido ∧ **cero preguntas de clarificación pendientes** |
| `M-assigned` | card con operador asignado — `basecamp cards show <card>` (`assignees` ≠ []). Requiere `M-ready`. Invalidada **solo por `unassign`** |
| `M-in_progress` | card en la columna **In progress** — `basecamp cards show <card>` (`parent`). Requiere `M-assigned`. **Composite**. Invalidada por `Not now` |
| `M-plan_drafted` | plan publicado como comentario en la card (`basecamp` comment) |
| `M-implemented` / `M-committed` | rama de feature (`git branch --show-current` ≠ `main`) con commits (`git log main..HEAD`) |
| `M-gates_green_local` | ⚠️ efímero: re-ejecutar la secuencia de [`gates.md`](gates.md) (`bin/rubocop` + `bundle exec rspec`) si hay duda |
| `M-visual_validated` | ⚠️ efímero (solo cambio visible): medición con `cream-playwright` (getBoundingClientRect/getComputedStyle), no eyeballing |
| `M-evidence_captured` | **verificación material**: `ls tmp/evidence/<ref>/` contiene ≥1 fichero del tipo adecuado ([`evidence.md`](evidence.md)); tras abrir el PR, además sección `## Evidence` en su cuerpo (`gh pr view --json body`). El relato de la sesión NO cuenta |
| `M-review_passed` | ⚠️ efímero: review sin blockers en esta sesión; si se perdió, re-lanzar review |
| `M-pr_opened` | `gh pr list --head <rama>` |
| `M-ci_pr_green` | `gh pr checks <PR>` |
| `M-merged` | `gh pr view <PR> --json state,mergedAt` |
| `M-ci_postmerge_green` | `gh run list --branch main` (workflows `ci.yml` y `docker.yml` del último merge verdes) |
| `M-documented` | manuales `USER_MANUAL.md`/`MANUAL_USUARIO.md` actualizados (si aplica) + `docs/openapi.yaml` (si toca API), **commiteados en la rama** (viajan en el PR) |
| `M-deployed_prod` | card en `Test` ∧ deploy job de `docker.yml` verde ∧ smoke en `https://crm.entaina.ai/up` OK (skill `cream-playwright`) |
| `M-verified` | card en `Done` ∧ confirmación humana de QA en producción |

> Los milestones marcados ⚠️ son **efímeros** (no dejan rastro fiable en el mundo): ante la duda, re-verificar re-ejecutando es más barato que asumir.

---

## Esqueleto de orquestación (referencia)

```yaml
workflow: deliver_work_item
input: { card_url }
# Las claves de fase son la IDENTIDAD de la etapa (nombre), no un ordinal.
# El orden de abajo es el recorrido típico; cada fase abre por su guard, no por posición.
phases:
  - intake        # rol product-owner (CLI basecamp) + task-triage
      M-ready (criterios ∧ CERO dudas) → move_card "TODO"
      reclamar (SOLO sin dudas): assign_card <operador `basecamp me`> → M-assigned ; move_card "In progress" → M-in_progress
      M-deferred → move_card "Not now"; halt
  - understand    # abre SOLO con Guard[understand]; entonces: primar contexto → Explore/Plan → git switch -c <tipo>/<slug>
      guard: [M-in_progress]
      M-plan_drafted (comentario en la card) → next implement ; gap → goto intake
  - implement     # subagentes general-purpose + skills cream-*
      guard: [M-plan_drafted, rama de feature]
      → M-implemented, M-committed ; next validate
  - validate      # task-test + task-review-issue + cream-playwright
      guard: [M-implemented]; gate: advance_any
      → M-gates_green_local, M-visual_validated, M-evidence_captured ; next review
  - review        # task-review-tech (loop-until-clean, tope 3) + code-reviewer
      guard: [M-gates_green_local, M-visual_validated]
      Review.blocker → invalidate M-review_passed; goto implement
      Review.passed  → M-review_passed; next document
  - document      # task-document + cream-user-manual (en la rama — viaja en el PR)
      guard: [M-review_passed] → M-documented ; next submit
  - submit        # integrador (skill git + gh)
      guard: [M-review_passed, M-documented, M-gates_green_local, M-evidence_captured]
      steps: push → gh pr create --base main --body-file (## Evidence primero — ver evidence.md)
             → gh pr checks --watch (→ M-ci_pr_green)
             → git rebase origin/main (→ push --force-with-lease → re-watch)
             → 🚦 gate humano → gh pr merge --merge --delete-branch (merge commit, NO fast-forward; → M-merged)
             → gh run watch (main: ci.yml + docker.yml) (→ M-ci_postmerge_green + deploy prod)
             → smoke en prod (cream-playwright /up) → move_card "Test"   # automático
      next: [release]
  - release       # product-owner + integrador (CLI basecamp)
      guard: [M-deployed_prod, QA humano en producción]
      verified_prod → 🚦 gate humano → move_card "Done" + comment
```
