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
- A `wikijs` OIDC client (M3.3, `oidc_clients.yml`), created the same
  idempotent admin-API way as the LDAP federation provider.
- A native Nginx reverse proxy (M3.3, ADR-0007) on `:80`, passing through
  only `/realms/platform/*` — token, authorization, userinfo, JWKS and
  discovery. This is what makes the realm reachable from app-01 and from a
  browser at all; Keycloak's own container port is still loopback-only,
  unchanged from M3.2.

Keycloak's container is still published on the VM loopback only — the proxy
is what widens, not the container. Admin console access is still an SSH
tunnel, exactly as before (the proxy deliberately doesn't forward `/admin`
or any realm but `platform`):

```
ssh -L 8080:127.0.0.1:8080 <user>@idp-01.platform.internal
# then http://localhost:8080 — bootstrap admin credentials from the vault
```

## Not here yet — deliberately

- **The versioned realm export JSON** this directory is for: it arrives once
  the realm configuration stabilises. Until then, the Ansible role is the
  realm's source of truth.
- **TLS** — the M3.3 proxy is plain HTTP, like everything else in this lab.
  ADR-0007 lists this as a limitation, not an oversight.
- **Group-based authorization for web SSO** — any federated user (`alice`
  and `bob` alike) can obtain a token for the `wikijs` client today. ADR-0006
  flagged this ("M3.3+ has to own that explicitly") and ADR-0007 owns it by
  documenting it: Keycloak has no group federation yet, so there's nothing
  to scope against.
- LDAPS/StartTLS to FreeIPA and a dedicated bind service account — ADR-0006
  lists both as lab shortcuts, with the hardening path.
