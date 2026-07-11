# ADR-0001: Use Terraform to provision libvirt VMs

- **Status:** Accepted
- **Date:** 2026-07-10

## Context

The lab runs on libvirt + KVM on a single Ubuntu 24.04 host. Something has to
create the VMs, the network, and the storage volumes, and hand them a cloud-init
seed. That "something" needs to be reproducible from a clean machine and legible
to a reviewer who has never seen the repo.

This is a portfolio repository targeting SRE, platform, and infrastructure
roles. The provisioning tool is one of the first things a reader will look at,
so the choice carries signal beyond its technical merits.

## Options considered

### Option A — Vagrant

The obvious homelab answer. `Vagrantfile`, `vagrant up`, done. Enormous amount
of prior art for libvirt. Fastest path to a running VM.

The problem is what it signals and what it teaches. Vagrant is a developer
convenience wrapper for local VMs. It is not infrastructure as code in the sense
the industry means it: no state file, no plan/apply cycle, no dependency graph,
no provider abstraction. Nothing learned here transfers to a cloud provider.

### Option B — Terraform

Real IaC. State, plan, apply, destroy, a dependency graph, and a provider model.
It is what job descriptions actually ask for. Critically, the HCL structure
(resources, variables, outputs, modules) transfers directly to AWS, GCP, or
Azure — the provider changes, the shape of the code does not. That is the exact
gap this repository is trying to close.

Cost: more verbose than Vagrant, and the libvirt provider is a community
provider rather than a first-party one (see ADR-0002).

### Option C — OpenTofu

A fork of Terraform under MPL-2.0, created after HashiCorp relicensed Terraform
under the BSL. The HCL is identical. The libvirt provider is published to both
registries.

For a public repository, the MPL licence is cleaner. But the market — job
listings, ATS keyword filters, hiring managers — says "Terraform". Picking
OpenTofu exclusively would be a licence-purity win and a signalling loss.

### Option D — libvirt XML / `virt-install` / shell scripts

Rejected without much thought. Imperative, unreviewable, and no state.

## Decision

**Terraform**, with the Makefile invoking it as `$(TF)`, defaulting to
`terraform`.

Because the HCL is identical across both tools, `TF=tofu make plan` works
unchanged. The repository does not marry either implementation. Both are tested
in CI.

## Consequences

### Good

- Real IaC skills: state, plan/apply, dependency graph, providers.
- The code shape transfers to a cloud provider by swapping the provider.
- Not locked to either Terraform or OpenTofu.
- `terraform plan` gives reviewers a readable diff of infrastructure changes.

### Bad

- Meaningfully more code than a `Vagrantfile` for the same five VMs.
- Terraform's state file becomes a thing that must be managed, even locally.
- The libvirt provider is community-maintained, which is its own risk — see
  ADR-0002.
- Supporting both `terraform` and `tofu` in CI doubles that job's matrix.

### Revisit if

The lab moves to a cloud provider, at which point the libvirt provider
disappears and this decision becomes uncontroversial.
