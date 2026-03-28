variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
}

variable "region" {
  description = "Azure region"
  type        = string
}

variable "tooling_subnet_id" {
  description = "Subnet ID for tooling VM"
  type        = string
}

variable "appdb_subnet_id" {
  description = "Subnet ID for app/db VM"
  type        = string
}

variable "admin_username" {
  description = "Admin username for Linux VMs"
  type        = string
}

variable "admin_ssh_public_key" {
  description = "SSH public key content for VM access"
  type        = string
}

variable "tooling_vm_size" {
  description = "VM size for tooling machine"
  type        = string
  default     = "Standard_B2s"
}

variable "appdb_vm_size" {
  description = "VM size for app/db machine"
  type        = string
  default     = "Standard_B2s"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into VMs"
  type        = string
  default     = "0.0.0.0/0"
}
