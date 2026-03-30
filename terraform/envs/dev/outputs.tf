output "network_id" {
  value = module.network.network_id
}

output "resource_group_name" {
  value = module.network.resource_group_name
}

output "cluster_name" {
  value = module.k8s_cluster.cluster_name
}

output "cluster_id" {
  value = module.k8s_cluster.cluster_id
}

output "monitoring_namespace" {
  value = module.monitoring.monitoring_namespace
}

output "tooling_public_ip" {
  value = module.vm_infra.tooling_public_ip
}

output "appdb_public_ip" {
  value = module.vm_infra.appdb_public_ip
}

output "tooling_private_ip" {
  value = module.vm_infra.tooling_private_ip
}

output "appdb_private_ip" {
  value = module.vm_infra.appdb_private_ip
}

output "acr_login_server" {
  description = "ACR login server (e.g. multiservicedevopsdevacr.azurecr.io)"
  value       = module.acr.acr_login_server
}

output "acr_name" {
  description = "ACR resource name"
  value       = module.acr.acr_name
}

