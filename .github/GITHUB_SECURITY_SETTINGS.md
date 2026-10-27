# GitHub repository settings (manual)

Apply in the Entaina/cream repository settings:

- Branch ruleset on `main`: require pull request, at least 1 approval, required checks `scan_ruby`, `scan_js`, `test`; disallow bypass for admins where possible.
- Environment `production`: required reviewers before deploy job runs.
- Actions: default workflow permissions **Read**; disable "Allow GitHub Actions to create and approve pull requests".
- Dependabot: enable **security** updates in addition to version updates.
