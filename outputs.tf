output "application_gateway_public_ip" {
  value = azurerm_public_ip.agw_public_ip.ip_address
}

output "fitness_vm_private_ip" {
  value = azurerm_network_interface.vm1_nic.private_ip_address
}

output "organic_vm_private_ip" {
  value = azurerm_network_interface.vm2_nic.private_ip_address
}

output "bastion_public_ip" {
  value = azurerm_public_ip.bastion_ip.ip_address
}

output "nat_public_ip" {
  value = azurerm_public_ip.nat_ip.ip_address
}
