# inventory

`hosts.yml` is **generated** from Terraform state via `make inventory`
(`terraform output -json` piped through [`generate.jq`](generate.jq)) and is
gitignored — do not edit or commit it.

[`hosts.example.yml`](hosts.example.yml) is committed so the repository is
readable without running Terraform. It mirrors the shape of the generated
file using the lab's synthetic, public-by-design addressing.

The generator emits two kinds of groups:

- **Profile groups** (`identity`, `observability`, `apps`) — from the
  `profile` field of Terraform's `vms` output. Playbooks target these for
  the common baseline; `make <profile>` maps to one playbook each.
- **Service groups** (`ipa`, `idp`, `obs`, `app`, `client`) — one per host,
  the short hostname minus its trailing `-NN`. Playbooks target these for
  service roles, so a role never leaks onto a host later added to the same
  profile.
