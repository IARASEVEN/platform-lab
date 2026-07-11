# ADR-0003: DNS domain, Kerberos realm, and DNS ownership

- **Status:** Accepted
- **Date:** 2026-07-10

## Context

FreeIPA is not a service that can be renamed. The DNS domain and the Kerberos
realm are baked into the CA's certificate subjects, the Kerberos principals, the
LDAP base DN, the SSSD client configuration, and — later — Keycloak's issuer
URLs and every OIDC client redirect URI. Changing them after M1 means rebuilding
the lab.

So it has to be right on day one, and it has to be fixed before a single line of
Terraform is written.

A second, less obvious question rides along with it: **who serves DNS?** FreeIPA
wants to be the authoritative DNS server — it ships BIND and it wants to own the
zone, because Kerberos service discovery depends on SRV records. But libvirt's
default network runs dnsmasq, which also wants to serve DNS and hand out DHCP
leases. Two DNS servers in one lab is a guaranteed afternoon of confusion.

## Options considered

### Domain name

**Option A — a subdomain of a real domain we own** (`lab.example.com`).
The by-the-book FreeIPA recommendation, and the only option that leaves the door
open to public ACME certificates. Requires actually owning a domain, and puts a
real, personally-identifying name into a public repository.

**Option B — a made-up TLD** (`.lab`, `.home`, `.local`).
`.local` is reserved for mDNS and actively breaks things. `.lab` and `.home` are
not reserved and may collide with a future gTLD.

**Option C — `.internal`.**
Reserved by ICANN for private use. Not resolvable on the public internet, by
design. Obviously synthetic, so nothing about it leaks a real organisation's
naming — which matters, because this repository is public and must not contain
real infrastructure identifiers.

### DNS ownership

**Option D — libvirt's dnsmasq does DHCP and DNS.**
Zero configuration. But then FreeIPA is not authoritative, Kerberos SRV records
have to be faked, and the DNS story in the README becomes an apology.

**Option E — libvirt does DHCP, FreeIPA does DNS.**
Workable, but it means disabling dnsmasq's DNS while keeping its DHCP, then
pointing guests at FreeIPA via DHCP option 6. Two moving parts, and lease
renewals can quietly stomp `/etc/resolv.conf`.

**Option F — no DHCP at all. Static IPs via cloud-init. FreeIPA owns DNS
outright.**
The guests get their address and their resolver from cloud-init's
`network-config` v2 at first boot. libvirt's network is NAT-only with DHCP
disabled. FreeIPA/BIND is the single authoritative nameserver, exactly as it
would be in a real deployment.

## Decision

- **DNS domain:** `platform.internal`
- **Kerberos realm:** `PLATFORM.INTERNAL`
- **libvirt network:** `platform-lab`, `192.168.60.0/24`, NAT, **DHCP disabled**
- **Addressing:** static, assigned by cloud-init `network-config` v2
- **DNS:** FreeIPA/BIND on `ipa-01` is the only authoritative nameserver

These values are synthetic and are the single source of truth. They are defined
once as Terraform variables and referenced everywhere else — never hardcoded.

Committing them is fine and is not a violation of the "no real infrastructure
identifiers" rule: they describe a lab that exists to be published, not a real
network belonging to anyone.

## Consequences

### Good

- FreeIPA is authoritative DNS, which is what it is designed to be. Kerberos SRV
  records, host enrolment, and DNS-based CA discovery all work the way the
  upstream documentation says they do.
- No dnsmasq-versus-BIND ambiguity. One DNS server, one story.
- Deterministic addressing: `ipa-01` is always `192.168.60.10`, so the runbooks
  and the demo script can just say so.
- `.internal` cannot accidentally resolve against something real.

### Bad

- **Chicken-and-egg at bootstrap.** The other VMs need `ipa-01` as their
  resolver, but `ipa-01` has to exist and be installed first. The Terraform
  apply and the Ansible run are therefore ordered, and `make identity` must
  complete before `make observability` or `make apps` will work. This is a real
  constraint and the README says so.
- **No public ACME certificates, ever.** `.internal` cannot be validated by
  Let's Encrypt. Everything is signed by FreeIPA's internal Dogtag CA, and every
  browser will complain until the CA is trusted. For a lab this is correct — it
  is also the entire reason the cert-expiry exporter in M4 has something to
  monitor — but it is a real limitation, not a feature.
- Static addressing means adding a VM is a code change, not a DHCP lease. That
  is intentional, but it is friction.

### Revisit if

The lab ever needs to be reachable from outside the host, in which case a real
owned domain and split-horizon DNS become necessary — and that is a rewrite of
this ADR, not an amendment.
