output "monitoring_namespace" {
  description = "Namespace for monitoring components"
  value       = var.monitoring_namespace
}

output "prometheus_release_name" {
  description = "Planned Prometheus release name"
  value       = "${var.cluster_name}-prometheus"
}

output "grafana_release_name" {
  description = "Planned Grafana release name"
  value       = "${var.cluster_name}-grafana"
}

output "log_analytics_workspace_id" {
  description = "Azure Log Analytics workspace ID"
  value       = azurerm_log_analytics_workspace.monitoring.id
}
