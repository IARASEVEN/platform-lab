locals {
  # QEMU/KVM locally-administered OUI (52:54:00:...). Last octet mirrors the
  # VM's static IP last octet, purely as a mnemonic. Assigning a static MAC
  # lets each VM's network-config v2 match its own interface by MAC,
  # regardless of what the guest kernel names it (eth0 vs enp1s0).
  ipa01_mac    = "52:54:00:60:00:10"
  client01_mac = "52:54:00:60:00:32"
}

resource "libvirt_volume" "ipa01_disk" {
  name     = "ipa-01.qcow2"
  pool     = libvirt_pool.platform_lab.name
  capacity = 21474836480 # 20 GiB — 389-ds + Dogtag CA

  backing_store = {
    path = libvirt_volume.rocky_base.path
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_volume" "client01_disk" {
  name     = "client-01.qcow2"
  pool     = libvirt_pool.platform_lab.name
  capacity = 10737418240 # 10 GiB

  backing_store = {
    path = libvirt_volume.rocky_base.path
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_domain" "ipa01" {
  name        = "ipa-01"
  type        = "kvm"
  memory      = 4096
  memory_unit = "MiB"
  vcpu        = 2

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [
      {
        dev = "hd"
      }
    ]
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_pool.platform_lab.name
            volume = libvirt_volume.ipa01_disk.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_pool.platform_lab.name
            volume = libvirt_volume.ipa01_cloudinit.name
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
        read_only = true
      }
    ]
    interfaces = [
      {
        model = {
          type = "virtio"
        }
        mac = {
          address = local.ipa01_mac
        }
        source = {
          network = {
            network = libvirt_network.platform_lab.name
          }
        }
      }
    ]
  }
}

resource "libvirt_domain" "client01" {
  name        = "client-01"
  type        = "kvm"
  memory      = 2048
  memory_unit = "MiB"
  vcpu        = 1

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [
      {
        dev = "hd"
      }
    ]
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_pool.platform_lab.name
            volume = libvirt_volume.client01_disk.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_pool.platform_lab.name
            volume = libvirt_volume.client01_cloudinit.name
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
        read_only = true
      }
    ]
    interfaces = [
      {
        model = {
          type = "virtio"
        }
        mac = {
          address = local.client01_mac
        }
        source = {
          network = {
            network = libvirt_network.platform_lab.name
          }
        }
      }
    ]
  }
}
