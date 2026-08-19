# task-test — Suite de validación de gates de calidad

> Skill-herramienta del motor `adw`. Ejecuta la secuencia canónica de gates de cream y devuelve un reporte estructurado por gate. **Sin estado y sin acciones outward**: solo ejecuta checks y reporta; no commitea, no publica, no muta estado. Consumible por el motor, por un subagente que reciba esta ruta, o standalone.

## Propósito

Replicar localmente los gates de calidad del repo (la secuencia de [`gates.md`](gates.md)) y reportar el resultado de forma estructurada. Es la realización de `M-gates_green_local`.

## Contrato

**Inputs (todos opcionales)**
- `scope` — Path(s) de specs a ejecutar en el gate `rspec` (p. ej. `spec/requests/deals_spec.rb`). Default: suite completa. Los demás gates siempre corren completos.
- `workdir` — Directorio de trabajo. Default: directorio actual (raíz del repo).
- `fail_fast` — Parar al primer gate bloqueante en rojo. Default: `true`.

**Outputs** — Reporte estructurado (JSON en un bloque de código), una entrada por gate:

```json
[
  {
    "gate": "rspec",
    "passed": false,
    "blocking": true,
    "execution_command": "bin/rails db:test:prepare && bundle exec rspec",
    "purpose": "RSpec test suite",
    "failures": [
      {"location": "spec/models/deal_spec.rb:42", "message": "expected true, got false", "reproduce": "bundle exec rspec spec/models/deal_spec.rb:42"}
    ]
  }
]
```

- Gates que pasan: `passed: true`, sin `failures`.
- Gates que fallan: `passed: false` + `failures[]` con fichero:línea (cuando el tool lo da), mensaje relevante y comando mínimo de reproducción.
- Gates no ejecutados por fail-fast: omitidos del array.
- Tras el JSON, una línea de veredicto: `GATES: GREEN` o `GATES: RED (<gate que falló>)`.

**Precondiciones (observables)**
- Working tree del repo (`git rev-parse --show-toplevel` funciona).
- Dependencias instaladas: `bundle check` pasa (si no, avisa y sugiere `bin/setup`).
- Para `rspec`: base de datos de test disponible (Postgres local vía `docker compose up -d`; ver skill `cream-dev`).

## Procedimiento

1. Sitúate en `workdir` y verifica precondiciones. Si alguna falla, repórtalo como precondición incumplida (no como gate en rojo) y para.
2. Ejecuta los gates **en este orden** (fuente de verdad: [`gates.md`](gates.md), que resume `bin/rubocop` local + `.github/workflows/ci.yml`), parando al primer bloqueante en rojo si `fail_fast`:

   | gate | comando | bloquea |
   |---|---|---|
   | `rubocop` | `bin/rubocop` | 🔴 sí (local; no en CI) |
   | `brakeman` | `bin/brakeman --no-pager` | 🔴 sí (job `scan_ruby`) |
   | `bundler_audit` | `bin/bundler-audit` | 🔴 sí (job `scan_ruby`) |
   | `importmap_audit` | `bin/importmap audit` | 🔴 sí (job `scan_js`) |
   | `rspec` | `bin/rails db:test:prepare && bundle exec rspec` (o `bundle exec rspec <scope>` si hay `scope`) | 🔴 sí (job `test`) |

3. Para cada gate registra exit code, y en fallo extrae de la salida las localizaciones `fichero:línea` y el mensaje mínimo útil. No pegues la salida completa: destila.
4. Emite el reporte estructurado y el veredicto final. Nada más: sin commits, sin comentarios, sin movimientos de cards.

## Reglas

- **Fuente de verdad de los gates**: [`gates.md`](gates.md) (que resume `bin/rubocop` y `ci.yml`). Si esta tabla y esos ficheros divergen, gana el repo.
- **Sin acciones outward**: esta skill no publica nada. Quien la invoque decide qué hacer con el reporte.
- **Sin conocimiento del lifecycle**: no razones sobre stages/milestones aquí.
- No "arregles" fallos: reporta. La corrección es de [`task-resolve.md`](task-resolve.md).
- `bin/bundler-audit` puede requerir `bin/bundler-audit update` para refrescar la base de CVEs; si falla por base desactualizada, indícalo.
- **System specs con Capybara** (`type: :system`, Selenium): valídalos en local; requieren la app arrancable. Los request/model specs son la base de la cobertura en CI.
