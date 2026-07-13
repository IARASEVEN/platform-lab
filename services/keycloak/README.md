# keycloak

Keycloak 26.6 on `idp-01`, running as a rootless Podman Quadlet beside its
PostgreSQL (ADR-0004), federated against FreeIPA's 389-ds over LDAP
(ADR-0006). FreeIPA stays the single source of identity truth; Keycloak turns
it into OIDC.

## What exists today (M3.2)

- `keycloak.service` — a Quadlet user unit under the `svc-idp` account,
  production mode (`start`, never `start-dev`), on the shared `idp` podman
  network with PostgreSQL. Startup is health-gated: systemd reports the unit
  started only once `/health/ready` answers (`Notify=healthy`).
- Realm `platform`, created idempotently by the `keycloak` Ansible role
  through the admin API. `master` stays admin-only.
- LDAP user federation `freeipa-ldap`: READ_ONLY, import enabled, full sync
  when the provider is created or reconfigured, on-demand import at first
  login afterwards. Passwords are never copied — every login is a live bind
  against FreeIPA.
- Verified end to end on every run (`--tags verify` works standalone): OIDC
  discovery of the realm, a password grant for a FreeIPA-only demo user, and
  a check that the imported user really carries the federation link.

Keycloak is published on the VM loopback only — nothing on the lab network
can reach it yet, on purpose. Admin console access is an SSH tunnel:

```
ssh -L 8080:127.0.0.1:8080 <user>@idp-01.platform.internal
# then http://localhost:8080 — bootstrap admin credentials from the vault
```

## Not here yet — deliberately

- **The versioned realm export JSON** this directory is for: it arrives once
  the realm configuration stabilises (OIDC clients land at M3.3+). Until
  then, the Ansible role is the realm's source of truth.
- OIDC clients, the reverse proxy and the TLS story — M3.3+.
- LDAPS/StartTLS to FreeIPA and a dedicated bind service account — ADR-0006
  lists both as lab shortcuts, with the hardening path.
