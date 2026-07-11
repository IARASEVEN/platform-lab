# observability

Prometheus, Grafana, Loki, Grafana Alloy, and Alertmanager on `obs-01`, run as
Podman Quadlets. Log shipping uses **Alloy** — Promtail is deprecated and does
not appear in this repository. Includes exporters, SLO recording rules, and
the alerts that the [runbooks](../../docs/runbooks/) answer to. Arrives at M2.
