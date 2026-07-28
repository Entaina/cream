# Contributing to Cream

Thanks for your interest in contributing! This document explains how to set up the project, the conventions we follow and how to submit changes.

## Development setup

Follow the [installation guide](INSTALL.md). In short:

```bash
cp .env.example .env
docker compose up -d
bundle install
bin/rails db:prepare db:seed
bin/dev
```

## Running the checks

Before opening a pull request, make sure both pass:

```bash
bin/rails db:test:prepare
bundle exec rspec   # tests
bin/rubocop         # style (rubocop-rails-omakase)
```

## Project conventions

- **Tests**: RSpec, under `spec/` mirroring the app structure (`spec/models`, `spec/requests`, `spec/services`, `spec/system`). Every change in behavior should come with specs.
- **Always mock external calls in specs**: HTTP requests (WebMock/stubs) and background jobs (Active Job test adapter / `have_enqueued_job`). Specs must never hit real APIs or run real Celery/Sidekiq-style work.
- **Style**: `rubocop-rails-omakase` with the local overrides in `.rubocop.yml`. Run `bin/rubocop` locally; CI enforces it.
- **Frontend**: Hotwire (Turbo + Stimulus) with importmap — no Node build. Tailwind v4 design tokens and components live in `app/assets/tailwind/application.css`; prefer the existing CSS components over ad-hoc utility soup.
- **Models**: CRM record types share the `CrmRecord` concern; anything that should appear in the activity timeline uses `Trackable`.
- **No secrets in code**: configuration goes through environment variables (see `.env.example`). Never commit real credentials, domains or personal data.

## Pull request flow

1. Fork the repository and create a branch from `main`.
2. Make your changes with specs, keeping the scope of each PR small and focused.
3. Run `bundle exec rspec` and `bin/rubocop`.
4. Open a pull request using the template — describe what changed, why, and how you tested it.
5. A maintainer will review it. CI must be green before merging.

## Reporting bugs and requesting features

- **Bugs**: open a [GitHub issue](../../issues) using the bug report template. Include steps to reproduce, expected vs. actual behavior, and logs if relevant.
- **Feature requests**: open an issue using the feature request template and describe the use case.
- **Security vulnerabilities**: do **not** open a public issue — see [SECURITY.md](SECURITY.md).

## Documentation

User-facing changes should update the user manual — both [USER_MANUAL.md](USER_MANUAL.md) (English) and [MANUAL_USUARIO.md](MANUAL_USUARIO.md) (Spanish) must stay in sync.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
