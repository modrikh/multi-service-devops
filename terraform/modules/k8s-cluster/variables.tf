variable "project_name" {
  description = "Project or platform name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group name containing the AKS cluster"
  type        = string
}

variable "region" {
  description = "Azure region"
  type        = string
}

variable "kubernetes_version" {
  description = "Target Kubernetes control-plane version"
  type        = string
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
}

variable "node_instance_type" {
  description = "AKS worker node VM size"
  type        = string
}

variable "network_id" {
  description = "Network/VPC ID from network module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnet IDs for worker nodes"
  type        = list(string)
}
