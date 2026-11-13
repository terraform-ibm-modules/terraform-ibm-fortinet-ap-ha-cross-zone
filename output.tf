output "FGT1_Port1_Public_IP" {
  description = "Active FortiGate Port1 Public IP"
  value       = ibm_is_floating_ip.publicip.address
}

output "FGT1_Port4_Public_IP" {
  description = "Active FortiGate Port4 (HA Management) Public IP"
  value       = ibm_is_floating_ip.publicip2.address
}

output "FGT2_Port1_Public_IP" {
  description = "Passive FortiGate Port1 Public IP"
  value       = ibm_is_floating_ip.publicip3.address
}

output "FGT2_Port4_Public_IP" {
  description = "Passive FortiGate Port4 (HA Management) Public IP"
  value       = ibm_is_floating_ip.publicip4.address
}

output "Public_Security_Group_ID" {
  description = "Security group ID for port1 (external) and port4 (HA management)"
  value       = ibm_is_security_group.fgt_sg_public.id
}

output "Public_Security_Group_Name" {
  description = "Security group name for port1 (external) and port4 (HA management)"
  value       = ibm_is_security_group.fgt_sg_public.name
}

output "Private_Security_Group_ID" {
  description = "Security group ID for port2 (internal) and port3 (HA heartbeat)"
  value       = ibm_is_security_group.fgt_sg_private.id
}

output "Private_Security_Group_Name" {
  description = "Security group name for port2 (internal) and port3 (HA heartbeat)"
  value       = ibm_is_security_group.fgt_sg_private.name
}

output "Catalog_Offering_Version_CRN" {
  description = "Catalog offering version CRN used for deployment"
  value       = var.CATALOG_OFFERING_VERSION_CRN
}

output "Catalog_Offering_Plan_CRN" {
  description = "Catalog offering plan CRN used for deployment"
  value       = var.CATALOG_OFFERING_PLAN_CRN
}

output "Selected_Profile" {
  description = "VSI profile selected based on plan CRN and region"
  value       = local.selected_profile
}
output "Username" {
  value = "admin"
}

output "FGT1_Default_Admin_Password" {
  value = ibm_is_instance.fgt1.id
}
output "FGT2_Default_Admin_Password" {
  value = ibm_is_instance.fgt2.id
}

output "Par_ID" {
  value = ibm_is_public_address_range.public_address_range_instance.id
}
output "Par_Name" {
  value = ibm_is_public_address_range.public_address_range_instance.name
}
output "Par_CIDR" {
  value = ibm_is_public_address_range.public_address_range_instance.cidr
}