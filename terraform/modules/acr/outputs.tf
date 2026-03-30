output "acr_name" {
  description = "Azure Container Registry name"
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "ACR login server URL (e.g. myregistry.azurecr.io)"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_id" {
  description = "ACR resource ID"
  value       = azurerm_container_registry.acr.id
}
