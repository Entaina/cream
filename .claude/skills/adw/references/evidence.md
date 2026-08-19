# Evidence — contrato de evidencia tipada

Prueba de que el **Change** (=PR) hace lo que dice. **Todo PR lleva evidencia**; el *tipo* (visual, textual o ambos) lo dicta la naturaleza del cambio. Se persiste SIEMPRE como **ficheros** en `tmp/evidence/<ref>/` (donde `<ref>` = id de card / nº de PR), replica los **medios binarios** en **Cloudflare R2** y se embebe en la sección `## Evidence` del cuerpo del PR — la misma prueba, tres representaciones. La produce QA (visual + textual) en `Validate` ([`task-review-issue.md`](task-review-issue.md)); la consume el Integrador al abrir el PR.

> `tmp/evidence/` está gitignored (cae bajo la regla `/tmp/*` de `.gitignore`) — la evidencia no se commitea; se sube a R2 (binarios) o se embebe como texto en el PR.

## Taxonomía: tipo de evidencia según el cambio

El *tipo* lo dicta la naturaleza del cambio — esta ficha es su autoridad:

| Naturaleza del cambio | Tipo | Formato |
|---|---|---|
| UI / cambio visible (vistas, componentes, layouts, Turbo, Stimulus, design-system) | **Visual** | 1–5 screenshots `.png` + vídeo `.webm` solo si aporta |
| Backend sin superficie visible (jobs, servicios, modelos, migraciones, mailers, logging, config, performance, API/MCP) | **Textual** | output real de comandos en `.txt`/`.md`/`.json`: extracto de log, corrida de tests roja→verde, `bin/rails runner`, respuesta `curl`, consulta SQL antes/después |
| Mixto (feature con UI + comportamiento de fondo) | Ambos | combinar |

No existe el cambio "sin evidencia posible": si el cambio es real, algún observable del mundo lo demuestra. **Excepción única**: chores sin comportamiento observable (tooling puro, docs); en ese caso la sección `## Evidence` del PR declara explícitamente por qué no aplica — esa declaración ES la evidencia.

## Captura (dónde y cómo)

Directorio: `mkdir -p tmp/evidence/<ref>`. Ficheros numerados `01_<descripcion>.<ext>` (la descripción identifica el criterio de aceptación que cubre).

- **Visual** — skill `cream-playwright` (`pw`): login con seed (`CREAM_SEED_ADMIN_EMAIL`/`CREAM_SEED_ADMIN_PASSWORD` desde `.env`, en `/session/new`), `pw screenshot --filename tmp/evidence/<ref>/01_<desc>.png`. **Medir, no eyeballing** (`getBoundingClientRect()`/`getComputedStyle()` vía `pw`); el screenshot es para el humano, el veredicto sale de valores medidos. Un screenshot sin `--filename` vuelve inline y **no cuenta** como evidencia.
- **Textual** — redirigir el output **real** a fichero con `tee`/`>`, recortado a lo relevante y con secretos redactados:
  ```bash
  bundle exec rspec spec/<ruta> 2>&1 | tee tmp/evidence/<ref>/01_rspec_regression.txt
  bin/rails runner '<snippet>' 2>&1  | tee tmp/evidence/<ref>/02_runner_output.txt
  curl -s http://localhost:3000/<endpoint> | tee tmp/evidence/<ref>/03_api_response.json
  ```

## Subida a R2 (solo binarios)

Los **medios binarios** (png/jpg/webp/gif/webm/mp4) se replican en R2 con key `adw/<ref>/<basename>`; la **evidencia textual NO pasa por R2**, se embebe como bloque de código en el PR.

```bash
.claude/skills/adw/scripts/evidence-r2.sh status                                   # "R2 enabled …" (exit 0) o la var que falta (exit 3)
.claude/skills/adw/scripts/evidence-r2.sh upload <ref> tmp/evidence/<ref>/*.png tmp/evidence/<ref>/demo.webm
```

`upload` sube cada fichero e imprime `<basename>\t<url>` por **stdout** (una línea por fichero). Las credenciales `CLOUDFLARE_R2_*` viven en `.env` (gitignored) y el script las carga en su proceso, **no en el shell** — por eso `echo $CLOUDFLARE_R2_*` sale vacío por diseño. **Nunca concluyas "R2 disabled" desde el shell: pregúntaselo al comando** (`status`, exit 3). Detalle del uploader: [`../scripts/evidence-r2.sh`](../scripts/evidence-r2.sh).

## Embeber en el cuerpo del PR

La sección `## Evidence` es **obligatoria en todo PR** y va **antes de `## Changes`**. La monta el Integrador al abrir el PR (`Submit`) leyendo `tmp/evidence/<ref>/` y las URLs de R2 que reportó [`task-review-issue.md`](task-review-issue.md) — nunca se reconstruye de memoria. Plantilla:

~~~markdown
## Evidence

<!-- Visual: imagen embebida por URL de R2 (o path local si R2 está deshabilitado) -->
![<descripción de la captura>](<url_png>)

[▶ Watch demo (WebM, ~<N>s)](<url_webm>)
- **<capítulo 1>** — <qué demuestra>

<!-- Textual: bloque de código con el output real, citando el fichero de origen -->
**<qué demuestra>** (`tmp/evidence/<ref>/01_rspec_regression.txt`):

```text
<extracto relevante del output>
```
~~~

Reglas de montaje (no bloqueantes):

- **R2 deshabilitado o subida fallida** → NO bloquees el PR: sustituye el enlace por `` Evidence recorded locally at `tmp/evidence/<ref>/<file>` (R2 disabled) `` y déjalo dicho en el resumen. La evidencia textual nunca depende de R2.
- **Grabación de vídeo interrumpida** → añade `> ⚠️ Recording stopped early; some acceptance criteria are not covered.`
- **Cambio sin observable** (chore de tooling puro, docs) → la sección dice `No observable behavior change — <motivo>` (esa declaración ES la evidencia).
- 🔴 **Nunca** embebas datos sensibles de cuentas reales ni secretos: usa seeds de desarrollo y redacta tokens en cualquier extracto.

**Verificación tras abrir** (observable de `M-evidence_captured`): `gh pr view <PR> --json body` contiene la sección `## Evidence` — el relato de la sesión no cuenta.

## Notas

- 🔴 **Regla material** (autoridad de esta ficha): una evidencia solo existe si es un **fichero** en `tmp/evidence/<ref>/`. Un screenshot visto inline, una medición en prosa o un output no persistido **no cuentan** como evidencia — cuentan como *validación* (`M-visual_validated`, otro milestone). `M-evidence_captured` se verifica contra el filesystem (`ls tmp/evidence/<ref>/`) y el cuerpo del PR, **nunca** contra el relato de la sesión.
- **Output textual real, nunca reconstruido de memoria**; recorta a lo relevante (decenas de líneas, no miles).
- 🔴 **NUNCA** subas datos sensibles de cuentas reales ni secretos: usa los usuarios seed de desarrollo (skill `cream-dev`) y **redacta tokens** en cualquier extracto.
- **R2 no bloquea**: si está deshabilitado o la subida falla, el PR referencia el path local (`tmp/evidence/<ref>/<file>`) y sigue adelante. La evidencia textual nunca depende de R2.
