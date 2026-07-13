# ADR-0007: Native Nginx reverse proxies in front of Keycloak and WikiJS

- **Status:** Accepted
- **Date:** 2026-07-13

## Context

ADR-0004 chose rootless Podman Quadlets for everything except FreeIPA, but
explicitly deferred one question: rootless containers cannot bind ports below
1024, and *something* in this lab eventually needs port 80. ADR-0004's own
words: "Nginx handles the privileged-port problem... it gets [port 80] via a
rootful reverse proxy or a `sysctl`-lowered unprivileged port floor — decided
at M3, when it first matters." It now matters.

Keycloak has been running since M3.2 published to `127.0.0.1:8080` only, on
purpose — nothing on the lab network could reach it, by design, until this
was decided. WikiJS (M3.3) needs to reach Keycloak's OIDC endpoints from
app-01, and a browser needs to reach both Keycloak's authorization endpoint
and WikiJS itself to complete a login. Two hosts, two proxies: idp-01 in
front of Keycloak, app-01 in front of WikiJS. Both need the same answer to
"how does something here get port 80."

## Options considered

### Option A — Rootless container, lowered privileged-port floor

Set `net.ipv4.ip_unprivileged_port_start=80` (a host-wide sysctl) so the
rootless `svc-idp`/`svc-app` users can publish a container directly on port
80/443, and run nginx as one more Quadlet beside Keycloak/WikiJS. Stays
inside ADR-0004's rootless posture with zero exceptions.

Cost: the sysctl is host-wide, not scoped to the reverse proxy — it also
lets *any* other rootless process on that VM claim ports 80-1023, quietly
widening the attack surface ADR-0004 was trying to narrow. And nginx gains
nothing from being containerized here: it isn't part of the rootless
stack's own network namespace story the way Keycloak/PostgreSQL are (they
talk to each other over the `idp`/`app` Podman networks; nginx only ever
talks to `127.0.0.1:<port>`, which works identically from outside a
container).

### Option B — Rootful Nginx container

Run nginx itself as a Podman container, but rootful (real root, not the
`svc-idp`/`svc-app` users) so it can bind 80/443 directly, alongside the
rootless Quadlet stack. Splits this host between two container ownership
models for one extra service, without buying isolation the native package
doesn't already have (nginx proxying to `127.0.0.1` needs no container
namespace of its own — there's nothing to isolate it from).

### Option C — Native Nginx, rootful, real root

`dnf install nginx` from Rocky 9's AppStream module, a plain systemd
service. Not a Quadlet, not rootless — a deliberate, scoped exception to
ADR-0004, the same shape of exception ADR-0005 already made for FreeIPA
("bare-metal where that's how upstream actually runs it"). This is also
what the overwhelming majority of real deployments do: nginx-in-front-of-
containers as a native package is far more common than rootless-with-a-
lowered-port-floor, which is a workaround specific to this lab's rootless
constraint rather than a pattern anyone reaches for by default.

## Decision

**Option C.** A small shared `nginx` Ansible role (install, one `conf.d`
fragment per invocation, firewalld, start) runs once on `idp-01` and once on
`app-01`. Each caller (the `keycloak` role, the `wikijs` role) owns its own
site content as a template in its own role directory — the shared role only
does the mechanical part, it has no opinion on what's being proxied.

- **idp-01**: proxies only `/realms/platform/*` (token, authorization,
  userinfo, JWKS, `.well-known` discovery — everything under that path) to
  Keycloak's loopback port. Everything else, including `/admin` and the
  `master` realm, returns 403 — the admin console stays reachable only
  through the SSH tunnel `services/keycloak/README.md` already documents.
  Keycloak's own container port never moves off `127.0.0.1:8080`; the proxy
  is the only thing that gets a wider address, and it runs on the same host.
  `KC_PROXY_HEADERS=xforwarded` is set now that a proxy genuinely sits in
  front (it was deliberately absent before this — see the keycloak role's
  Quadlet comments).
- **app-01**: proxies everything to WikiJS's loopback port. No path
  restriction — WikiJS is the only thing app-01 exposes today. NetBox adds
  a second `conf.d` fragment through the same role later, not a rewrite of
  this one.

Still plain HTTP, everywhere, on purpose — no TLS exists anywhere in this
lab yet (ADR-0006 already carries the same limitation for the LDAP leg).

## Consequences

### Good

- The one service that genuinely needs root gets it directly and narrowly,
  instead of widening a host-wide sysctl or splitting container ownership
  models for no isolation benefit.
- systemd supervises nginx exactly like every other native service on these
  hosts (chrony, firewalld) — no new supervision model to reason about.
- One shared role instead of duplicated install/template/firewalld logic on
  two hosts.
- Keycloak's admin console and `master` realm stay exactly as locked down as
  they were before this ADR — only the `platform` realm's OIDC surface
  widens, and only to the lab network, not the internet.

### Bad

- **Nginx is the one service in this repository that is not a Podman
  Quadlet.** A deliberate, scoped exception to ADR-0004 — the same shape of
  exception ADR-0005 already made for FreeIPA, not a new kind of one, but
  still a second exception to a "rootless everywhere" story.
- **No TLS.** Both proxies terminate plain HTTP. Acceptable inside this
  NATed lab network, unacceptable anywhere else — same caveat ADR-0006
  already carries for the LDAP leg. Hardening path: this is the natural
  place to add it later, since nginx already terminates the connection.
- **Any Keycloak-federated user can log into WikiJS, not just an authorized
  subset.** ADR-0006 flagged this explicitly and deferred it: "HBAC does
  not gate web SSO... M3.3+ has to own that explicitly." It's owned here by
  documenting it, not by building group-based authorization — Keycloak has
  no group federation yet (ADR-0006 deferred that too), so there is nothing
  to scope a WikiJS-side rule against yet. alice and bob both get a valid
  WikiJS login today.
- `server_name`/realm/port values in the two nginx site templates are
  literals that mirror the keycloak/wikijs roles' own defaults rather than
  live references to them — chosen deliberately (see the templates'
  comments) so the proxy play doesn't need to re-run the role it's fronting
  just to see its variables, at the cost of two places to update if those
  defaults ever change.

### Revisit if

TLS termination becomes a goal (add it here, at the proxy, not per-service).
Keycloak group federation lands, making app-side or realm-side authorization
scoping possible for WikiJS. NetBox's arrival on app-01 is the first real
test of whether the shared `nginx` role's "one template per site" shape
still holds with two sites on one host.
