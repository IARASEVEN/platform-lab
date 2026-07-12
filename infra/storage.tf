# libvirt_pool schema (0.9.8) has no example page in the registry docs; this
# is derived from the schema, per infra/README.md.
resource "libvirt_pool" "platform_lab" {
  name = "platform-lab"
  type = "dir"

  target = {
    path = "/var/lib/libvirt/pools/platform-lab"
  }
}

# Shared base image. Per-VM disks are qcow2 backing-store overlays against
# this volume (infra/vms.tf) — the image is fetched and stored once.
resource "libvirt_volume" "rocky_base" {
  name = "rocky-9.8-base.qcow2"
  pool = libvirt_pool.platform_lab.name

  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = var.rocky_image_url
    }
  }
  # capacity is computed automatically from the download's Content-Length.
}
