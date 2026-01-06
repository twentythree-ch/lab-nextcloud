# Nextcloud with Cloudflare Tunnel - Portainer Stack

This repository contains a Docker Compose stack for running Nextcloud with a Cloudflare Tunnel, designed to be deployed via Portainer with automated GitHub Actions CI/CD using Terraform.

## Architecture

- **Nextcloud**: Self-hosted cloud storage (FPM Alpine version)
- **PostgreSQL**: Database backend
- **Redis**: Caching layer
- **Caddy**: Reverse proxy and web server
- **Cloudflared**: Cloudflare Tunnel for secure external access

## Deployment Options

This stack supports two deployment methods:

1. **Automated CI/CD (Recommended)**: Push to `develop` or `main` branch triggers automatic deployment via GitHub Actions with Terraform
2. **Manual Portainer**: Deploy directly through Portainer UI

## Network Configuration

- **internal**: Internal network for communication between services (isolated)
- **external-services**: Your existing bridge network (172.25.0.0/24) for outbound connectivity

## GitHub Actions CI/CD Setup

The deployment uses **Terraform** with the **Portainer provider** to manage stacks declaratively. This provides:
- Infrastructure as Code (IaC) for reproducible deployments
- State management via Azure Blob Storage
- Automatic drift detection and remediation
- Git commit-based change detection

### Architecture

```
GitHub Actions
    │
    ├── Azure OIDC Login (for Terraform state backend)
    │
    ├── Terraform Init (Azure Blob Storage backend)
    │
    ├── NetBird Tunnel (secure connectivity to Portainer)
    │
    ├── Terraform Plan (detect changes)
    │
    └── Terraform Apply (deploy via Portainer API)
```

### Required Secrets and Variables

Configure the following in your GitHub repository:

#### Organization/Repository Secrets

- `NETBIRD_SETUP_KEY` - NetBird tunnel connection key for secure access to Portainer
- `PORTAINER_TOKEN` - API token for Portainer access
- `GH_PAT` - GitHub Personal Access Token for Portainer Git integration

#### Organization/Repository Variables

- `PORTAINER_URL` - Portainer URL accessible via NetBird (e.g., `https://192.168.11.2:9443`)
- `PORTAINER_ENDPOINT_ID` - Portainer endpoint ID (typically `2`)
- `ARM_CLIENT_ID` - Azure AD application client ID for OIDC
- `ARM_TENANT_ID` - Azure AD tenant ID
- `ARM_SUBSCRIPTION_ID` - Azure subscription ID
- `AZURE_TF_STATE_RG` - Resource group for Terraform state storage
- `AZURE_TF_STATE_ACCOUNT` - Azure Storage account name
- `AZURE_TF_STATE_CONTAINER` - Blob container name for Terraform state

#### Environment-Level Secrets
Configure these separately for each environment (`development` and `production`):

**Settings → Environments → [environment name] → Add secret**

- `CLOUDFLARE_TUNNEL_TOKEN` - Cloudflare Tunnel token (different per environment)
- `DB_PASSWORD` - PostgreSQL password (different per environment)
- `REDIS_PASSWORD` - Redis password (different per environment)

#### Environment-Level Variables

- `NEXTCLOUD_DOMAIN` - Nextcloud domain name (different per environment)

#### Environment Protection Rules

**Production environment** (Settings → Environments → production):
- ✅ Enable **Required reviewers** and add approvers
- ✅ Optionally set **Wait timer** for additional safety

**Development environment**: No protection rules needed for automatic deployment

### Azure OIDC Setup

For Terraform state management, configure Azure OIDC federation:

1. Create an Azure AD App Registration
2. Add federated credentials for GitHub Actions:
   - Entity type: Environment
   - Organization: your-org
   - Repository: your-repo
   - Environment: development (and production separately)
3. Grant **Storage Blob Data Contributor** role on the storage account

### Deployment Workflow

The GitHub Actions workflow automatically deploys based on branch:

