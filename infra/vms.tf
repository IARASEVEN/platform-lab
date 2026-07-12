locals {
  # QEMU/KVM locally-administered OUI (52:54:00:...). Last octet mirrors the
  # VM's static IP last octet, purely as a mnemonic. Assigning a static MAC
  # lets each VM's network-config v2 match its own interface by MAC,
  # regardless of what the guest kernel names it (eth0 vs enp1s0).
  ipa01_mac    = "52:54:00:60:00:10"
  client01_mac = "52:54:00:60:00:32"
  idp01_mac    = "52:54:00:60:00:30"
}

resource "libvirt_volume" "ipa01_disk" {
  name     = "ipa-01.qcow2"
  pool     = libvirt_pool.platform_lab.name
  capacity = 21474836480 # 20 GiB — 389-ds + Dogtag CA

  target = {
    format = {
      type = "qcow2"
    }
  }

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

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = libvirt_volume.rocky_base.path
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_volume" "idp01_disk" {
  name     = "idp-01.qcow2"
  pool     = libvirt_pool.platform_lab.name
  capacity = 16106127360 # 15 GiB — Keycloak + PostgreSQL

  target = {
    format = {
      type = "qcow2"
    }
  }

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
  running     = true
  memory      = 4096
  memory_unit = "MiB"
  vcpu        = 2

  # Rocky 9 userspace requires x86-64-v2; the provider's default qemu64
  # model lacks it and the guest panics killing init.
  cpu = {
    mode = "host-passthrough"
  }

  # libvirt defaults ACPI off unless requested; a q35 guest without ACPI
  # hangs before the kernel registers its console.
  features = {
    acpi = true
    apic = {}
  }

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
        # Without an explicit driver, libvirt attaches the volume as raw and
        # the guest sees the qcow2 container instead of the OS — unbootable.
        driver = {
          name = "qemu"
          type = "qcow2"
        }
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
    # The Rocky 9 GenericCloud GRUB resets the machine at boot when the
    # guest has no video adapter, so headless-with-VGA it is.
    videos = [
      {
        model = {
          type    = "vga"
          vram    = 16384
          heads   = 1
          primary = "yes"
        }
      }
    ]
    # virtio channel the qemu-guest-agent binds to; without it the agent
    # service cannot start inside the guest (cloud-init enables it).
    channels = [
      {
        source = {
          unix = {
            mode = "bind"
          }
        }
        target = {
          virt_io = {
            name = "org.qemu.guest_agent.0"
          }
        }
      }
    ]
  }
}

resource "libvirt_domain" "client01" {
  name        = "client-01"
  type        = "kvm"
  running     = true
  memory      = 2048
  memory_unit = "MiB"
  vcpu        = 1

  cpu = {
    mode = "host-passthrough"
  }

  features = {
    acpi = true
    apic = {}
  }

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
        driver = {
          name = "qemu"
          type = "qcow2"
        }
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
    videos = [
      {
        model = {
          type    = "vga"
          vram    = 16384
          heads   = 1
          primary = "yes"
        }
      }
    ]
    # virtio channel the qemu-guest-agent binds to; without it the agent
    # service cannot start inside the guest (cloud-init enables it).
    channels = [
      {
        source = {
          unix = {
            mode = "bind"
          }
        }
        target = {
          virt_io = {
            name = "org.qemu.guest_agent.0"
          }
        }
      }
    ]
  }
}

resource "libvirt_domain" "idp01" {
  name        = "idp-01"
  type        = "kvm"
  running     = true
  memory      = 3072
  memory_unit = "MiB"
  vcpu        = 2

  cpu = {
    mode = "host-passthrough"
  }

  features = {
    acpi = true
    apic = {}
  }

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
        driver = {
          name = "qemu"
          type = "qcow2"
        }
        source = {
          volume = {
            pool   = libvirt_pool.platform_lab.name
            volume = libvirt_volume.idp01_disk.name
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
            volume = libvirt_volume.idp01_cloudinit.name
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
          address = local.idp01_mac
        }
        source = {
          network = {
            network = libvirt_network.platform_lab.name
          }
        }
      }
    ]
    videos = [
      {
        model = {
          type    = "vga"
          vram    = 16384
          heads   = 1
          primary = "yes"
        }
      }
    ]
    # virtio channel the qemu-guest-agent binds to; without it the agent
    # service cannot start inside the guest (cloud-init enables it).
    channels = [
      {
        source = {
          unix = {
            mode = "bind"
          }
        }
        target = {
          virt_io = {
            name = "org.qemu.guest_agent.0"
          }
        }
      }
    ]
  }
}
