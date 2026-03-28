# Terraform Structure

This folder is organized by reusable modules and per-environment stacks.

## Layout

- `modules/network`: Azure resource group, virtual network, and subnets.
- `modules/k8s-cluster`: AKS cluster resources.
- `modules/monitoring`: Log Analytics and optional Application Insights.
- `modules/vm-infra`: Tooling VM and app/db VM.
- `envs/dev`: Development stack composition and variables.
- `envs/staging`: Staging stack composition and variables.
- `envs/prod`: Production stack composition and variables.

## Typical Workflow

From an environment folder (`envs/dev`, `envs/staging`, or `envs/prod`):

1. `terraform init`
2. `terraform plan -var-file=terraform.tfvars`
3. `terraform apply -var-file=terraform.tfvars`

## Notes

- Keep secret values out of `terraform.tfvars` when possible.
- Use separate state backends/workspaces per environment.
- `envs/dev/terraform.tfvars` is an example baseline and must be adapted before apply.