- **Push to `develop`** → Deploys to `development` environment
- **Push to `main`** → Deploys to `production` environment (requires approval)
- **Manual dispatch** → Choose specific environment via Actions tab

**Stack naming:**
- Development: `lab-nextcloud-development`
- Production: `lab-nextcloud-production`

**Data directories on host:**
- Development: `/data/lab-nextcloud-development/`
- Production: `/data/lab-nextcloud-production/`

### Docker Host Configuration

The Docker host must be properly configured before automated deployments:

#### Required Docker Networks

Create the `external-services` network (if not already exists):

```bash
docker network create --driver bridge --subnet 172.25.0.0/24 external-services
```

Verify it exists:
```bash
docker network ls | grep external-services
```

#### Directory Permissions

The Terraform/Portainer deployment expects data directories to exist. Create them:

```bash
# Development environment
sudo mkdir -p /data/lab-nextcloud-development/{db,nextcloud,caddy_data,caddy_config}
sudo chmod -R 755 /data/lab-nextcloud-development

# Production environment
sudo mkdir -p /data/lab-nextcloud-production/{db,nextcloud,caddy_data,caddy_config}
sudo chmod -R 755 /data/lab-nextcloud-production
```

#### NetBird Access

The Docker host must be:
- ✅ Connected to the same NetBird network as GitHub Actions
- ✅ Reachable via the configured Portainer URL through NetBird tunnel

#### Portainer Configuration

Ensure Portainer:
- ✅ Is accessible at the configured `PORTAINER_URL`
- ✅ Has API access enabled
- ✅ Has the correct endpoint ID (typically `2`, stored in `PORTAINER_ENDPOINT_ID`)
- ✅ Can pull from GitHub (requires `GH_PAT` with repo read access)

Test Portainer API access:
```bash
curl -k -H "X-API-Key: YOUR_TOKEN" https://portainer-url:9443/api/endpoints
```

## Prerequisites

1. Docker host with Portainer installed
2. Existing `external-services` network (already created on your host)
3. Cloudflare account with a domain configured
4. Cloudflare Tunnel created
5. Azure subscription with Storage Account for Terraform state
6. NetBird network for secure connectivity
7. Create the data directory on your host:
   ```bash
   mkdir -p /data/lab-nextcloud/{db,nextcloud,caddy_data,caddy_config}
   chmod -R 755 /data/lab-nextcloud
   ```

## Setup Instructions

### Automated Deployment (GitHub Actions with Terraform)

Once secrets and variables are configured (see "GitHub Actions CI/CD Setup" above):

1. **Initial setup**: Ensure Docker host has `/data` directory and proper permissions
2. **Commit and push** to `develop` branch → auto-deploys to development
3. **Merge to `main`** → triggers production deployment (requires approval)
4. **Monitor**: Check Actions tab for deployment status

The Terraform workflow automatically:
- Connects via NetBird tunnel to Portainer
- Creates or updates Portainer stack from Git repository
- Passes environment variables securely
- Detects changes via git commit SHA and triggers updates

### Manual Deployment via Portainer

#### 5. Configure Cloudflare Tunnel

