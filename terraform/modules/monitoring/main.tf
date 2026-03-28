locals {
  monitoring_namespace = var.monitoring_namespace
  prometheus_release   = "${var.cluster_name}-prometheus"
  grafana_release      = "${var.cluster_name}-grafana"
}

resource "azurerm_log_analytics_workspace" "monitoring" {
  name                = "${var.cluster_name}-law"
  location            = var.region
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "grafana_like" {
  count               = var.enable_grafana ? 1 : 0
  name                = "${var.cluster_name}-appinsights"
  location            = var.region
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.monitoring.id
}
