# task-review-issue — Revisión contra requisitos con evidencia tipada

> Skill-herramienta del motor `adw`, realización de la mitad de **aceptación** del artefacto Review. Verifica, criterio a criterio y contra el **sistema real corriendo**, que la implementación cumple los criterios de aceptación del WorkItem, capturando [evidencia](evidence.md) tipada. **Solo verifica y reporta**: no aprueba, no mueve cards, no comenta, no gestiona estado. La **única acción outward** es subir binarios de evidencia a R2. Consumible por el motor, por un subagente que reciba esta ruta, o standalone.

> 🔴 **Regla material** ([`evidence.md`](evidence.md)): una evidencia solo existe si es un **fichero en `tmp/evidence/<ref>/`**. Un screenshot inline, una medición en prosa o un output no redirigido a fichero son *validación*, no *evidencia*. Antes de emitir el reporte, verifica con `ls tmp/evidence/<ref>/` que los ficheros existen.

## Contrato

**Inputs**
- **Criterios de aceptación**: texto de la card o lista pasada en el prompt. Si solo se recibe una referencia (id de card), obtener el texto de la fuente antes de empezar.
- **Cambio a verificar**: por defecto la rama actual (`git diff origin/main...HEAD`).
- **Ref de evidencia** (opcional): identificador para nombrar el directorio (id de card / nº PR). Si no se da, derivar del nombre de la rama.

**Outputs**
- **Veredicto por criterio**: `cumplido` | `no cumplido` | `no verificable` (con motivo), cada uno con la evidencia/medición que lo sustenta.
- **Evidencias capturadas**: ficheros bajo `tmp/evidence/<ref>/` (verificados con `ls`), URLs públicas de R2 para binarios cuando la subida procede, y el extracto textual listo para el bloque `## Evidence` del PR.
- **Resumen** (2-4 frases) + veredicto global: PASS si ningún criterio queda `no cumplido` con severidad blocker.

**Precondiciones observables**
- App arrancable (`bin/dev`, o `bin/rails server` con el Postgres de `docker compose` levantado; ver skill `cream-dev`).
- Para evidencia **visual**: skill `cream-playwright` (`pw`). Para evidencia **textual** no se necesita.

**Acciones outward**: únicamente la subida de binarios de evidencia a R2 vía [`../scripts/evidence-r2.sh`](../scripts/evidence-r2.sh). Nada más sale del entorno local.

## Procedimiento

1. **Cargar criterios, cambio y tipo de evidencia.** Obtener el texto de los criterios. `git diff origin/main...HEAD --stat` para conocer el alcance y **decidir el tipo de evidencia** ([`evidence.md § taxonomía`](evidence.md)): visible (vistas/componentes) → visual; backend sin UI (jobs, servicios, modelos, migraciones, mailers, API/MCP) → textual; mixto → ambos. `mkdir -p tmp/evidence/<ref>`.

2. **Arrancar la app** si la verificación la necesita. Verificar que responde (`curl -sf http://localhost:3000/up`); si no, arrancarla (`bin/dev`). Anotar el puerto real.

3. **Autenticarse** *(solo verificación visual)* con el usuario seed de desarrollo desde `.env` (skill `cream-playwright`):
   ```bash
   set -a && source .env && set +a
   pw() { npx -y @playwright/cli@latest "$@"; }
   pw open; pw resize 1440 900
   pw goto "$CREAM_APP_URL/session/new"
   pw fill "Email textbox" "$CREAM_SEED_ADMIN_EMAIL"
   pw fill "Password textbox" "$CREAM_SEED_ADMIN_PASSWORD"
   pw click "Sign in button"
   ```

4. **Verificar criterio a criterio** contra el sistema real:
   - **Visual**: navega a la ruta real (`/`, `/people`, `/companies`, `/deals`, `/deals/board`, `/tasks`, …). **Medir, no eyeballing**: geometría con `getBoundingClientRect()`, estilos con `getComputedStyle()`, altura con `scrollHeight` — el screenshot es para el humano, el veredicto sale de valores medidos. Revisa consola y red (errores JS, 404).
   - **Textual**: ejercita el comportamiento de verdad — corre el spec de regresión (ideal: rojo sin el fix / verde con él), ejecuta el servicio/job con `bin/rails runner`, golpea el endpoint con `curl`, provoca la línea de log. El veredicto sale del output real, nunca de leer el código.

