# ADR-0002: Pin `dmacvicar/libvirt` to the 0.9 rewrite, exactly

- **Status:** Accepted
- **Date:** 2026-07-10

## Context

There is exactly one viable Terraform provider for libvirt: `dmacvicar/libvirt`.
It is a community provider, not a first-party one.

In November 2025 it was **completely rewritten**. The legacy provider (v0.8.x
and earlier) lives on in a `v0.8` branch; every release from v0.9.0 onward is
based on the rewrite. The rewrite moved to the Terraform Plugin Framework
(because the SDK v2 used by the legacy provider is deprecated) and, more
importantly, **changed the schema**: it now mirrors the libvirt XML structure
directly instead of abstracting it.

Concretely, 0.9 HCL looks like this:

```hcl
resource "libvirt_domain" "example" {
  name        = "example-vm"
  type        = "kvm"
  memory      = 512
  memory_unit = "MiB"
  vcpu        = 1
  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
  }
  devices = {
    disks = [{ device = "disk", target = { dev = "vda" }, source = { pool = "...", volume = "..." } }]
  }
}
```

That is not what 0.8 looked like, and the maintainer has stated there is **no
automated migration path** for the HCL.

This creates a specific and severe problem for an AI-assisted workflow: every
blog post, every Stack Overflow answer, every tutorial, and every LLM's training
data describes the **0.8** schema. An agent asked to "write the libvirt
Terraform" will confidently emit 0.8 HCL that does not work, and will do so
fluently enough that it looks right.

## Options considered

### Option A — Pin to 0.8.x (legacy)

Stable, frozen, and surrounded by working examples. Lowest friction to a booting
VM. Every tutorial applies directly.

But it is the legacy branch of a deprecated SDK. Using it in a 2026 portfolio
repository sends precisely the wrong signal — it says "I used whatever the first
search result told me to". And it is a dead end: eventually it stops getting
fixes.

### Option B — Track 0.9.x with a pessimistic constraint (`~> 0.9`)

Current, maintained, and on the supported framework. But the schema was still
being adjusted through the 0.9 line — the introduction of a schema code
generator changed attribute names again between 0.9.0 and later releases. A
floating constraint means a `terraform init` on a Tuesday can break a repo that
worked on a Monday, in a repository whose whole selling point is that it
reproduces from clean.

### Option C — Pin 0.9.x exactly

Current and maintained, with reproducibility guaranteed. The cost is that
upgrades become deliberate work rather than something that happens for free.

## Decision

**Pin exactly: `version = "0.9.8"`.** Not `~>`, not `>=`.

Additionally, and because of the training-data trap described above:

1. `infra/README.md` documents the XML → HCL mapping for the resources this
   repository actually uses, with working examples taken from the pinned
   version's own docs — not from memory and not from the internet.
2. `CLAUDE.md` carries an explicit rule: **do not write libvirt HCL from
   memory.**
3. Provider upgrades are their own PR, with a `terraform plan` diff in the
   description.

## Consequences

### Good

- Reproducible: `terraform init` produces the same provider on any machine, on
  any day.
- Current framework, not the deprecated SDK.
- The 0.9 schema exposes the full libvirt XML surface, so features like TPM,
  RNG, and CPU pinning are reachable without provider patches.
- Forces genuine understanding of libvirt's domain XML rather than a leaky
  abstraction over it — which is the point of the exercise.

### Bad

- **Materially more verbose than 0.8.** Attaching a cloud-init ISO takes three
  resources (`libvirt_cloudinit_disk` → `libvirt_volume` → a `cdrom` entry in
  the domain's `devices`) instead of one attribute.
- Sparse examples. Some of the domain-device configuration is trial and error.
- A single-maintainer community provider is a real dependency risk. If it stops,
  this repository's `infra/` layer has no drop-in replacement.
- Pinning exactly means security fixes in the provider require a deliberate
  bump.

### Revisit if

The provider reaches 1.0 and stabilises the schema, at which point a `~> 1.0`
constraint becomes reasonable. Or if the provider is abandoned, in which case
the fallback is generating libvirt XML from Ansible templates and dropping
Terraform for the on-prem layer — a significant rewrite, and the reason this
risk is named explicitly here rather than left implicit.
