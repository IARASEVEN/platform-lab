# ADR-0004: Run containers as Podman Quadlets, not docker-compose

- **Status:** Accepted
- **Date:** 2026-07-10

## Context

Everything in this lab except FreeIPA itself (see ADR-0005) runs in a container:
Keycloak, PostgreSQL, Prometheus, Alertmanager, Loki, Grafana, Alloy, NetBox,
WikiJS, Nginx, and the exporters. Something has to define and supervise them.

The guests are Rocky Linux 9 with SELinux enforcing. Podman is the native
container runtime there; Docker is not installed and is not going to be.

## Options considered

### Option A — `docker-compose` / `podman-compose`

What essentially every homelab repository on GitHub does. One `compose.yaml` per
stack, familiar to everyone, huge amount of prior art.

`podman-compose` is a third-party reimplementation with its own gaps. Podman's
own `podman compose` shells out to an external compose provider. Either way,
compose files describe containers but say nothing about **supervision** — what
restarts them on boot, what orders them, what their dependencies are, how their
logs reach the journal. In practice people paper over this with a
`docker-compose up -d` in a systemd unit, which is a systemd unit supervising a
supervisor.

The deeper problem: it teaches nothing. Writing a compose file is a skill that
does not generalise.

### Option B — Hand-written systemd units calling `podman run`

Works, and puts systemd properly in charge. But it is verbose, it is easy to get
wrong, and every unit ends up re-implementing the same cleanup and pull logic.
This is what people did before Quadlets existed.

### Option C — Podman Quadlets

Declarative `.container`, `.network`, `.volume`, and `.pod` files that
`podman-system-generator` translates into real systemd units at boot. Native to
Podman. Native to the Red Hat ecosystem, which is where this stack would
actually live.

The units are real systemd units: `systemctl --user status keycloak`, journald
integration, `After=`/`Requires=` dependency ordering, restart policies,
socket activation, and `systemd-analyze` all work as expected.

Cost: less prior art than compose, and Quadlet syntax is its own thing to learn.
Running them **rootless** adds real constraints — no privileged ports below
1024, user lingering must be enabled for units to survive logout, and SELinux
labelling on bind-mounted volumes (`:Z`) has to be right or nothing starts.

## Decision

**Podman rootless with Quadlets.** No Docker, no docker-compose, no
podman-compose anywhere in this repository.

Nginx handles the privileged-port problem: it is the only thing that needs 80 and
443, and it gets them via a rootful reverse proxy or a `sysctl`-lowered
unprivileged port floor — decided at M3, when it first matters.

## Consequences

### Good

- systemd is genuinely in charge: boot ordering, restart policy, journald,
  dependency graph. No supervisor supervising a supervisor.
- Forces real understanding of systemd user units, rootless namespaces, subuid
  mapping, and SELinux container labelling. That is the transferable skill, and
  it is the reason for doing this at all.
- This is what the Red Hat ecosystem actually runs in production. It is the
  non-tutorial answer.
- Rootless containers are a genuine security posture, not a claimed one.

### Bad

- **Steeper learning curve than compose**, and fewer examples to crib from. Some
  of this will be slow.
- Rootless means privileged ports are unavailable and volume permissions
  (subuid/subgid ranges, SELinux `:Z` labels) will bite at least once per
  service.
- Quadlets are Podman-specific. This does not transfer to a Docker shop.
- Contributors who know compose will have to learn something new to read the
  repo. For a portfolio repository that is an acceptable trade — arguably the
  point — but it is a cost.

### Revisit if

Never, within the scope of this repository. Docker and compose are explicitly
out of scope until M5 ships, and reintroducing them would delete the reason this
decision was made.
