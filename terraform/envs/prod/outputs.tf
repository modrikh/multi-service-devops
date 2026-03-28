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
