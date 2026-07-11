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

TODO (M1): filled in from the pinned provider version's own documentation,
with working examples — not from memory, not from the internet.
