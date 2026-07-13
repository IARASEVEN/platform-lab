# ADR-0006: Keycloak federates to FreeIPA over LDAP

- **Status:** Accepted
- **Date:** 2026-07-12

## Context

M3 introduces web SSO. Grafana and the M3 applications speak OIDC; FreeIPA —
the platform's single source of identity truth (ADR-0003, ADR-0005) — is not
an OIDC provider. Keycloak bridges that gap. The question this ADR answers is
**how Keycloak sees FreeIPA's users**: same accounts, same passwords, no
second identity silo.

Constraints that shape the answer: Keycloak runs as a rootless Podman
container on `idp-01` (ADR-0004), while FreeIPA runs bare-metal on `ipa-01`
(ADR-0005); and since Keycloak 26.2, LDAP referral chasing is filtered by
default (a CVE mitigation) — relevant when the backend is 389-ds.

## Options considered

### Option A — LDAP user federation against FreeIPA's 389-ds

Keycloak's built-in LDAP storage provider, pointed at
`cn=users,cn=accounts,...` with vendor "Red Hat Directory Server" (389-ds).
Users are imported on sync or on first login; passwords are never copied —
every login is a live LDAP bind against FreeIPA. Works from inside a
container with nothing but a TCP route to `ipa-01`. This is the mainstream
way Keycloak consumes an existing directory.

### Option B — Keycloak's SSSD federation provider

Reads users through the host's SSSD over D-Bus. Designed for Keycloak
installed on an IPA-enrolled RHEL host: it needs `sssd-dbus`, an enrolled
host, and access to the host's D-Bus socket — three things a rootless
container deliberately does not have. Enrolling `idp-01` and punching the
D-Bus socket into the container buys nothing over Option A here, and fights
ADR-0004.

### Option C — Kerberos/SPNEGO brokering

Ticket-based browser SSO for enrolled machines. It is a *login mechanism*,
not a user store — Keycloak still needs Option A or B underneath to know the
users. Useless for this lab's browsers (the Ubuntu host is not enrolled) and
for pure OIDC clients. Can be layered on top later; not an alternative.

### Option D — No federation: manage users natively in Keycloak

A second user database. SSH identity and web identity drift apart, HBAC demo
users stop being the SSO users, and "FreeIPA is the source of truth" becomes
false. Rejected on principle.

## Decision

**Option A.** The `keycloak` Ansible role creates the `platform` realm and an
LDAP federation provider against `ldap://ipa-01.platform.internal:389`:
`READ_ONLY` edit mode, import enabled, vendor `rhds`, `uid` as username,
`nsuniqueid` as UUID, one-level scope under the flat `cn=users` container,
full sync when the provider is created or reconfigured, on-demand import at
first login afterwards. Referrals keep Keycloak's filtered default — a
single-suffix IPA tree never emits any.

## Consequences

### Good

- One identity: alice and bob authenticate to web apps with the same
  passwords FreeIPA enforces for SSH, and password policy stays FreeIPA's.
- Passwords are never stored in Keycloak — every web login is a live bind
  against 389-ds, which the role's verify proves end to end on every run.
- Container-friendly: one TCP connection, no enrolment, no host sockets.
- READ_ONLY keeps the arrow of truth pointing one way; nothing Keycloak does
  can corrupt the directory.

### Bad

- **The LDAP leg is plaintext `ldap://:389`.** Bind passwords cross the wire
  unencrypted between `idp-01` and `ipa-01`. Tolerable inside this NATed lab
  network, unacceptable anywhere else. Hardening path: LDAPS/StartTLS with
  the IPA CA mounted into the container (`KC_TRUSTSTORE_PATHS`), not done at
  M3.2.
- **The bind account is the IPA `admin`.** A lab shortcut that avoids a
  dedicated `cn=sysaccounts` service account with read-only ACIs. The vault
  already isolates the secret; the account itself is still far too powerful
  for a read-only consumer.
- **HBAC does not gate web SSO.** HBAC controls PAM access on enrolled
  hosts; an LDAP simple bind is not subject to it. bob — denied SSH
  everywhere by deny-by-default — can still obtain OIDC tokens. Web-side
  authorisation is Keycloak's (or the application's) job, and M3.3+ has to
  own that explicitly.
- Only users and default attributes federate today. Group federation (and
  with it Grafana role mapping) is deliberately deferred to the Grafana OIDC
  migration.
- The realm exists only as API state so far; the versioned realm export JSON
  promised in `services/keycloak/` arrives once the realm config stabilises,
  and until then the Ansible role is the realm's source of truth.

### Revisit if

Applications need profile write-back (edit mode), desktop SSO makes Kerberos
brokering worth layering on, or the lab ever leaves the single NATed network
— at which point the plaintext LDAP leg stops being tolerable and LDAPS stops
being optional.
