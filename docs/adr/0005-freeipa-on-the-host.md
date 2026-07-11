# ADR-0005: FreeIPA runs on the host, not in a container

- **Status:** Accepted
- **Date:** 2026-07-10

## Context

ADR-0004 commits the platform to Podman rootless with Quadlets for containerised
workloads. That raises an obvious question: does FreeIPA run in a container too?

It is tempting to say yes, for consistency. A container image exists
(`freeipa/freeipa-server`), and "everything is a container" is a clean story.

It is the wrong answer, and the reason is worth writing down, because a reader
will ask.

## Options considered

### Option A — FreeIPA in a rootless Podman container

FreeIPA server is not one process. It is 389-ds, the MIT Kerberos KDC, kadmin,
BIND, Apache, Dogtag (which is a Tomcat application), certmonger, and SSSD, all
supervised by systemd **inside** the container. Running systemd inside a
rootless container is possible but hostile.

On top of that it needs to bind privileged ports — 53 (DNS), 88 and 464
(Kerberos), 389 and 636 (LDAP), 80 and 443 — which rootless containers cannot do
without lowering the unprivileged port floor across the whole host. And SELinux
labelling for a container that is itself running a CA and a directory server is
a genuine research project.

The upstream container image exists mainly for CI and for ephemeral test
deployments. It is not how anybody runs an identity provider they depend on.

### Option B — FreeIPA in a rootful Podman container

Solves the port problem and most of the systemd problem. But a rootful container
running with the privileges FreeIPA needs is, in security terms, barely
distinguishable from installing it on the host — while adding a layer of
indirection that makes every runbook harder to write and every debugging session
harder to run.

It buys the *appearance* of containerisation without the substance. That is
exactly the kind of thing this repository is supposed to avoid.

### Option C — FreeIPA bare-metal on `ipa-01`, via `ipa-server-install`

`dnf install ipa-server ipa-server-dns` and `ipa-server-install`, driven by
Ansible, on a dedicated Rocky 9 VM that does nothing else. This is how FreeIPA
is deployed and documented upstream, and how Red Hat deploys IdM.

The VM **is** the isolation boundary. That is what the hypervisor is for.

## Decision

**FreeIPA server runs directly on `ipa-01`**, installed with
`ipa-server-install` and configured by Ansible. `ipa-01` runs nothing else.

Podman rootless with Quadlets remains the rule for everything else: Keycloak,
PostgreSQL, the observability stack, and the applications.

## Consequences

### Good

- FreeIPA is deployed the way upstream deploys it, so upstream documentation,
  upstream troubleshooting, and upstream runbooks all apply verbatim.
- No fighting systemd-in-a-container, privileged ports, or SELinux labelling on
  a CA.
- `ipa-01` is a single-purpose host with a clean blast radius. The VM boundary
  is a stronger isolation boundary than a rootful container would have been
  anyway.
- The mixed model — bare-metal for the identity plane, rootless containers for
  the workload plane — is itself a realistic production shape, and is more
  honest than pretending everything containerises cleanly.

### Bad

- **The platform is not "all containers".** The architecture story is slightly
  less tidy, and the README has to explain the split rather than assert
  uniformity. That explanation is the point, but it is a cost.
- `ipa-01` is a pet, not cattle. Rebuilding it means a full `ipa-server-install`
  run, not a container restart. Backups of `/var/lib/ipa` and the CA's key
  material become a real operational concern — and, notably, an M2 alerting
  concern.
- Ansible has to manage packages and services on a host, not just drop Quadlet
  files. Two configuration idioms coexist in the repo.

### Revisit if

FreeIPA upstream ships a containerised server intended for production use, or if
the lab moves to Kubernetes — where the question is not "container or not" but
"is FreeIPA the right identity source at all". Both are out of scope until M5
ships.
