variable "cluster_name" {
  description = "Target cluster name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for monitoring resources"
  type        = string
}

variable "region" {
  description = "Azure region for monitoring resources"
  type        = string
}

variable "monitoring_namespace" {
  description = "Namespace for monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "enable_prometheus" {
  description = "Whether Prometheus should be enabled"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Whether Grafana should be enabled"
  type        = bool
  default     = true
}
