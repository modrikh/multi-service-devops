variable "project_name" {
  description = "Project name (used to build the ACR name)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group to create the ACR in"
  type        = string
}

variable "region" {
  description = "Azure region"
  type        = string
}

variable "acr_sku" {
  description = "ACR pricing tier: Basic, Standard, or Premium"
  type        = string
  default     = "Basic"
}

variable "aks_kubelet_identity_id" {
  description = "Object ID of the AKS kubelet managed identity (needed to grant AcrPull)"
  type        = string
}
