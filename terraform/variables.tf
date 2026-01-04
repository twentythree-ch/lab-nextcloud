variable "environment" {
  description = "Deployment environment (development|production)"
  type        = string
}

variable "terraform_state_rg" {
  description = "Resource Group containing the storage account for terraform state"
  type        = string
}

variable "terraform_state_sa" {
  description = "Storage account name for terraform state"
  type        = string
}

variable "terraform_state_container" {
  description = "Blob container name for terraform state"
  type        = string
}

variable "portainer_url" {
  description = "Portainer base URL (e.g. https://portainer.example.com)"
  type        = string
}

variable "portainer_token" {
  description = "Portainer API token"
  type        = string
  sensitive   = true
}

variable "portainer_endpoint_id" {
  description = "Portainer endpoint ID where the stack will be deployed"
  type        = string
}

variable "stack_name" {
  description = "Name of the Portainer stack"
  type        = string
}

variable "compose_file_path" {
  description = "Path to the docker-compose file within the repo"
  type        = string
}

variable "git_branch" {
  description = "Git branch to deploy (used for reference)"
  type        = string
  default     = "main"
}

variable "git_sha" {
  description = "Git commit sha to use as a trigger"
  type        = string
}
