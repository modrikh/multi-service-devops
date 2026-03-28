locals {
  network_name = "${var.project_name}-${var.environment}-network"
  public_subnets = {
    for idx, cidr in var.public_subnet_cidrs :
    format("public-%02d", idx + 1) => cidr
  }
  private_subnets = {
    for idx, cidr in var.private_subnet_cidrs :
    format("private-%02d", idx + 1) => cidr
  }

  tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
    module      = "network"
  }
}

resource "azurerm_resource_group" "network" {
  name     = var.resource_group_name
  location = var.region
  tags     = local.tags
}

resource "azurerm_virtual_network" "network" {
  name                = local.network_name
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = [var.vpc_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "public" {
  for_each = local.public_subnets

  name                 = "${azurerm_virtual_network.network.name}-${each.key}"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = [each.value]
}

resource "azurerm_subnet" "private" {
  for_each = local.private_subnets

  name                 = "${azurerm_virtual_network.network.name}-${each.key}"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = [each.value]
}
