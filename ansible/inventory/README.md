# inventory

`hosts.yml` is **generated** from Terraform state via `make inventory`
(`terraform output -json`) and is gitignored — do not edit or commit it.

[`hosts.example.yml`](hosts.example.yml) is committed so the repository is
readable without running Terraform. It mirrors the shape of the generated
file using the lab's synthetic, public-by-design addressing.
