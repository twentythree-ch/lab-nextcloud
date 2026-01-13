
terraform {
  required_providers {
    portainer = {
      source  = "portainer/portainer"
      version = ">= 1.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }

  backend "azurerm" {
    # Configuration provided via -backend-config during init
  }
}

provider "portainer" {
  endpoint        = var.portainer_url
  api_key         = var.portainer_token
  skip_ssl_verify = true  # Required if using self-signed certs
}

# Trigger resource to detect git commit changes
resource "null_resource" "git_change_trigger" {
  triggers = {
    git_sha = var.git_sha
  }
}

# Deploy stack from Git repository using the Portainer provider
resource "portainer_stack" "app" {
  name            = var.stack_name
  deployment_type = "standalone"
  method          = "repository"
  endpoint_id     = tonumber(var.portainer_endpoint_id)

  # Git repository configuration
  repository_url                = "https://github.com/${var.github_repository}"
  repository_reference_name     = "refs/heads/${var.git_branch}"
  file_path_in_repository       = var.compose_file_path
  git_repository_authentication = true
  repository_username           = var.github_username
  repository_password           = var.github_pat

  # Stack behavior
  pull_image   = true
  force_update = true

  # Environment variables for the stack
  env {
    name  = "CLOUDFLARE_TUNNEL_TOKEN"
    value = var.cloudflare_tunnel_token
  }

  env {
    name  = "DB_PASSWORD"
    value = var.db_password
  }

  env {
    name  = "REDIS_PASSWORD"
    value = var.redis_password
  }

  env {
    name  = "NEXTCLOUD_DOMAIN"
    value = var.nextcloud_domain
  }

  env {
    name  = "DATA_PATH"
    value = "/data/${var.stack_name}"
  }

  env {
    name  = "AUTHENTIK_CLIENT_ID"
    value = var.authentik_client_id
  }

  env {
    name  = "AUTHENTIK_CLIENT_SECRET"
    value = var.authentik_client_secret
  }

  env {
    name  = "AUTHENTIK_DISCOVERY_URL"
    value = var.authentik_discovery_url
  }

  # Force update when git commit changes
  depends_on = [null_resource.git_change_trigger]
}

output "stack_id" {
  description = "ID of the deployed Portainer stack"
  value       = portainer_stack.app.id
}
