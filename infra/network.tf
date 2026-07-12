# libvirt_network schema (0.9.8) has no example page in the registry docs;
# this is derived from the schema + libvirt XML semantics, per
# infra/README.md. Verify with `terraform validate` before trusting further.
resource "libvirt_network" "platform_lab" {
  name      = var.network_name
  autostart = true

  forward = {
    mode = "nat"
  }

  domain = {
    name       = var.dns_domain
    local_only = "yes"
  }

  # FreeIPA/BIND on ipa-01 is the only authoritative DNS server (ADR-0003).
  # libvirt's own dnsmasq DNS stays off — two DNS servers on one network is
  # not a story worth telling.
  dns = {
    enable = "no"
  }

  ips = [
    {
      # Mirrors libvirt <ip address=… prefix=…>: this is the host-side
      # bridge address, not the subnet CIDR that 0.8 took.
      address = var.network_gateway
      prefix  = 24
      # No `dhcp` attribute: DHCP is disabled by omission (ADR-0003).
      # Addressing is static, assigned via cloud-init network-config v2.
    }
  ]
}
