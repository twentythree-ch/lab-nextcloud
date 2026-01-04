
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
  features = {}
}

# Placeholder resource that triggers a deployment provisioner.
# The provisioner runs a script which should perform the Portainer stack create/update.
resource "null_resource" "deploy_stack" {
  triggers = {
    git_sha         = var.git_sha
    compose_path    = var.compose_file_path
    stack_name      = var.stack_name
    portainer_url   = var.portainer_url
    portainer_ep_id = var.portainer_endpoint_id
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/deploy_stack.sh '${var.stack_name}' '${var.compose_file_path}' '${var.portainer_endpoint_id}' '${var.portainer_url}'"
    environment = {
      PORTAINER_TOKEN = var.portainer_token
    }
  }
}
