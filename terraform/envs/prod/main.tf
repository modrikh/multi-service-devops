provider "azurerm" {
  features {}
}

module "network" {
  source = "../../modules/network"

  project_name         = var.project_name
  environment          = var.environment
  resource_group_name  = var.resource_group_name
  region               = var.region
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "k8s_cluster" {
  source = "../../modules/k8s-cluster"

  project_name        = var.project_name
  environment         = var.environment
  resource_group_name = module.network.resource_group_name
  region              = var.region
  kubernetes_version  = var.kubernetes_version
  node_count          = var.node_count
  node_instance_type  = var.node_instance_type
  network_id          = module.network.network_id
  private_subnet_ids  = module.network.private_subnet_ids
}

module "monitoring" {
  source = "../../modules/monitoring"

  cluster_name         = module.k8s_cluster.cluster_name
  resource_group_name  = module.network.resource_group_name
  region               = var.region
  monitoring_namespace = var.monitoring_namespace
  enable_prometheus    = var.enable_prometheus
  enable_grafana       = var.enable_grafana
}
