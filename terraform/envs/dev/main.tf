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

module "acr" {
  source = "../../modules/acr"

  project_name            = var.project_name
  environment             = var.environment
  resource_group_name     = module.network.resource_group_name
  region                  = var.region
  acr_sku                 = var.acr_sku
  aks_kubelet_identity_id = module.k8s_cluster.kubelet_identity_id
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

module "vm_infra" {
  source = "../../modules/vm-infra"

  project_name          = var.project_name
  environment           = var.environment
  resource_group_name   = module.network.resource_group_name
  region                = var.region
  tooling_subnet_id     = module.network.public_subnet_ids[0]
  appdb_subnet_id       = module.network.public_subnet_ids[1]
  admin_username        = var.admin_username
  admin_ssh_public_key  = var.admin_ssh_public_key
  tooling_vm_size       = var.tooling_vm_size
  appdb_vm_size         = var.appdb_vm_size
  allowed_ssh_cidr      = var.allowed_ssh_cidr
}
