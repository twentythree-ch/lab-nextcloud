# Terraform for lab-nextcloud

This folder contains Terraform configuration to deploy Portainer stacks using the **official Portainer Terraform provider**.

## Architecture

The deployment uses:
- **Portainer Terraform Provider** (`portainer/portainer`) to manage stacks via Portainer's API
- **Azure Blob Storage** for Terraform state backend
- **GitHub Actions** for CI/CD pipeline

## Required Azure Resources

These must be created before running Terraform (not managed by this config):
- Resource Group (e.g. `rg-lab-twentythree-tf`)
- Storage Account (e.g. `stlabtwentythree`)
- Blob Container for Terraform state (e.g. `terraform-state-nextcloud`)

## Required GitHub Secrets / Variables

### Organization variables (non-secret):
- `AZURE_TF_STATE_ACCOUNT` - Storage account name
- `AZURE_TF_STATE_RG` - Resource group name
- `AZURE_TF_STATE_CONTAINER` - Blob container name
- `PORTAINER_URL` - Portainer base URL (e.g. `https://portainer.example.com`)
- `PORTAINER_ENDPOINT_ID` - Portainer endpoint ID
- `NEXTCLOUD_DOMAIN` - Domain for Nextcloud
- `ARM_CLIENT_ID` - Azure AD application client ID
- `ARM_SUBSCRIPTION_ID` - Azure subscription ID
- `ARM_TENANT_ID` - Azure AD tenant ID

### Organization secrets:
- `PORTAINER_TOKEN` - Portainer API token
- `GH_PAT` - GitHub Personal Access Token (for Portainer to clone private repos)
- `CLOUDFLARE_TUNNEL_TOKEN` - Cloudflare Tunnel token
- `DB_PASSWORD` - PostgreSQL database password
- `REDIS_PASSWORD` - Redis password

## Terraform Resources

The main resource is `portainer_stack` which:
- Deploys a Docker Compose stack from a Git repository
- Passes environment variables to the stack
- Supports automatic image pulling and force updates

## Local Development

```bash
# Initialize Terraform (requires Azure login)
az login
terraform init \
  -backend-config="resource_group_name=rg-lab-twentythree-tf" \
  -backend-config="storage_account_name=stlabtwentythree" \
  -backend-config="container_name=terraform-state-nextcloud" \
  -backend-config="key=lab-nextcloud/development.tfstate" \
  -backend-config="use_azuread_auth=true"

# Plan
terraform plan -var-file="dev.tfvars"

# Apply
terraform apply -var-file="dev.tfvars"
```

Automated setup (no `jq`) — create App Registration, add federated credential, assign role, and set GitHub variables/secrets

Replace the placeholders (`ORG`, `REPO`, `BRANCH`, `SUBSCRIPTION_ID`, etc.) before running the commands.

```bash
# variables -- edit these
ORG=your-org-or-user
REPO=lab-nextcloud
BRANCH=main
APP_NAME=github-actions-lab-nextcloud
SUBSCRIPTION_ID=<your-subscription-id>
RG=rg-lab-twentythree-tf
SA=stlabtwentythree
CONTAINER=terraform-state-nextcloud

# Create app registration and get identifiers
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
APP_OBJECT_ID=$(az ad app show --id "$APP_ID" --query id -o tsv)

# Create a service principal for the app
az ad sp create --id "$APP_ID"

# Create the federated credential JSON body (replace ORG/REPO/BRANCH)
SUBJECT="repo:${ORG}/${REPO}:ref:refs/heads/${BRANCH}"
cat > /tmp/gh-federation.json <<EOF
{
	"name": "gh-actions-federation",
	"issuer": "https://token.actions.githubusercontent.com",
	"subject": "${SUBJECT}",
	"audiences": ["api://AzureADTokenExchange"]
}
EOF

# Create federated credential (requires permissions to call Microsoft Graph via az)
az rest --method POST --uri "https://graph.microsoft.com/v1.0/applications/${APP_OBJECT_ID}/federatedIdentityCredentials" --body @/tmp/gh-federation.json

# Assign Storage Blob Data Contributor on the storage account to the SP
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query objectId -o tsv)
SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${SA}"
az role assignment create --assignee-object-id "$SP_OBJECT_ID" --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope "$SCOPE"

# Optional: confirm role assignment
az role assignment list --assignee-object-id "$SP_OBJECT_ID" --scope "$SCOPE" --query '[].{role:roleDefinitionName,scope:scope}' -o table

# Set GitHub org variables (replace --org with --repo for repo-level variables)
gh variable set AZURE_TF_STATE_ACCOUNT --body "$SA" --org "$ORG"
gh variable set AZURE_TF_STATE_RG --body "$RG" --org "$ORG"
gh variable set PORTAINER_URL --body "https://portainer.example.com" --org "$ORG"
gh variable set PORTAINER_ENDPOINT_ID --body "1" --org "$ORG"
gh variable set ARM_CLIENT_ID --body "$APP_ID" --org "$ORG"
gh variable set ARM_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --org "$ORG"
gh variable set ARM_TENANT_ID --body "$(az account show --query tenantId -o tsv)" --org "$ORG"

# Set repo variable for container if desired (no --org)
gh variable set AZURE_TF_STATE_CONTAINER --body "$CONTAINER" --repo "${ORG}/${REPO}"

# Set org secrets (federated method avoids client secret, but set PORTAINER_TOKEN)
gh secret set PORTAINER_TOKEN --body "$(read -s -p 'Portainer token: ' token && echo "$token")" --org "$ORG"

``` 

Notes:
- The `az rest` call requires that your az login has the needed Graph permissions; run it as a user with rights to update the App Registration.
- If you prefer to use a client secret instead of federation, create one via `az ad app credential reset --id "$APP_ID" --append --credential-description "ci-secret"` and store the value as the org secret `ARM_CLIENT_SECRET` (not recommended).

Usage from GitHub Actions: the workflow will `checkout`, authenticate with Azure (via `azure/login` using service principal or OIDC), then run `terraform init` (with backend-config), `plan` and `apply`.

Backend notes:
- This configuration uses the AzureRM backend stored in a Blob Container. The backend configuration must be provided during `terraform init` (backend configs cannot reference variables).
- To authenticate to the storage account without a storage key, use Azure AD authentication by passing `-backend-config="use_azuread_auth=true"` to `terraform init` and ensuring the identity used by the runner has the `Storage Blob Data Contributor` role on the storage account or container.

Example `terraform init` from CI (uses repository variables `AZURE_TF_STATE_*`):

```
terraform init \
	-backend-config="resource_group_name=${AZURE_TF_STATE_RG}" \
	-backend-config="storage_account_name=${AZURE_TF_STATE_ACCOUNT}" \
	-backend-config="container_name=${AZURE_TF_STATE_CONTAINER}" \
	-backend-config="key=lab-nextcloud/${ENVIRONMENT}.tfstate" \
	-backend-config="use_azuread_auth=true"
```

The identity used by the runner (service principal or federated identity) must be granted the `Storage Blob Data Contributor` role on the storage account/container so `use_azuread_auth=true` can access the state.

Notes:
- This is a skeleton using the community Portainer provider as a placeholder. You may need to adjust provider/resource names or use a custom script if your Portainer API differs.
