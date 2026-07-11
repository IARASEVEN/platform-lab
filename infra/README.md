# infra

Terraform + cloud-init for the libvirt/KVM layer: the `platform-lab` network
(`192.168.60.0/24`, NAT, DHCP disabled), volumes, and the Rocky Linux 9 guests
with static addressing via cloud-init `network-config` v2. Arrives at M1.

## Provider pin — read before writing any HCL

The `dmacvicar/libvirt` provider is pinned to **exactly `0.9.8`** (not `~>`).
The provider was completely rewritten at v0.9.0 and its schema now mirrors
libvirt XML directly; virtually every example on the internet — and in LLM
training data — is 0.8 syntax and **will not work**. See
[ADR-0002](../docs/adr/0002-libvirt-provider-version.md).

**Do not write libvirt HCL from memory.** Use the XML → HCL mapping below.

## XML → HCL mapping for the resources this repo uses

Documented from the Terraform registry's own content for **0.9.8** (provider
version id `98245`, docs fetched from `registry.terraform.io/v2/provider-docs/`
on 2026-07-11). Everything below is taken from that source, not from memory.

Two provenance caveats, stated up front:

- The registry **truncates the `libvirt_domain` page** (~488 KB served, the
  schema listing cuts off inside `devices.tpms`). The full nested schema for
  `os` sits past the cutoff; its attribute names below come from the doc's own
  example block, which is above the cutoff.
- The `libvirt_network` and `libvirt_pool` pages ship **no example usage at
  all** (schema only). Examples for those two are derived from the 0.9.8
  schema plus libvirt XML semantics and are marked as such — validate them
  with `terraform validate` before trusting them at M1.

### Structural changes that apply to every resource (read first)

- The provider was reimplemented on terraform-plugin-framework. All nesting is
  **attribute syntax with `=`**: `devices = { disks = [ { … } ] }`. The 0.8
  repeated-block style (`disk { … }`, `network_interface { … }`) does not
  parse against this schema.
- The schema **mirrors libvirt XML** (`formatdomain.html`,
  `formatnetwork.html`). When in doubt, the HCL attribute path matches the XML
  element path.
- Several XML `yes|no` attributes surface as **Strings, not Booleans**
  (e.g. `dns.enable`, `domain.local_only`). Others are real Booleans
  (`autostart`, `running`, `read_only`). Check per attribute.

### `libvirt_network`

Schema-only page. Attributes M1 needs: `name` (required), `autostart` (Bool),
`forward` (nested: `mode`, `nat`), `domain` (nested: `name`, `local_only`),
`dns` (nested: `enable`, `forward_plain_names`, …), `bridge` (nested: `name`),
`ips` (list of nested: `address`, `prefix`, `netmask`, `family`, `dhcp`).

Derived example (schema-conformant, not doc-verbatim — verify at M1):

```hcl
resource "libvirt_network" "platform_lab" {
  name      = var.network_name
  autostart = true

  forward = {
    mode = "nat"
  }

  domain = {
    name       = var.dns_domain # "platform.internal"
    local_only = "yes"
  }

  # FreeIPA is the only authoritative DNS (ADR-0003); libvirt's dnsmasq stays off.
  dns = {
    enable = "no"
  }

  ips = [
    {
      # Mirrors libvirt <ip address=… prefix=…>: this is the host-side bridge
      # address, NOT the subnet CIDR that 0.8 took.
      address = var.network_gateway # e.g. first host of var.network_cidr
      prefix  = 24
      # DHCP disabled by construction: omit the `dhcp` attribute entirely.
    }
  ]
}
```

0.8 → 0.9.8 renames (the traps):

| 0.8 | 0.9.8 |
|---|---|
| `mode = "nat"` (top level) | `forward = { mode = "nat" }` |
| `addresses = ["192.168.60.0/24"]` (subnet CIDR) | `ips = [{ address = …, prefix = … }]` — semantics changed too: `address` is the bridge/gateway IP, per libvirt XML |
| `domain = "platform.internal"` (string) | `domain = { name = "platform.internal" }` (nested) |
| `dhcp { enabled = false }` | gone — DHCP is enabled by *presence* of `ips[].dhcp`; omit it to disable |
| `dns { enabled = …, local_only = … }` | `dns = { enable = "yes"/"no" }` (String); `local_only` moved to `domain.local_only` |
| `bridge = "virbr60"` (string) | `bridge = { name = "virbr60" }` (nested) |

### `libvirt_pool`

Schema-only page. `name` and `type` are required; the path lives in
`target.path`. Derived example (verify at M1):

```hcl
resource "libvirt_pool" "platform_lab" {
  name = "platform-lab"
  type = "dir"

  target = {
    path = "/var/lib/libvirt/pools/platform-lab"
  }
}
```

