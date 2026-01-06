variable "environment" {
  description = "Deployment environment (development|production)"
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
  description = "Git branch to deploy"
  type        = string
  default     = "main"
}

variable "github_repository" {
  description = "GitHub repository in format owner/repo"
  type        = string
}

variable "github_username" {
  description = "GitHub username for repository authentication"
  type        = string
}

variable "github_pat" {
  description = "GitHub Personal Access Token for repository authentication"
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_token" {
  description = "Cloudflare Tunnel token"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL database password"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
}

variable "nextcloud_domain" {
  description = "Nextcloud domain name"
  type        = string
}

variable "git_sha" {
  description = "Git commit SHA to trigger updates when code changes"
  type        = string
  default     = ""
}
