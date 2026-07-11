# ansible

Configuration management for the guests. The control node is the Ubuntu 24.04
host; the targets are Rocky Linux 9 VMs — deliberately different, so the
playbooks have to be genuinely portable. Arrives at M1.

- [`inventory/`](inventory/) — generated from Terraform state, never hand-maintained
- [`roles/`](roles/) — reusable roles
- [`playbooks/`](playbooks/) — one playbook per profile (identity, observability, apps)

Secrets go through Ansible Vault. Only `vault.example.yml` with placeholders is
ever committed; real vault files and the vault password are gitignored.
