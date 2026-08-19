# task-resolve — Plan de corrección focalizado

> Skill-herramienta del motor `adw`. Convierte hallazgos concretos (tests en rojo de [`task-test.md`](task-test.md), blockers de review, fallo de CI, comentario de PR pidiendo cambios) en un **plan de patch mínimo**: causa raíz → fix focalizado → ficheros → validación. **Sin estado y sin acciones outward**: solo diagnostica y planifica; no implementa, no commitea, no publica. Consumible por el motor, por un subagente que reciba esta ruta, o standalone.

## Contrato

**Inputs**
- `hallazgos` (obligatorio) — Lo que hay que resolver, en cualquier forma: reporte JSON de `task-test` (`passed: false` + `failures[]`), veredicto de review con blockers/checks en FAIL, log/resumen de un fallo de CI, texto de un comentario de PR, o un path a un fichero con cualquiera de esos.
- `contexto` (opcional) — Contexto del cambio original: plan, descripción de la card, screenshots. Mejora el diagnóstico.
- `output_path` (opcional) — Dónde escribir el plan. Default: emitirlo íntegro en la respuesta.

**Outputs** — Plan de patch estructurado:

```md
# Resolve: <resumen de qué se corrige>

## Hallazgos
### 1. <nombre>
- **Fuente**: <test | review | CI | comentario PR> · **Severidad**: <blocker | should-fix | nit>
- **Síntoma**: <error/descripción tal como llegó>
- **Causa raíz**: <diagnóstico tras investigar, no una paráfrasis del síntoma>
- **Tipo de fix**: mecánico | ⚠️ decisión de diseño (escalar al humano)

## Ficheros a Modificar
<paths REALES verificados en el repo, con qué cambiar en cada uno>

## Pasos de Implementación
### Paso 1: <acción concreta y mínima>
...

## Validación
<por cada fix: comando o comprobación que demuestra que está resuelto, p. ej. `bundle exec rspec spec/models/deal_spec.rb:42`>

## Alcance
Riesgo: <bajo|medio|alto> · Hallazgos escalados sin resolver: <N o "ninguno">
```

**Precondiciones (observables)** — Estar en el working tree del cambio (`git rev-parse --show-toplevel` funciona; `git diff origin/main...HEAD` muestra el cambio original, si existe).

## Procedimiento

1. **Parsear los hallazgos**: identifica el formato y extrae cada problema (nombre, error, severidad, comando de reproducción si viene). De un review: los `blocker` y checks en FAIL entran siempre al plan; los `should-fix` se planifican o se documenta por qué se aplazan (nunca se ignoran en silencio); los `nit` se pueden posponer.
2. **Diagnosticar causa raíz ANTES de proponer nada**. Por cada hallazgo:
   - Reproduce el fallo si es posible (ejecuta el test/comando que falla).
   - Lee los ficheros implicados y usa `git diff origin/main...HEAD --stat` para acotar qué introdujo el cambio original.
   - Piensa a fondo hasta explicar *por qué* falla, no solo *qué* falla.
3. **Clasificar cada hallazgo**:
   - **Mecánico**: fix objetivo y acotado (typo, scope de workspace mal aplicado, assertion desalineada, policy que falta…). Entra al plan con pasos concretos.
   - **Decisión de diseño**: resolverlo implica elegir entre alternativas con trade-offs (cambiar un contrato, alterar UX, relajar una validación…). Se documenta con las opciones y se marca ⚠️ para escalar; NO se decide aquí.
4. **Generar el plan** siguiendo el formato: el plan más pequeño que resuelve los hallazgos mecánicos, con paths verificados (Glob/Read, nunca inventados) y validación por fix.
5. **Emitir**: escribe en `output_path` si se dio; si no, devuelve el plan + un resumen de una línea: `RESOLVE: <N> hallazgos, <M> planificados, <K> escalados`.

## Reglas

- **Patch FOCALIZADO**: resuelve exclusivamente los hallazgos recibidos. Nada de mejoras, refactors oportunistas ni cambios adyacentes — eso es un WorkItem aparte.
- **Arregla el código, no los tests** — salvo que el test sea nuevo y esté objetivamente mal escrito (y en ese caso, justifícalo en la causa raíz).
- **No inventes paths ni convenciones**: todo fichero del plan debe existir (verificado) o declararse como fichero nuevo con ubicación justificada por las convenciones de cream (skill `cream-architecture`).
- **Las decisiones de diseño se escalan, no se toman**: el plan las presenta con opciones y recomendación, pero quien invoca (humano u orquestador con gate humano) decide.
- **Sin acciones outward**: no implementa, no commitea, no comenta, no muta trackers. Solo diagnóstico + plan.
- **Sin conocimiento del lifecycle GSM**: el orquestador decide qué hacer con el plan (típicamente pasarlo a un subagente de implementación).
