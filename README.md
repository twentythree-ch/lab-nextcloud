# Nextcloud with Cloudflare Tunnel - Portainer Stack

This repository contains a Docker Compose stack for running Nextcloud with a Cloudflare Tunnel, designed to be deployed via Portainer.

## Architecture

- **Nextcloud**: Self-hosted cloud storage (FPM Alpine version)
- **PostgreSQL**: Database backend
- **Redis**: Caching layer
- **Caddy**: Reverse proxy and web server
- **Cloudflared**: Cloudflare Tunnel for secure external access

## Network Configuration

- **internal**: Internal network for communication between services (isolated)
- **external-services**: Your existing bridge network (172.25.0.0/24) for outbound connectivity

## Prerequisites

1. Docker host with Portainer installed
2. Existing `external-services` network (already created on your host)
3. Cloudflare account with a domain configured
4. Cloudflare Tunnel created

## Setup Instructions

### 1. Create Cloudflare Tunnel

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Networks** > **Tunnels**
3. Create a new tunnel (give it a name like "nextcloud")
4. Copy the tunnel token (you'll need this for the `.env` file)
5. Configure the tunnel:
   - **Public Hostname**: your-domain.com (or subdomain)
   - **Service**: HTTP, caddy:80

### 2. Prepare Your Repository

1. Create a new GitHub repository
2. Add these files to the repository:
   - `docker-compose.yml`
   - `Caddyfile`
   - `.env.template`
   - `README.md`
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

### 4. Deploy with Portainer

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

#### Option B: Deploy from Web Editor

1. In Portainer, go to **Stacks** > **Add stack**
2. Choose **Web editor**
3. Copy the contents of `docker-compose.yml`
4. Add environment variables in the UI
5. Deploy the stack

### 5. Initial Nextcloud Setup

1. Wait for all containers to start (check logs in Portainer)
2. Access Nextcloud through your domain (e.g., https://cloud.example.com)
3. Create an admin account on first access
4. Nextcloud will automatically configure itself with PostgreSQL and Redis

### 6. Post-Installation Configuration

After initial setup, you may want to configure:

- **Background jobs**: Set to Cron (recommended)
- **Email server**: For notifications and password resets
- **File locking**: Already configured with Redis
- **Memory caching**: Already configured with Redis

## File Structure

```
your-repo/
├── docker-compose.yml    # Main Docker Compose configuration
├── Caddyfile            # Caddy reverse proxy configuration
├── .env.template        # Template for environment variables
├── .gitignore           # Git ignore file (include .env)
└── README.md            # This file
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
   - Verify tunnel configuration points to `http://caddy:80`

2. **Database connection errors**:
   - Ensure `DB_PASSWORD` matches in both Nextcloud and PostgreSQL
   - Check if PostgreSQL container is running

3. **Redis connection issues**:
   - Verify `REDIS_PASSWORD` is set correctly
   - Check Redis container logs

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

Important directories to backup:
- PostgreSQL data: `db_data` volume
- Nextcloud files: `nextcloud_data` volume
- Caddy certificates: `caddy_data` volume

Consider using Portainer's backup features or setting up automated volume backups.

## License

This configuration is provided as-is for personal use.