---
name: adw
description: >
  Motor de desarrollo GSM/event-driven para el CRM cream. Recibe un EVENTO (card de Basecamp,
  comentario o estado de un PR, CI en rojo, o petición libre "entrega X"), carga el contrato de
  desarrollo de `references/`, infiere el estado GSM del WorkItem desde observables del mundo
  (Basecamp, git, gh, filesystem) y SINTETIZA su propia orquestación —workflows dinámicos,
  subagentes o ejecución inline— para reaccionar, con gates humanos en las acciones outward de
  decisión (merge, mover card a Done). Actívala cuando el usuario quiera entregar/desarrollar una
  card, reaccionar a feedback de un PR o a un fallo de CI, retomar un WorkItem a medias, orquestar
  el flujo de desarrollo, o escriba `/adw`.
compatibility: Diseñada para Claude Code; requiere git, gh y los CLIs basecamp, playwright-cli y aws (este último solo para subir evidencia a R2).
metadata:
  version: "1.0"
  origin: "portada desde brainsome-rails/.claude/skills/adw"
---

# adw — motor del flujo de desarrollo (GSM, event-driven)

No eres un guion: eres un **motor GSM**. El contrato en [`references/contract.md`](references/contract.md) define la **física** del sistema (artefactos, guards, milestones, associations, invariantes); tú recibes un **evento**, percibes el estado real del WorkItem y **diseñas la orquestación que ese evento necesita**. El camino nunca está preconfigurado: una card nueva, un comentario en un PR y un pipeline en rojo entran por el mismo motor y producen workflows distintos.

> 🔴 **REGLA CERO**: el contrato manda. Ante cualquier duda de columnas, milestones, comandos o convenciones, consulta `references/` y el repo; nunca inventes. Si detectas una contradicción entre esta skill y el contrato, gana el contrato — y repórtala al usuario.

**Input**: un evento — cualquier query. Ejemplos concretos evento→reacción:

- **Card nueva en `Triage`** → triar readiness; si está lista y sin dudas, reclamar (asignar + In progress) y entregar hasta el PR.
- **Comentario de change-request en un PR** → `Review.blocker`: patch acotado (leer → plan → implementar → validar → push → re-esperar CI), no re-recorrer el lifecycle.
- **Pipeline de `main` en rojo tras un merge** → fix-forward prioritario (producción rota); la card no pasa a `Test` hasta reverdecer.

