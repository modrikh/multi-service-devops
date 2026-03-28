output "tooling_vm_name" {
  value = azurerm_linux_virtual_machine.tooling.name
}

output "appdb_vm_name" {
  value = azurerm_linux_virtual_machine.appdb.name
}

output "tooling_public_ip" {
  value = azurerm_public_ip.tooling_pip.ip_address
}

output "appdb_public_ip" {
  value = azurerm_public_ip.appdb_pip.ip_address
}

output "tooling_private_ip" {
  value = azurerm_network_interface.tooling_nic.private_ip_address
}

output "appdb_private_ip" {
  value = azurerm_network_interface.appdb_nic.private_ip_address
}
