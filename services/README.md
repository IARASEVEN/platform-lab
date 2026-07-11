# services

Per-service configuration, one directory per service group. Containerised
services run as **Podman Quadlets** (systemd units) — never docker-compose,
see [ADR-0004](../docs/adr/0004-quadlets-over-compose.md). The one exception
is FreeIPA, which runs bare-metal
([ADR-0005](../docs/adr/0005-freeipa-on-the-host.md)).

- [`freeipa/`](freeipa/) — identity core (M1)
- [`observability/`](observability/) — metrics, logs, alerting (M2)
- [`keycloak/`](keycloak/) — OIDC federation (M3)
- [`apps/`](apps/) — NetBox, WikiJS, Nginx (M3)
