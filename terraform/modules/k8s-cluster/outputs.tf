output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.cluster.name
}

output "node_pool_name" {
  description = "Default AKS node pool name"
  value       = azurerm_kubernetes_cluster.cluster.default_node_pool[0].name
}

output "kubeconfig_hint" {
  description = "Command hint to fetch kubeconfig"
  value       = "az aks get-credentials --resource-group ${azurerm_kubernetes_cluster.cluster.resource_group_name} --name ${azurerm_kubernetes_cluster.cluster.name}"
}

output "cluster_id" {
  description = "AKS cluster ID"
  value       = azurerm_kubernetes_cluster.cluster.id
}

output "kubelet_identity_id" {
  description = "Object ID of the AKS kubelet managed identity (used for ACR role assignment)"
  value       = azurerm_kubernetes_cluster.cluster.kubelet_identity[0].object_id
}
