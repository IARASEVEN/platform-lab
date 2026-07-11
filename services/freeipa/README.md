# freeipa

FreeIPA server configuration for `ipa-01` (192.168.60.10): DNS (BIND), CA
(Dogtag), Kerberos, HBAC deny-by-default, sudo rules. Runs **bare-metal** via
`ipa-server-install`, not in a container — see
[ADR-0005](../../docs/adr/0005-freeipa-on-the-host.md). FreeIPA is the only
authoritative DNS for `platform.internal`
([ADR-0003](../../docs/adr/0003-dns-domain-realm-and-ownership.md)).
Arrives at M1.
