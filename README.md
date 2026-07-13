# platform-lab

A self-hosted identity and observability platform — FreeIPA, Keycloak,
Prometheus, Grafana, Loki — on Rocky Linux 9 VMs, built entirely as
infrastructure as code on a single libvirt/KVM host.

**This is a lab.** It exists to be built, broken, documented, and published.
It is not production, it does not pretend to be, and where it cuts corners
the [ADRs](docs/adr/) say so explicitly.

## Why

Identity and observability are the two platform concerns that every tutorial
skips and every real environment depends on. This repository builds both,
end to end, the way a platform team would: provisioning in Terraform,
configuration in Ansible, decisions in ADRs, alerts backed by runbooks, and
a single `make` command per profile. The artifact is the repository itself —
the running lab is disposable by design.

## Status

**M1 complete, M3 in progress.** Identity core — FreeIPA, DNS, CA, HBAC
deny-by-default, sudo rules, Ansible — is done and boots with one command.
Keycloak is running on `idp-01`, federated to FreeIPA over LDAP; the rest of
M3 (versioned realm export, Grafana's migration from LDAP to OIDC) is still
ahead. The milestone table below is the honest state of the work.

| Milestone | Contents | Status |
|---|---|---|
| **M1 — identity core** | Terraform + cloud-init, FreeIPA on Rocky 9, DNS, CA, HBAC deny-by-default, sudo rules, Ansible | ✅ complete |
| **M2 — observability** | Prometheus, Grafana, Loki, Alloy, Alertmanager, exporters, SLOs, runbooks | planned |
| **M3 — keycloak federation** | Keycloak federated to FreeIPA, versioned realm export, Grafana migrated from LDAP to OIDC | 🔄 in progress (70%) |
| **M4 — cert exporter** | Go exporter for FreeIPA certificate expiry, tests, Prometheus alert, renewal runbook | planned |
| **M5 — CI, docs, demo** | Full pipeline, architecture diagram, ADR set, asciinema demo, final README | planned |

## Architecture

```text
┌──────────────────────────────────────────────────────────────────────────┐
│  Ubuntu 24.04 host, 32 GB — libvirt/KVM hypervisor + Ansible control     │
│                                                                          │
│  libvirt network "platform-lab" — 192.168.60.0/24, NAT, DHCP disabled    │
│  DNS: platform.internal · Kerberos: PLATFORM.INTERNAL                    │
│                                                                          │
│  ┌─ identity ────────────────────┐  ┌─ observability ─────────────────┐  │
│  │                               │  │                                 │  │
│  │  ipa-01        .10   (M1)     │  │  obs-01        .20   (M2)       │  │
│  │  FreeIPA: DNS, CA,            │  │  Prometheus, Grafana,           │  │
│  │  Kerberos, LDAP (bare-metal)  │  │  Loki, Alloy, Alertmanager      │  │
│  │                               │  │                                 │  │
│  │  idp-01        .30   (M3)     │  └─────────────────────────────────┘  │
│  │  Keycloak + PostgreSQL        │  ┌─ apps ──────────────────────────┐  │
│  │       │ federates to          │  │                                 │  │
│  │       └──► FreeIPA LDAP       │  │  app-01        .40   (M3)       │  │
│  │                               │  │  NetBox, Wiki.js, Nginx         │  │
│  └───────────────────────────────┘  │                                 │  │
│                                     │  client-01     .50   (M1)       │  │
│  All DNS resolves through           │  enrolled IPA client            │  │
│  FreeIPA's BIND (ADR-0003)          │                                 │  │
│                                     └─────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```

Two deployment idioms coexist, deliberately: FreeIPA runs bare-metal on its
own VM because that is how upstream deploys it ([ADR-0005](docs/adr/0005-freeipa-on-the-host.md));
everything else runs as rootless Podman containers managed by systemd
Quadlets ([ADR-0004](docs/adr/0004-quadlets-over-compose.md)). The host is
Ubuntu and the guests are Rocky on purpose — it forces the Ansible roles to
be genuinely portable.

> A rendered architecture diagram and a full written walkthrough land at M5
> in [docs/architecture.md](docs/architecture.md), once there is a running
> system to describe honestly.

## VMs and RAM budget

Everything fits in 32 GB at once, but the platform starts **by profile**, so
a 16 GB machine can still run any single profile.

| VM | Profile | RAM | vCPU | IP | Arrives |
|---|---|---|---|---|---|
| `ipa-01` | identity | 4 GB | 2 | `192.168.60.10` | M1 |
| `client-01` | apps | 2 GB | 1 | `192.168.60.50` | M1 |
| `obs-01` | observability | 3 GB | 2 | `192.168.60.20` | M2 |
| `idp-01` | identity | 3 GB | 2 | `192.168.60.30` | M3 |
| `app-01` | apps | 3 GB | 2 | `192.168.60.40` | M3 |

**Total: 15 GB** guest RAM.

## Running it

`make identity` is ready: it provisions and configures the whole identity
profile end to end — FreeIPA, DNS, CA, HBAC deny-by-default, sudo rules, the
enrolled client, and (M3, in progress) Keycloak federated to FreeIPA on
`idp-01`. `make observability` and `make apps` are not implemented yet (see
[Status](#status)).

The Makefile is the only human interface:

```console
make help           # list all targets
make check-tools    # verify terraform/ansible/go at pinned versions
make identity       # provision + configure the identity profile
make observability  # provision + configure observability
make apps           # provision + configure apps
make all            # everything (needs ~15 GB free RAM)
make clean          # destroy the lab
```

OpenTofu works everywhere Terraform does: `TF=tofu make <target>`.

Ansible's inventory is generated from Terraform state (`make inventory`),
never hand-maintained; [`hosts.example.yml`](ansible/inventory/hosts.example.yml)
is committed so the repo is readable without running anything.

## Repository layout

- [`docs/`](docs/) — architecture, SLOs, [ADRs](docs/adr/), runbooks
- [`infra/`](infra/) — Terraform + cloud-init
- [`ansible/`](ansible/) — roles, playbooks, generated inventory
- [`services/`](services/) — per-service configuration (FreeIPA, Keycloak, observability, apps)
- [`exporters/`](exporters/) — custom Prometheus exporters (Go)
- [`.github/workflows/`](.github/workflows/) — lint + secrets-scan CI

## Design decisions

Every architectural choice gets an ADR, including its limitations:

- [ADR-0001](docs/adr/0001-terraform-for-provisioning.md) — Terraform for provisioning
- [ADR-0002](docs/adr/0002-libvirt-provider-version.md) — libvirt provider pinned exactly at 0.9.8
- [ADR-0003](docs/adr/0003-dns-domain-realm-and-ownership.md) — DNS domain, realm, and FreeIPA as sole DNS
- [ADR-0004](docs/adr/0004-quadlets-over-compose.md) — Podman Quadlets over docker-compose
- [ADR-0005](docs/adr/0005-freeipa-on-the-host.md) — FreeIPA bare-metal, not containerised

## What this is not

Not production, not highly available, not Kubernetes (deliberately out of
scope until after M5), and not a tutorial — it assumes you can read
Terraform and Ansible. All addressing in this repository
(`platform.internal`, `192.168.60.0/24`) is synthetic and public by design.

## License

[MIT](LICENSE).
