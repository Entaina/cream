# task-document — Documentación de cierre de un cambio

> Skill-herramienta del motor `adw`, realización del rol Documentador. Produce la documentación que cierra un cambio **en la rama**, de modo que viaja dentro del PR y se revisa/mergea con el código. **Solo documenta y reporta**: escribe ficheros de doc en el working tree (acción local permitida), pero no commitea, no publica fuera del repo, no mueve cards. Consumible por el motor (tras el review, antes del PR), por un subagente que reciba esta ruta, o standalone.

## Qué documenta cream (no `docs/history/changes/`)

A diferencia de brainsome, cream **no** usa `docs/history/changes/`. La documentación de cierre en cream son los artefactos vivos que cambian cuando cambia la funcionalidad — codificado en `cream-architecture § Finishing a change`:

| Si el cambio… | Documenta en | Skill |
|---|---|---|
| es **visible al usuario** (pantallas, menús, flujos, permisos en la UI) | `USER_MANUAL.md` (EN) **y** `MANUAL_USUARIO.md` (ES) | `cream-user-manual` |
| añade/modifica **REST API v1** (`app/controllers/api/v1/`) | `docs/openapi.yaml` (en el mismo PR) | `cream-api` |
| añade/modifica **tools o OAuth MCP** | doc/convenciones MCP | `cream-mcp` |
| es puramente interno (refactor, tooling, sin superficie de usuario/API/MCP) | *no requiere doc* — decláralo | — |

## Contrato

**Inputs**
- `cambio` (opcional) — Qué documentar. Default: **el cambio de la rama actual contra `origin/main`** (`git diff origin/main...HEAD`). Acepta también un nº de PR o rango de commits para documentación retroactiva.
- `contexto` (opcional) — Contexto del WorkItem (título, plan, evidencias, review) para enmarcar requisitos vs lo construido, nunca como sustituto del diff real.
- `workdir` (opcional) — Default: raíz del repo.

**Outputs**
- Ediciones en los ficheros de doc que correspondan (manuales EN+ES, OpenAPI, MCP) según la tabla de arriba, **coherentes entre sí** (la entrada EN y la ES describen lo mismo).
- Reporte final: qué ficheros se tocaron y un resumen de una línea. Si el cambio no requiere doc, decláralo explícitamente con el motivo (esa declaración es la salida).

**Precondiciones** — Hay un cambio real que documentar (diff no vacío de la rama contra `main`, o el PR/rango indicado existe). Working tree del repo disponible.

## Procedimiento

1. Resuelve el cambio: por defecto la rama actual (`git diff origin/main...HEAD`); si se indicó PR (`gh pr view/diff`) o rango, ese. Verifica que el diff no está vacío.
2. Analiza el cambio **real**: `git diff <base>...<head> --stat` y `--name-only`; lee los diffs concretos de los ficheros significativos. Nunca documentes de memoria ni desde el `contexto` sin contrastar con el diff.
3. **Decide qué documentar** con la tabla de "Qué documenta cream": ¿toca UI visible? ¿API? ¿MCP? Puede ser más de uno.
4. **Ejecuta la documentación siguiendo la skill correspondiente**:
   - UI visible → skill `cream-user-manual`: actualiza `USER_MANUAL.md` y `MANUAL_USUARIO.md` (ambos, en paralelo y coherentes) con la funcionalidad nueva/cambiada, en el estilo y estructura existentes de esos ficheros.
   - API → skill `cream-api`: actualiza `docs/openapi.yaml` con los endpoints nuevos/modificados en el mismo PR.
   - MCP → skill `cream-mcp`: documenta los tools/OAuth afectados.
   - Concisión: documenta **decisiones y uso**, no re-narres el código; prefiere listas y tablas sobre párrafos largos.
5. Reporta los ficheros tocados. Nada más.

## Reglas

- **Diff real como fuente de verdad**: la documentación describe el cambio verificado con git (la rama, el PR o el merge), no lo que el plan decía que se construiría.
- **Manuales siempre en pareja**: si tocas `USER_MANUAL.md`, toca también `MANUAL_USUARIO.md` (y viceversa) — deben quedar consistentes. Es parte del checklist del `PULL_REQUEST_TEMPLATE.md` de cream.
- **Sin acciones outward**: escribir en los ficheros de doc del repo es acción local permitida. No comentes en GitHub/Basecamp, no muevas cards, no commitees — eso es del orquestador/Integrador.
- **Sin conocimiento del lifecycle GSM**: aquí solo se comprueba la precondición observable (hay un diff que documentar); los guards los verifica el consumidor.
- **Un cambio, coherencia**: no dupliques contenido; si el cambio toca un área ya documentada, actualízala en lugar de añadir secciones redundantes.
