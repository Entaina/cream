# Cream 🍦

Cream is an open source CRM: **people**, **companies** and **deals** organized by workspace, with notes, tasks, lists and a shared activity timeline for your team.

Built with **Rails 8.1**, **Tailwind CSS v4**, **Hotwire (Turbo + Stimulus)** and **PostgreSQL 16** (Docker Compose). No Node build step: importmap + tailwindcss-rails.

## Quick start

```bash
cp .env.example .env          # adjust if needed
docker compose up -d          # PostgreSQL on localhost:5470
bin/rails db:prepare db:seed  # schema + demo workspace
bin/dev                       # server + Tailwind watcher (http://localhost:3030)
```

Demo credentials: `admin@example.com` / `creamcream` (also `member@example.com` / `creamcream`).

Full setup instructions, environment variables and optional features: **[INSTALL.md](INSTALL.md)**.

## Features

- **Multi-user workspaces** with registration, login, password recovery and optional Google OAuth (native Rails 8 authentication).
- **People, Companies and Deals** with sortable tables, global search (`/` shortcut) and filters by company, industry or stage.
- **Kanban pipeline board** with drag & drop, per-column totals, multiple pipelines and per-stage entry conditions.
- **Record pages** with attribute panel, notes, tasks, attachments and an automatic activity timeline (creation, field changes with diff, stage changes).
- **Tasks** with due dates, assignees, overdue highlighting and @mentions.
- **Typed lists** (people, companies or deals) with colors, plus saved views and custom fields (text, select, formula, record references and more).
- **Products and deal line items** — deal value computed from product lines.
- **Email from records**: templates with variables, mail merge, scheduled send, follow-up reminders, open/click tracking and optional send-as-Gmail with reply logging.
- **Public lead capture forms** with anti-spam protection (honeypot, time-trap, rate limiting, optional Cloudflare Turnstile) and pipeline routing.
- **Booking pages** (Calendly-style) backed by Google Calendar, with event types, availability windows and automatic deal creation.
- **Automations** (trigger + conditions + actions), **stage triggers**, **webhooks** and **reports** with CSV export and scheduled email delivery.
- **Stripe payment reconciliation** — import charges and match them to deals.
- **Gmail add-on** to link Gmail threads to deals from the Gmail sidebar ([gmail_addon/](gmail_addon/)).
- **Optional AI features**: sales briefings, contextual assistant with knowledge base (Google Drive), agent memory and CRM tools via API + MCP server.

See the **[User Manual](USER_MANUAL.md)** for a complete tour ([versión en español](MANUAL_USUARIO.md)).

## Tests

```bash
bin/rails db:test:prepare
bundle exec rspec
```

## Project structure

- Core models in `app/models` with the `CrmRecord` (shared associations) and `Trackable` (automatic timeline) concerns.
- Design tokens and CSS components in `app/assets/tailwind/application.css`.
- Development skills for AI coding agents in `.claude/skills/` (environment, architecture, browser verification).

## Documentation

| Document | Contents |
|---|---|
| [INSTALL.md](INSTALL.md) | Requirements, local setup, environment variables, optional features |
| [USER_MANUAL.md](USER_MANUAL.md) | End-user documentation (English) |
| [MANUAL_USUARIO.md](MANUAL_USUARIO.md) | End-user documentation (Spanish) |
| [deploy/README.md](deploy/README.md) | Production deployment (Docker, GitHub Actions, Traefik) |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [SECURITY.md](SECURITY.md) | Reporting vulnerabilities |

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for the development setup, project conventions and pull request flow.

## License

Cream is released under the [MIT License](LICENSE).