La semántica GSM completa (milestones que cada evento alcanza o invalida) y la lista abierta están en [`contract.md § Eventos externos`](references/contract.md#eventos-externos-entradas-del-motor): eventos nuevos se interpretan contra el contrato.

**Alcance**: una invocación = **un WorkItem**. cream no tiene worktrees aislados (`bin/trees`): cada WorkItem vive en una **rama de feature** desde `main` (`git switch -c <tipo>/<slug>`); varios WorkItems conviven como ramas/PRs distintos.

---

## El ciclo del motor

### 1 · Cargar (contrato + capacidades)

- **Contrato** (Always Read): [`contract.md`](references/contract.md) — la física GSM (stages, milestones, guards, associations, invariantes, verificación observable, modos de operación). Carga los ficheros **Conditional** según el área que toque el evento (ver más abajo).
- **Capacidades**: el catálogo vive en [`roles.md`](references/roles.md); mapea cada servicio a su realización (subagente, skill, CLI). Crúzalo con las skills y subagentes disponibles en tu sesión y los CLIs del repo (`gh`, `basecamp`, `aws`, `pw`). No asumas que una herramienta existe: verifícala en el catálogo o en la sesión.

**Conditional** (carga según el área del evento):
- Intake / aceptación / movimiento de cards → [`board.md`](references/board.md), [`task-triage.md`](references/task-triage.md).
- Planificación / implementación → [`task-plan.md`](references/task-plan.md), [`task-resolve.md`](references/task-resolve.md), skills `cream-architecture`/`cream-dev`.
- Validación / review → [`gates.md`](references/gates.md), [`evidence.md`](references/evidence.md), [`task-test.md`](references/task-test.md), [`task-review-tech.md`](references/task-review-tech.md), [`task-review-issue.md`](references/task-review-issue.md).
- Ops / merge / CI post-merge / deploy → [`gates.md`](references/gates.md), [`board.md`](references/board.md), skill `git`, `gh`.
- Cierre / documentación → [`task-document.md`](references/task-document.md), skill `cream-user-manual`.

### 2 · Percibir (evento → estado GSM)

- **Normaliza el evento**: ¿a qué WorkItem apunta (card, rama, PR)? ¿qué milestone alcanza o invalida? Si el evento es ambiguo o le falta contexto, PARA y pregunta antes de actuar.
- **Infiere los milestones desde el mundo**, nunca de memoria ni de trackers: columna de la card (`basecamp cards show`), `git log`/`git branch`, `gh pr list/view/checks`, `gh run list`. Mapeo milestone→observable: [`contract.md § Verificación observable`](references/contract.md#verificación-observable-de-milestones). Los milestones ⚠️ efímeros (gates locales, review) se re-verifican re-ejecutando.
- No repitas trabajo que el mundo ya acredita (plan comentado en la card, PR abierto, evidencias subidas).
- 🔴 **Percibir es leer ESTADO GSM (card/git/GitHub/filesystem), NO primar contexto de `Understand`.** Explorar código de la aplicación (controladores/vistas/nav) para diseñar el CAMBIO **ya es planificar `Understand`**, y `Understand` **no abre sin `Guard[understand]`** (`M-in_progress` ⇒ card asignada + en In progress). Al confirmar `M-ready` **sin dudas** y comprometerte a implementar, **reclama** el WorkItem (asignar → `M-assigned`, mover a In progress → `M-in_progress`) **antes** de tocar código de la app. Con dudas → comentar / `Not now`, **NO** reclamar.

### 3 · Deliberar (síntesis de la orquestación)

- Con estado + evento, evalúa **qué guards pueden abrirse** y fija el **objetivo de quiescencia**: el punto más lejano alcanzable sin gate humano (con los [Modos de operación](references/contract.md#modos-de-operación) por defecto: hasta abrir el PR, o hasta resolver el evento si es más acotado).
- **Elige la forma del trabajo** — es una paleta, no una prescripción: inline (mover una card no necesita workflow), un subagente único (un patch pequeño), o un **workflow dinámico** — el mecanismo por defecto para trabajo sustantivo; ver la sección siguiente.
- Anuncia el plan: evento interpretado, estado inferido, orquestación elegida y dónde está el próximo gate humano.

### Workflows dinámicos (Workflow tool)

Esta skill te **autoriza e instruye a usar el Workflow tool**: es el motor de ejecución preferente para el núcleo autónomo de cualquier evento sustantivo (entender, implementar, validar, revisar). No hay script `.js` versionado — **sintetiza el script en tiempo de ejecución** a partir del estado GSM y del objetivo de quiescencia de esta invocación.

- **Formas de orquestación** (elige por la estructura del trabajo, no por costumbre): `parallel` para fan-out (lectura de contexto, review adversarial por dimensiones), `pipeline` para capas en orden (rutas→controladores→jobs→servicios→front→vistas), loop-until-clean para review (con su tope de 3), loop-until-dry para descubrimiento de tamaño desconocido.
- **Los subagentes consumen las skills-herramienta** `references/task-*.md`: pásales en el prompt la ruta a seguir (p. ej. "sigue las instrucciones de `.claude/skills/adw/references/task-review-tech.md`, dimensión: seguridad") — son markdown en disco, legibles aunque el subagente no tenga el Skill tool. El `agentType` de cada servicio sale de [`roles.md`](references/roles.md).
- **Los esperas van en el bucle principal, no dentro del workflow**: `gh pr checks --watch`, `gh run watch` (loop-until-green) los ejecutas tú entre workflows, porque marcan puntos de re-percepción y posibles gates.
- 🔴 **Nada outward dentro de un workflow** (merge, borrado de rama, movimientos de card, deploy): el Workflow tool no hace pausas interactivas; esas acciones van en el bucle principal tras su gate humano.
- Los resultados del workflow no son verdad: al terminar, **re-percibe** y verifica los milestones contra sus observables.

### 4 · Ejecutar y verificar

- Ejecuta la orquestación. Tras cada unidad de trabajo, **re-percibe**: verifica el milestone contra su observable antes de darlo por alcanzado.
- Itera hasta la **quiescencia**: ningún guard puede abrirse sin input humano → para y reporta el gate pendiente.
- **Topes y escaladas** (fuera de gate): loop de review sin converger tras **3 iteraciones** → escala con el estado del loop; CI que falla por causa ajena al cambio → **1 relanzamiento** y si reincide es rojo real; conflictos de rebase no triviales → gate humano; fallo de subida a R2 → no bloquea, continúa con paths locales y señálalo ([`evidence.md`](references/evidence.md)).

---

## Invariantes (la física — nunca se sintetizan)

> 🔴 **`Guard[advance_any]`**: nada avanza (ni commit, ni push, ni PR, ni merge) con un gate bloqueante en rojo. Gates de cream en [`gates.md`](references/gates.md): `bin/rubocop` local + los jobs de CI (`scan_ruby`, `scan_js`, `test`).
> 🔴 **Gates humanos en las acciones outward de decisión**: merge (rebase sobre `main` + merge commit, ver [`board.md`](references/board.md) y skill `git`), movimiento de card a `Done`. **Excepción por contrato**: push a `main` despliega a **producción** y la card→`Test` es una association **automática** tras `M-ci_postmerge_green` + smoke — el movimiento describe la realidad. Todo lo demás corre autónomo.
> 🔴 **Nada outward dentro de un workflow autónomo** (merge, borrado de rama, movimientos de card): el Workflow tool no pausa; esas acciones van en el bucle principal, tras su gate.
> 🔴 **Milestone no verificado = milestone no alcanzado.** El mundo es la base de datos de estado.
> 🔴 **`Guard[understand]`: el desarrollo no abre sin `M-in_progress`.** Primar contexto, explorar código, redactar el plan o crear la rama son `Understand` — **prohibidos hasta que la card esté asignada (`M-assigned`) ∧ en In progress (`M-in_progress`)**, que a su vez exigen `M-ready` **sin dudas** (criterios ∧ `delivery_path` decidido ∧ cero preguntas de clarificación). No es un paso de plan a recordar: es un **guard sobre un estado observable**, se comprueba como cualquier otro. Con dudas → `Not now`, NO reclamar. Ver [`contract.md`](references/contract.md).
> 🔴 Comandos y mecánica (rama, merge, borrado, columnas) se **leen del contrato y sus referencias**, no se improvisan.

---

## Reporte

Al alcanzar la quiescencia (o al parar en un gate o escalar), reporta estos 4 puntos:

- **Evento** — cómo se interpretó y sobre qué WorkItem (card/rama/PR).
- **Estado GSM** — milestones alcanzados, cada uno verificado contra su observable.
- **Artefactos** — plan (comentario en la card), PR + URL, evidencias (R2/locales), doc/manuales.
- **Próximo gate** — la siguiente acción outward que espera decisión humana (merge, card→Done), o "ninguno" si se cerró.

Si escalaste (review sin converger, conflicto de rebase, CI rojo persistente), añade qué se intentó y qué decisión necesitas.