**IMPORTANT**: Use the IP address of the Caddy container, NOT the hostname, to avoid port resolution issues.

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Networks** > **Tunnels**
3. Create a new tunnel (give it a name like "nextcloud")
4. Copy the tunnel token (you'll need this for the `.env` file)
5. Configure the tunnel:
   - **Public Hostname**: cloud.yourdomain.com
   - **Service Type**: HTTP
   - **Service URL**: `172.25.0.4:80` (use the Caddy container's IP from external-services network, NOT `caddy:80`)
   
   **Why use IP instead of hostname?** Using `caddy:80` can cause Cloudflare Tunnel to incorrectly resolve ports, leading to redirect issues. Using the IP address directly avoids this problem.

#### 2. Prepare Your Repository

1. Create a new GitHub repository
2. Add these files to the repository:
   - `docker-compose.yml`
   - `Caddyfile`
   - `.env.template`
   - `README.md`
   - `.gitignore`
3. **Important**: Create a `.env` file locally (DO NOT commit this to Git!)

### 3. Configure Environment Variables

Copy `.env.template` to `.env` and fill in your values:

```bash
cp .env.template .env
```

Edit `.env` with your values:
- `DB_PASSWORD`: Strong password for PostgreSQL
- `REDIS_PASSWORD`: Strong password for Redis
- `NEXTCLOUD_DOMAIN`: Your domain (e.g., cloud.example.com)
- `CLOUDFLARE_TUNNEL_TOKEN`: Token from Cloudflare Tunnel

**Security Note**: Add `.env` to `.gitignore` to prevent committing secrets!

#### 4. Deploy with Portainer

#### Option A: Deploy from Git Repository

1. In Portainer, go to **Stacks** > **Add stack**
2. Choose **Git Repository**
3. Enter your repository URL
4. Set repository reference (branch): `main` or `master`
5. Specify Compose path: `docker-compose.yml`
6. Add environment variables in Portainer's UI:
   - Click "Add an environment variable" for each variable in `.env.template`
   - Or use "Load variables from .env file" if you have the `.env` file
7. Deploy the stack

##### Option B: Deploy from Web Editor

1. In Portainer, go to **Stacks** > **Add stack**
2. Choose **Web editor**
3. Copy the contents of `docker-compose.yml`
4. Add environment variables in the UI
5. Deploy the stack

#### 5. Initial Nextcloud Setup

1. Wait for all containers to start (check logs in Portainer)
2. Access Nextcloud through your domain (e.g., https://cloud.example.com)
3. Create an admin account on first access
4. Nextcloud will automatically configure itself with PostgreSQL and Redis

#### 6. Post-Installation Configuration

After initial setup, you may want to configure:

- **Background jobs**: Set to Cron (recommended)
- **Email server**: For notifications and password resets
- **File locking**: Already configured with Redis
- **Memory caching**: Already configured with Redis

## File Structure

```
your-repo/
├── docker/
│   ├── docker-compose.yml       # Main Docker Compose configuration
│   ├── Caddyfile                # Caddy reverse proxy configuration
│   └── nextcloud-config.php     # Nextcloud pre-config
├── terraform/
│   ├── main.tf                  # Portainer stack resource definition
│   ├── variables.tf             # Terraform variables
│   └── README.md                # Terraform-specific documentation
├── .github/
│   └── workflows/
│       ├── deploy.yml                    # Main deployment orchestrator
│       ├── deploy-terraform-stack.yml    # Reusable Terraform workflow
│       └── deploy-portainer-stack.yml    # Wrapper (backwards compat)
├── .env.template                # Template for environment variables
├── .gitignore                   # Git ignore file (include .env)
└── README.md                    # This file
```

**Host system:**
```
/data/lab-nextcloud-{environment}/
├── db/                     # PostgreSQL data
├── nextcloud/              # Nextcloud files
├── caddy_data/             # Caddy certificates
└── caddy_config/           # Caddy configuration cache
```

## Updating the Stack

To update your stack in Portainer:

1. Push changes to your GitHub repository
2. In Portainer, go to your stack
3. Click **Pull and redeploy**
4. Portainer will pull the latest changes from Git and redeploy

## Troubleshooting

### Checking Logs

In Portainer, go to your stack and click on individual containers to view logs.

### Common Issues

1. **Cannot access Nextcloud**: 
   - Check Cloudflare Tunnel status in the cloudflared logs
   - Verify tunnel configuration points to `http://172.25.0.4:80` (use IP, not hostname)
   - Check that the tunnel is active in Cloudflare dashboard

2. **Redirects to wrong port (e.g., port 84)**:
   - This happens when using hostname `caddy:80` in Cloudflare Tunnel
   - Solution: Use IP address `172.25.0.4:80` instead
   - Verify in Cloudflare Tunnel settings

3. **Database connection errors**:
   - Ensure `DB_PASSWORD` matches in both Nextcloud and PostgreSQL
   - Check if PostgreSQL container is running

4. **Redis connection issues**:
   - Verify `REDIS_PASSWORD` is set correctly
   - Check Redis container logs

5. **Cannot upload files / folders missing**:
   - Check for broken apps: `docker exec -u www-data <container> php occ app:list`
   - Disable problematic apps: `docker exec -u www-data <container> php occ app:disable <appname>`
   - Common culprits: `organization_folders` (conflicts with `groupfolders`)
   - Check permissions: `docker exec <container> ls -la /var/www/html/data`

6. **Slow app downloads / cannot install apps**:
   - Nextcloud container needs internet access
   - Ensure it's connected to `external-services` network in docker-compose.yml
   - This is already configured in the provided compose file

### Resetting the Stack

To completely reset (WARNING: This deletes all data):

```bash
docker compose down -v
```

Then redeploy through Portainer.

## Security Considerations

- All secrets are stored in environment variables
- Internal network isolates services from external access
- Cloudflare Tunnel provides DDoS protection and doesn't expose ports
- Caddy automatically handles security headers
- Never commit `.env` file to Git

## Backup Strategy

Important directories to backup on your host system:
- PostgreSQL data: `/data/lab-nextcloud/db`
- Nextcloud files: `/data/lab-nextcloud/nextcloud`
- Caddy certificates: `/data/lab-nextcloud/caddy_data`
- Caddy config: `/data/lab-nextcloud/caddy_config`

Consider using Portainer's backup features or setting up automated volume backups.

## Additional Features

### Geographic Access Restrictions with Cloudflare WAF

You can restrict access to your Nextcloud (and other services) to specific countries using Cloudflare's Web Application Firewall:

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Select your domain
3. Navigate to **Security** → **WAF** → **Custom rules**
4. Click **Create rule**

5. **Configure the rule**:
   - **Rule name**: "Block non-allowed countries"
   - **Field**: Country
   - **Operator**: is not in
   - **Value**: Select your allowed countries (e.g., CH, DE, AT, IT, FR, BE, LU, LI, ES, NL)
   - Click **And**
   - **Field**: Hostname
   - **Operator**: is in
   - **Value**: Enter your hostnames (one per line):
     ```
     cloud.vansummeren.ch
     homeassistant.vansummeren.ch
     ```
   - **Then**: Block (or Challenge for CAPTCHA instead)

6. Click **Deploy**

**Benefits:**
- ✅ One rule covers multiple services/tunnels
- ✅ Easy to add/remove countries or hostnames
- ✅ Blocks malicious traffic before it reaches your server
- ✅ Reduces attack surface significantly

**Important**: Test the rule from an allowed country first to avoid locking yourself out!

### SAML Authentication with Microsoft Entra ID

The stack supports SAML SSO with Microsoft Entra ID (Azure AD). To configure:

1. **Install SAML app in Nextcloud**:
   - Log in as admin → Apps → Search for "SSO & SAML authentication"
   - Download and enable

2. **Configure in Azure/Entra ID**:
   - Create Enterprise Application (Non-gallery)
   - Set up SAML with:
     - Entity ID: `https://your-domain.com/apps/user_saml/saml/metadata`
     - Reply URL: `https://your-domain.com/apps/user_saml/saml/acs`
     - Sign-on URL: `https://your-domain.com`

3. **Configure in Nextcloud**:
   - Settings → SSO & SAML authentication
   - Add identity provider with Azure metadata
   - Map attributes (email, displayname, uid)

### Group Folders

The `groupfolders` app is compatible and can be enabled for shared folder management:
```bash
docker exec -u www-data <nextcloud-container> php occ app:enable groupfolders
```

**Note**: Avoid installing `organization_folders` as it conflicts with `groupfolders`.