Trap: 0.8 accepted a top-level `path`. In 0.9.8 it is `target = { path = … }`.

### `libvirt_volume`

Doc-verbatim examples (0.9.8 registry page):

```hcl
# Volume from HTTP URL upload
resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-22.04.qcow2"
  pool   = "default"
  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
    }
  }
  # capacity is automatically computed from Content-Length when available
}

resource "libvirt_volume" "overlay" {
  name     = "overlay.qcow2"
  pool     = "default"
  capacity = 10737418240

  backing_store = {
    path   = libvirt_volume.base.path
    format = {
      type = "qcow2"
    }
  }
}
```

0.8 → 0.9.8 renames (the traps):

| 0.8 | 0.9.8 |
|---|---|
| `source = "https://…img"` | `create = { content = { url = … } }` |
| `format = "qcow2"` (string) | `target = { format = { type = "qcow2" } }` |
| `size = 10737418240` | `capacity` (bytes; optional when `create.content` supplies it) |
| `base_volume_id` / `base_volume_name` / `base_volume_pool` | `backing_store = { path = …, format = { type = … } }` — referenced **by path**, not by id |

Useful read-onlys: `path` (host filesystem path), `id`/`key`.

### `libvirt_cloudinit_disk`

**Still exists in 0.9.x**, but its contract changed. In 0.8 it took a `pool`
and uploaded itself as a volume; in 0.9.8 it only **generates a local ISO
file** (read-only `path`) and you upload it explicitly via a `libvirt_volume`.
`user_data` and `meta_data` are both **required** now; `network_config` is
optional (this is where our network-config v2 static addressing goes).

Doc-verbatim example:

```hcl
resource "libvirt_cloudinit_disk" "init" {
  name      = "vm-init"
  user_data = file("user-data.yaml")
  meta_data = yamlencode({
    instance-id    = "vm-01"
    local-hostname = "webserver"
  })
}

resource "libvirt_volume" "cloudinit" {
  name   = "vm-cloudinit"
  pool   = "default"
  format = "raw"

  create = {
    content = {
      url = libvirt_cloudinit_disk.init.path
    }
  }
}
```

⚠️ **The doc's own example is internally inconsistent**: `format = "raw"` is
not a top-level attribute in the 0.9.8 `libvirt_volume` schema (the schema
says `target.format.type`). Expect to write
`target = { format = { type = "raw" } }` instead; confirm at M1.

### `libvirt_domain`

Doc-verbatim basic example:

```hcl
resource "libvirt_domain" "example" {
  name   = "example-vm"
  memory = 2048
  memory_unit   = "MiB"
  vcpu   = 2
  type   = "kvm"

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = ["hd", "network"]
  }

  devices = {
    disks = [
      {
        source = {
          file = {
            file = "/var/lib/libvirt/images/example.qcow2"
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      }
    ]
    interfaces = [
      {
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "default"
          }
        }
      }
    ]
  }
}
```

0.8 → 0.9.8 renames (the traps):

| 0.8 | 0.9.8 |
|---|---|
| `memory = 2048` (MiB implied) | `memory` **plus explicit `memory_unit = "MiB"`** |
| — | `type = "kvm"` is now **required** |
| `disk { volume_id = libvirt_volume.x.id }` | `devices.disks[].source.volume = { pool = …, volume = … }` (by pool+name) or `source.file = { file = … }` (by path); `target = { dev, bus }` |
| `network_interface { network_name = … }` | `devices.interfaces[].source.network = { network = … }`, with `model = { type = "virtio" }` |
| `network_interface { wait_for_lease = true }` | `devices.interfaces[].wait_for_ip = { source = "lease"/"agent"/"any", timeout = 300 }` |
| `network_interface { mac = "…" }` | `devices.interfaces[].mac = { address = "…" }` |
| `machine`, `arch`, `firmware`, `boot_device { dev = […] }` (top level) | all inside `os = { type = "hvm", type_machine, type_arch, firmware, boot_devices = […] }` |
| **`cloudinit = libvirt_cloudinit_disk.x.id`** | **Gone.** Zero occurrences of `cloudinit` in the 0.9.8 domain schema. Attach the cloud-init ISO as a regular disk: upload it to a `libvirt_volume` (see above), then reference that volume in `devices.disks[]` — as a cdrom, something like `{ device = "cdrom", source = { volume = { pool = …, volume = … } }, target = { dev = "sda", bus = "sata" }, read_only = true }` (derived, verify at M1) |

Also note: the domain's read-only `id` is a **Number** in 0.9.8 (it was the
UUID string in 0.8); the UUID is the separate `uuid` attribute. `running` and
`autostart` keep their 0.8 names.
