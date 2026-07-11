# workflows

GitHub Actions CI, live from the first commit:

- `lint.yml` — `make lint` on every push and PR. The Makefile lints what
  exists (yamllint, ansible-lint) and skips loudly what has not arrived yet
  (Terraform at M1, promtool at M2, golangci-lint at M4); the workflow's
  tool installs grow with those milestones.
- `secrets-scan.yml` — `make secrets-scan` (gitleaks) on every push and PR.

The full pipeline — including the Go exporter's tests and multi-arch
release — lands at M5. GitHub ignores this README; only `*.yml` files here
are workflows.
