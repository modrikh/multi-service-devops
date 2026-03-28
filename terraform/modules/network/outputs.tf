output "network_name" {
  description = "Virtual network name"
  value       = azurerm_virtual_network.network.name
}

output "network_id" {
  description = "Virtual network ID"
  value       = azurerm_virtual_network.network.id
}

output "resource_group_name" {
  description = "Resource group containing network resources"
  value       = azurerm_resource_group.network.name
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = [for subnet in azurerm_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = [for subnet in azurerm_subnet.private : subnet.id]
}

output "tags" {
  description = "Module tags"
  value       = local.tags
}
