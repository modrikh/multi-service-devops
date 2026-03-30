locals {
  acr_name = replace("${var.project_name}${var.environment}acr", "-", "")
  tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
    module      = "acr"
  }
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = local.acr_name
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = var.acr_sku
  admin_enabled       = false  # Use managed identity, not admin credentials
  tags                = local.tags
}

# Grant AKS the AcrPull role on the registry so it can pull images without secrets
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = var.aks_kubelet_identity_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}
