variable "project_name" {
  description = "Project or platform name"
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group name for shared network resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "Azure region"
  type        = string
}

variable "vpc_cidr" {
  description = "Main VPC CIDR block"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets"
  type        = list(string)
}
