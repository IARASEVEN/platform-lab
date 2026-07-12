terraform {
  required_version = ">= 1.0"

  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      # Exact pin, not "~>". The provider was rewritten at 0.9.0; see
      # ADR-0002 and infra/README.md before touching any HCL in this
      # directory.
      version = "0.9.8"
    }
  }
}
