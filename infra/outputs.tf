output "ipa01_ip" {
  description = "Static IP of ipa-01."
  value       = var.ipa01_ip
}

output "client01_ip" {
  description = "Static IP of client-01."
  value       = var.client01_ip
}

output "idp01_ip" {
  description = "Static IP of idp-01."
  value       = var.idp01_ip
}

output "app01_ip" {
  description = "Static IP of app-01."
  value       = var.app01_ip
}

output "ipa01_fqdn" {
  description = "FQDN of ipa-01."
  value       = "ipa-01.${var.dns_domain}"
}

output "client01_fqdn" {
  description = "FQDN of client-01."
  value       = "client-01.${var.dns_domain}"
}

output "idp01_fqdn" {
  description = "FQDN of idp-01."
  value       = "idp-01.${var.dns_domain}"
}

output "app01_fqdn" {
  description = "FQDN of app-01."
  value       = "app-01.${var.dns_domain}"
}

output "ipa01_ssh" {
  description = "SSH connection string for ipa-01."
  value       = "ssh rocky@${var.ipa01_ip}"
}

output "client01_ssh" {
  description = "SSH connection string for client-01."
  value       = "ssh rocky@${var.client01_ip}"
}

output "idp01_ssh" {
  description = "SSH connection string for idp-01."
  value       = "ssh rocky@${var.idp01_ip}"
}

output "app01_ssh" {
  description = "SSH connection string for app-01."
  value       = "ssh rocky@${var.app01_ip}"
}

output "vms" {
  description = "Structured VM inventory (hostname -> ip/fqdn/profile), consumed by `make inventory` to generate ansible/inventory/hosts.yml."
  value = {
    ipa-01 = {
      ip      = var.ipa01_ip
      fqdn    = "ipa-01.${var.dns_domain}"
      profile = "identity"
    }
    # client-01 is identity, not apps: at M1 it exists to prove enrollment,
    # HBAC and sudo against ipa-01 — it starts and stops with that profile.
    client-01 = {
      ip      = var.client01_ip
      fqdn    = "client-01.${var.dns_domain}"
      profile = "identity"
    }
    # idp-01 (Keycloak, M3) is identity: it exists to federate against
    # ipa-01 and starts and stops with that profile.
    idp-01 = {
      ip      = var.idp01_ip
      fqdn    = "idp-01.${var.dns_domain}"
      profile = "identity"
    }
    # app-01 (WikiJS + Nginx, M3.3; NetBox later) is apps: it starts and
    # stops with that profile, separately from identity.
    app-01 = {
      ip      = var.app01_ip
      fqdn    = "app-01.${var.dns_domain}"
      profile = "apps"
    }
  }
}
