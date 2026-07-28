# Security Policy

## Supported versions

Cream is under active development. Security fixes are applied to the latest
code on the `main` branch. If you deploy Cream, keep your instance up to date
with `main`.

| Version | Supported |
|---|---|
| `main` (latest) | ✅ |
| Older commits | ❌ |

## Reporting a vulnerability

Please do **not** open a public issue for security vulnerabilities.

Instead, report it privately through
[GitHub's private vulnerability reporting](../../security/advisories/new)
for this repository ("Security" tab → "Report a vulnerability").

Include as much detail as possible:

- A description of the vulnerability and its impact.
- Steps to reproduce (proof of concept if available).
- Affected components (e.g. public lead forms, API endpoints, Gmail integration).

You can expect an initial response within a few days. Once the issue is
confirmed and fixed, we will publish a security advisory crediting the
reporter (unless you prefer to remain anonymous).

## Scope notes

- Cream is self-hosted: hardening of your server, TLS termination and network
  configuration are the responsibility of the operator (see
  [deploy/README.md](deploy/README.md)).
- Secrets are provided exclusively via environment variables; report any code
  path that logs or exposes them.
