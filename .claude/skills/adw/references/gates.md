# Gates de calidad de cream — autoridad de `Guard[advance_any]`

> 🔴 **REGLA DURA — `Guard[advance_any]`**: ningún stage avanza (ni commit, ni push, ni PR, ni merge) si algún `GateRun` **bloqueante** está en rojo. Se evalúa en *toda* transición. Este fichero es la **fuente de verdad** de qué gates existen y cuáles bloquean; su origen son `.rubocop.yml`/`bin/rubocop` (local) y [`.github/workflows/ci.yml`](../../../../.github/workflows/ci.yml) (CI). Si esta tabla y esos ficheros divergen, gana el repo — y repórtalo.

cream **no usa overcommit ni pre-commit hooks**: los gates locales se ejecutan a mano. RuboCop **no corre en CI** (es solo local); la seguridad y los tests **sí** corren en CI.

## Gate local (bloqueante, antes de commit)

| gate | comando | bloquea | notas |
|---|---|---|---|
| `rubocop` | `bin/rubocop` (autofix: `bin/rubocop -a`) | 🔴 sí (local) | hereda `rubocop-rails-omakase`. Convención de cream: **al terminar cada cambio, correr lint local y arreglar antes de commitear** (skills `cream-dev` y `cream-architecture § Finishing a change`). No está en CI, así que es responsabilidad del flujo local. |

## Gates de CI (`ci.yml` — bloqueantes; corren en `pull_request` y en `push` a `main`)

| job | pasos / comando | bloquea |
|---|---|---|
| `scan_ruby` | `bin/brakeman --no-pager` (análisis estático de seguridad Rails) **+** `bin/bundler-audit` (CVEs en gems) | 🔴 sí |
| `scan_js` | `bin/importmap audit` (CVEs en dependencias JS de importmap) | 🔴 sí |
| `test` | `bin/rails tailwindcss:build` → `bin/rails db:test:prepare && bundle exec rspec` (Postgres `pgvector/pgvector:pg16`, `RAILS_ENV=test`) | 🔴 sí |

> Corolario: **NUNCA** subas nada (commit, push, PR, merge) con un gate bloqueante en rojo. Si falla, vuelve a `Implement` y arréglalo ([`task-resolve.md`](task-resolve.md)).

## Secuencia de QA local (la ejecuta [`task-test.md`](task-test.md))

Réplica local de los gates de CI, en orden, parando al primer bloqueante en rojo (`fail_fast`):

```bash
bin/rubocop                                  # estilo (local-only, no en CI)
bin/brakeman --no-pager                       # seguridad (= job scan_ruby, parte 1)
bin/bundler-audit                             # CVEs gems (= job scan_ruby, parte 2)
bin/importmap audit                           # CVEs JS (= job scan_js)
bin/rails db:test:prepare && bundle exec rspec   # tests (= job test)
```

- Un solo spec: `bundle exec rspec spec/requests/sessions_spec.rb` (o `path:línea`).
- `bundle exec rspec` requiere la base de datos de test disponible (`docker compose up -d` para el Postgres local; ver skill `cream-dev`).
- `bin/bundler-audit` puede necesitar `bin/bundler-audit update` para refrescar la base de CVEs.

## Deploy y CI post-merge (`docker.yml`)

Tras el merge a `main`, además de `ci.yml` corre [`.github/workflows/docker.yml`](../../../../.github/workflows/docker.yml): build de la imagen → push a **GHCR** → job `deploy` (SSH al servidor, `docker compose pull/up web`). `M-ci_postmerge_green` exige **ambos** workflows verdes en `main` (`gh run list --branch main`). El deploy a **producción** es parte de este pipeline: no hay staging.

## Milestones que alimentan estos gates

- `M-gates_green_local` — ⚠️ efímero: los 5 comandos locales de arriba en verde. Ante duda, re-ejecutar.
- `M-ci_pr_green` — `gh pr checks <PR>`: los 3 jobs de `ci.yml` verdes en el PR.
- `M-ci_postmerge_green` — `gh run list --branch main`: `ci.yml` **y** `docker.yml` verdes tras el merge (incluye el deploy a prod).

Estos milestones y los guards que abren (`Guard[review]`, `Guard[open_PR]`, `Guard[merge]`, `Guard[card→Test]`) viven en [`contract.md`](contract.md).
