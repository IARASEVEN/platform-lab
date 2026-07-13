# apps

End-user applications on `app-01`. WikiJS runs as a rootless Podman Quadlet
(ADR-0004) behind a native Nginx reverse proxy (ADR-0007), authenticating
through Keycloak OIDC. These exist to give the identity and observability
layers something real to protect and measure. NetBox arrives later, behind
the same Nginx as a second site.

## What exists today (M3.3)

- `wikijs.service` — a Quadlet user unit under the `svc-app` account, on the
  shared `app` Podman network with its own PostgreSQL (a second instance of
  the `postgresql` role, distinct from idp-01's — see that role's
  `defaults/main.yml`). Published to the VM loopback only.
- Nginx (native package, real root — not a Quadlet, see ADR-0007) fronting
  WikiJS on `:80`, the only thing app-01 exposes to the lab network.
- A `wikijs` OIDC client in Keycloak's `platform` realm (the `keycloak`
  role's `oidc_clients.yml`, run on idp-01), and Keycloak's own OIDC
  endpoints now reachable from app-01 through idp-01's matching proxy
  (ADR-0007) instead of loopback-only.
- Verified on every run (`--tags verify` works standalone): WikiJS answers
  over HTTP, and — once the manual step below has been completed once — its
  OIDC strategy is active and its login redirect targets the platform
  realm's authorization endpoint with the right client ID.

## Manual, on purpose: connecting WikiJS to Keycloak

Wiki.js has no confirmed, documented way to complete its first-run admin
setup or add an authentication strategy non-interactively — this was
checked against upstream discussion at implementation time, not assumed.
Ansible deploys and verifies; this one step is done once, by hand:

1. Reach WikiJS: `http://app-01.platform.internal/` (lab network) or an SSH
   tunnel to `127.0.0.1:3000` on app-01.
2. Complete the first-run wizard: site title/URL, then an admin account —
   use the email in `wikijs_admin_email` (`wikijs` role defaults) and the
   password in `vault_wikijs_admin_password`.
3. Log in as that admin, then **Administration → Modules → Authentication →
   Add Strategy → Generic OpenID Connect / OAuth2**, and fill in:
   - Client ID: `wikijs` · Client Secret: `vault_wikijs_oidc_client_secret`
   - Authorization/Token/User Info/Logout Endpoint URLs: the
     `wikijs_oidc_*_url` values in the `wikijs` role's `defaults/main.yml`
     (all under `http://idp-01.platform.internal/realms/platform/...`)
4. Save, note the callback URL WikiJS displays for the new strategy, and
   confirm it matches the Keycloak `wikijs` client's redirect URI pattern
   (`keycloak_wikijs_redirect_base`/login/* — see the `keycloak` role's
   `oidc_clients.yml`); narrow that wildcard to the exact path once you've
   seen it.
5. Re-run `ansible-playbook ansible/playbooks/apps.yml --tags verify` (or
   `make apps`) — it now checks the strategy is live and wired correctly.

A real login as a FreeIPA/Keycloak user (`alice`) through that strategy is
the one thing in this stack that stays a manual browser check — there is no
API-driven way to complete an OIDC authorization-code redirect flow, so
nothing here claims to automate it.

## Not here yet — deliberately

- **NetBox** — a second app on app-01, behind the same Nginx as a second
  `conf.d` site, the same OIDC pattern as WikiJS. Not started.
- **TLS** — both of app-01's proxies (this one, and idp-01's in front of
  Keycloak) are plain HTTP. ADR-0007 lists this as a limitation, not an
  oversight.
- **Group-based authorization** — any Keycloak-federated user (`alice` and
  `bob` alike) can log into WikiJS today. Keycloak has no group federation
  yet, so there's nothing to scope a WikiJS-side rule against. ADR-0006 and
  ADR-0007 both flag this explicitly.
