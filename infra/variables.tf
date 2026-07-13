variable "dns_domain" {
  description = "Authoritative DNS domain. Served by FreeIPA/BIND on ipa-01, the only nameserver in this lab (ADR-0003)."
  type        = string
  default     = "platform.internal"
}

variable "kerberos_realm" {
  description = "Kerberos realm. Not consumed by Terraform directly; defined once here so Ansible and later milestones reference a single source of truth (ADR-0003)."
  type        = string
  default     = "PLATFORM.INTERNAL"
}

variable "network_name" {
  description = "libvirt network name."
  type        = string
  default     = "platform-lab"
}

variable "network_cidr" {
  description = "Subnet for the platform-lab libvirt network. Informational (used in variable descriptions/outputs) — the provider takes gateway + prefix, not a CIDR, since 0.9.8 (see infra/README.md)."
  type        = string
  default     = "192.168.60.0/24"
}

variable "network_gateway" {
  description = "Host-side bridge address for the platform-lab network (first usable host of network_cidr). Not a DHCP pool start — DHCP is disabled network-wide (ADR-0003)."
  type        = string
  default     = "192.168.60.1"
}

variable "ipa01_ip" {
  description = "Static IP for ipa-01 (identity profile, M1)."
  type        = string
  default     = "192.168.60.10"
}

variable "client01_ip" {
  description = "Static IP for client-01 (identity profile, M1)."
  type        = string
  default     = "192.168.60.50"
}

variable "idp01_ip" {
  description = "Static IP for idp-01, the Keycloak + PostgreSQL host (identity profile, M3)."
  type        = string
  default     = "192.168.60.30"
}

variable "app01_ip" {
  description = "Static IP for app-01, the WikiJS/NetBox/Nginx host (apps profile, M3)."
  type        = string
  default     = "192.168.60.40"
}

variable "rocky_image_url" {
  description = "URL of the Rocky Linux 9 GenericCloud base qcow2 image, pinned to an exact build — never the floating 'latest' symlink."
  type        = string
  default     = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base-9.8-20260525.0.x86_64.qcow2"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key injected into cloud-init for the default bootstrap user. Machine-specific: set in terraform.tfvars, which is gitignored."
  type        = string
}

variable "bootstrap_dns_servers" {
  description = "Resolvers used only by ipa-01 during first boot (package installs), before ipa-server-install makes it authoritative for its own domain (ADR-0003 chicken-and-egg note). client-01 resolves via ipa-01 directly, not via these."
  type        = list(string)
  default     = ["1.1.1.1", "9.9.9.9"]
}
