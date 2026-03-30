locals {
  cluster_name = "${var.project_name}-${var.environment}-k8s"
  node_pool    = "system"
  dns_prefix   = "${var.project_name}-${var.environment}"
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name                = local.cluster_name
  location            = var.region
  resource_group_name = var.resource_group_name
  dns_prefix          = local.dns_prefix
  kubernetes_version  = var.kubernetes_version
  
  oidc_issuer_enabled = true

  default_node_pool {
    name           = local.node_pool
    node_count     = var.node_count
    vm_size        = var.node_instance_type
    vnet_subnet_id = var.private_subnet_ids[0]
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
    module      = "k8s-cluster"
  }
}
