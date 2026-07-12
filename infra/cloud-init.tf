# In 0.9.8 libvirt_cloudinit_disk only generates a local ISO (read-only
# `path`); it no longer uploads itself as a volume. Each disk below is
# wrapped in an explicit libvirt_volume that uploads that local ISO into the
# pool, per infra/README.md's documented 0.9.8 contract change.

resource "libvirt_cloudinit_disk" "ipa01" {
  name = "ipa-01-cloudinit.iso"

  user_data = <<-EOT
    #cloud-config
    hostname: ipa-01
    fqdn: ipa-01.${var.dns_domain}
    # Deliberately false, and only on this host: cloud-init's RHEL-family
    # /etc/hosts template maps the FQDN to 127.0.0.1 and ::1 on every boot,
    # and ipa-server-install refuses to install when the hostname resolves
    # to a loopback address. The freeipa_server Ansible role owns this
    # host's /etc/hosts entry instead.
    manage_etc_hosts: false
    users:
      - default
    ssh_authorized_keys:
      - ${trimspace(file(var.ssh_public_key_path))}
    packages:
      - qemu-guest-agent
    runcmd:
      - systemctl enable --now qemu-guest-agent
  EOT

  meta_data = yamlencode({
    instance-id    = "ipa-01"
    local-hostname = "ipa-01"
  })

  network_config = yamlencode({
    version = 2
    ethernets = {
      eth0 = {
        match = {
          macaddress = local.ipa01_mac
        }
        set-name  = "eth0"
        addresses = ["${var.ipa01_ip}/24"]
        gateway4  = var.network_gateway
        nameservers = {
          # ipa-01 cannot resolve via itself yet (FreeIPA isn't installed)
          # and libvirt's dnsmasq DNS is off network-wide (ADR-0003). These
          # are for outbound package installs during first boot only.
          addresses = var.bootstrap_dns_servers
        }
      }
    }
  })
}

resource "libvirt_volume" "ipa01_cloudinit" {
  name = "ipa-01-cloudinit.iso"
  pool = libvirt_pool.platform_lab.name

  create = {
    content = {
      url = libvirt_cloudinit_disk.ipa01.path
    }
  }
}

resource "libvirt_cloudinit_disk" "client01" {
  name = "client-01-cloudinit.iso"

  user_data = <<-EOT
    #cloud-config
    hostname: client-01
    fqdn: client-01.${var.dns_domain}
    manage_etc_hosts: true
    users:
      - default
    ssh_authorized_keys:
      - ${trimspace(file(var.ssh_public_key_path))}
    packages:
      - qemu-guest-agent
    runcmd:
      - systemctl enable --now qemu-guest-agent
  EOT

  meta_data = yamlencode({
    instance-id    = "client-01"
    local-hostname = "client-01"
  })

  network_config = yamlencode({
    version = 2
    ethernets = {
      eth0 = {
        match = {
          macaddress = local.client01_mac
        }
        set-name  = "eth0"
        addresses = ["${var.client01_ip}/24"]
        gateway4  = var.network_gateway
        nameservers = {
          # ipa-01 is expected to be up (make identity runs before
          # make apps) and is the sole authoritative DNS server (ADR-0003).
          addresses = [var.ipa01_ip]
        }
      }
    }
  })
}

resource "libvirt_volume" "client01_cloudinit" {
  name = "client-01-cloudinit.iso"
  pool = libvirt_pool.platform_lab.name

  create = {
    content = {
      url = libvirt_cloudinit_disk.client01.path
    }
  }
}
