variable "project_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "kubernetes_version" {
  type = string
}

variable "node_count" {
  type = number
}

variable "node_instance_type" {
  type = string
}

variable "monitoring_namespace" {
  type    = string
  default = "monitoring"
}

variable "enable_prometheus" {
  type    = bool
  default = true
}

variable "enable_grafana" {
  type    = bool
  default = true
}

variable "admin_username" {
  type = string
}

variable "admin_ssh_public_key" {
  type = string
}

variable "tooling_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "appdb_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "allowed_ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}
