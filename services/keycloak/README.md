# keycloak

Keycloak (+ PostgreSQL) on `idp-01`, federated against FreeIPA's 389-ds over
LDAP. The realm configuration is kept as a **versioned realm export JSON** in
this directory, so identity configuration is code like everything else.
Arrives at M3, together with migrating Grafana from LDAP to OIDC.