5. **Capturar evidencias visuales** en `tmp/evidence/<ref>/` *(solo si hay cambio visible)*: 1-5 screenshots alineados con los criterios, `01_<descripcion>.png`. `--filename` es obligatorio:
   ```bash
   pw goto "$CREAM_APP_URL/<ruta>"
   pw screenshot --filename tmp/evidence/<ref>/01_<descripcion>.png
   ```
   **Vídeo demo** solo cuando aporta (flujo end-to-end, ≈30-90s) — ver skill `cream-playwright` para la API de vídeo si está disponible.

6. **Capturar evidencias textuales** en `tmp/evidence/<ref>/`: redirigir el output **real** a fichero con `tee`/`>`, recortado y con secretos redactados:
   ```bash
   bundle exec rspec spec/<ruta> 2>&1 | tee tmp/evidence/<ref>/01_rspec_regression.txt
   bin/rails runner '<snippet>' 2>&1  | tee tmp/evidence/<ref>/02_runner_output.txt
   ```

7. **Subir binarios a R2** con el uploader de la skill (la evidencia textual NO pasa por R2 — se embebe como bloque de código en el PR). **Nunca concluyas "R2 disabled" desde el shell: pregúntaselo al comando.**
   ```bash
   .claude/skills/adw/scripts/evidence-r2.sh status                                    # exit 0 = habilitado / exit 3 = falta una var
   .claude/skills/adw/scripts/evidence-r2.sh upload <ref> tmp/evidence/<ref>/*.png tmp/evidence/<ref>/demo.webm
   ```
   `upload` sube cada fichero a `adw/<ref>/<basename>` e imprime `<basename>\t<url>` por stdout (una línea por fichero).

8. **Verificar materialmente y emitir el reporte.** Cierra la sesión de `pw` (`pw close`). Comprueba `ls tmp/evidence/<ref>/` — si está vacío, la captura FALLÓ aunque la validación haya ido bien: repítela antes de reportar. Emite: veredicto por criterio con su evidencia/medición, lista de evidencias (path local verificado + URL R2 si existe + extractos textuales), resumen y veredicto global.

## Reglas

- **Verificación adversarial**: intenta REFUTAR cada criterio. Un criterio sin evidencia observable se reporta `no verificable` con el motivo — nunca se da por cumplido por lectura del código.
- **Evidencia siempre, del tipo adecuado**: no hay revisión sin ficheros en `tmp/evidence/<ref>/`. Si el cambio genuinamente no tiene comportamiento observable (chore de tooling puro, docs), repórtalo como `no observable — <motivo>` para que el PR lo declare en `## Evidence`.
- **Severidad**: enum canónico `blocker | should-fix | nit` ([`task-review-tech.md`](task-review-tech.md)). PASS solo sin blockers.
- **R2 no bloquea, pero verifica antes de descartarlo**: `R2 disabled` solo es válido si `evidence-r2.sh status` devolvió exit 3; **nunca lo infieras del shell** (`$CLOUDFLARE_R2_*` está vacío por diseño). `upload failed` solo tras ejecutar el upload. En cualquiera de esos casos reporta las evidencias con paths locales y señálalo en el resumen. La evidencia textual nunca depende de R2.
- **Fallos de captura no abortan**: si `pw` no está o una navegación falla, continúa con el resto de criterios, reporta los afectados como `no verificable` y deja constancia del motivo.
- **Solo datos seed, sin secretos**: nunca captures evidencias con datos de cuentas reales; usa los usuarios seed (skill `cream-dev`). Redacta tokens/credenciales en cualquier extracto de log.
- **Sin efectos colaterales**: no comentes, no muevas cards, no apruebes/rechaces. El único output persistente son las evidencias en `tmp/evidence/<ref>/` (y su copia en R2) y el reporte devuelto.
