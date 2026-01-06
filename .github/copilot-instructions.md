# Copilot / AI Agent Instructions for lab-nextcloud

Summary
- Short: Docker Compose stack that runs Nextcloud (FPM), PostgreSQL, Redis, Caddy and Cloudflared.
- Primary deploy target: Portainer (Git-backed stacks via Terraform).

What to know before editing
- The canonical compose file is `docker/docker-compose.yml` and expects host paths under `/data/lab-nextcloud-{environment}`.
- Environment variables are passed via Terraform/Portainer, not `.env` files on the host.
- Caddy configuration lives in `docker/Caddyfile`. Nextcloud pre-configuration is in `docker/nextcloud-config.php`.

Architecture & important patterns
- Services:
  - `nextcloud`: image `nextcloud:stable-fpm-alpine` (PHP-FPM). It mounts `nextcloud_data` at `/var/www/html`.
  - `db`: `postgres:16-alpine` using a bind-mounted volume at `/data/lab-nextcloud-{environment}/db`.
  - `redis`: `redis:7-alpine` with a required password from env.
  - `caddy`: `caddy:2-alpine` acts as reverse-proxy and serves files from `/var/www/html`.
  - `cloudflared`: Cloudflare Tunnel; in production it must point to the Caddy container IP (see below).
- Networks:
  - `internal`: internal bridge used for service-to-service communication.
  - `external-services`: an external host network that gives containers outbound access; must exist on the host (name: `external-services`).

Key operational details agents must respect
- Cloudflare Tunnel must be configured to target the Caddy container IP (example in README: `172.25.0.4:80`). Using `caddy:80` causes port/redirect issues. If you change networks or compose ordering, update the README and any automation that computes the IP.
- Volumes are bind-mounted to `/data/lab-nextcloud-{environment}/*`. Any automation that migrates or backs up data should use these host paths.
- Environment variables (`NEXTCLOUD_DOMAIN`, `DB_PASSWORD`, `REDIS_PASSWORD`, `CLOUDFLARE_TUNNEL_TOKEN`, `DATA_PATH`) are passed via Terraform to Portainer. Always reference `terraform/main.tf` and `terraform/variables.tf` when adding/removing envs.
- `trusted_proxies` is set to `caddy` in `docker/nextcloud-config.php` and via env in the compose. If renaming the proxy, update both places.

Developer workflows & useful commands
- **CI/CD deployment**: GitHub Actions in `.github/workflows/` handle automated deployment via Terraform:
  - `deploy.yml`: main workflow triggered on push to `main` (production) or `develop` (development)
  - `deploy-terraform-stack.yml`: reusable workflow handling Azure OIDC auth, Terraform init/plan/apply, and NetBird tunnel
  - `deploy-portainer-stack.yml`: wrapper for backwards compatibility (calls deploy-terraform-stack.yml)
  - Manual trigger: Actions → Deploy to Portainer → Run workflow (select environment)
  - Stack names: `lab-nextcloud-development`, `lab-nextcloud-production`
- **Terraform state**: Stored in Azure Blob Storage with OIDC authentication
- **Change detection**: Git commit SHA is passed to Terraform to trigger updates when compose files change
- Local/Portainer deploy: Use Portainer Stacks (Git or Web editor) as documented in README.md.
- Quick local bring-up (for debugging only):
  - Create host directories shown in README and set proper permissions.
  - `docker compose -f docker/docker-compose.yml up -d`
  - View logs: `docker compose -f docker/docker-compose.yml logs -f caddy nextcloud db redis cloudflared`
- Reset stack (destructive): `docker compose -f docker/docker-compose.yml down -v` (back up `/data/lab-nextcloud-{environment}` first).

Patterns and conventions to follow
- Infrastructure as Code: All deployment configuration is in Terraform (`terraform/` directory). Stack creation and updates go through the Portainer Terraform provider.
- Config-as-data: prefer editing Docker Compose files and Terraform variables rather than in-image changes.
- Security: secrets are passed via GitHub Actions secrets → Terraform → Portainer environment variables. Never commit secrets.
- Networking: services talk over `internal`; internet access comes via `external-services`. Code that needs external network access should be attached to `external-services` (e.g., `nextcloud`, `caddy`, `cloudflared`).

Files to reference when changing behavior
- Compose and services: `docker/docker-compose.yml`
- Reverse proxy: `docker/Caddyfile`
- Nextcloud config example: `docker/nextcloud-config.php`
- Terraform configuration: `terraform/main.tf`, `terraform/variables.tf`
- GitHub Actions deployment: `.github/workflows/deploy.yml` and `.github/workflows/deploy-terraform-stack.yml`
- High level instructions and Cloudflare notes: `README.md`

Examples (copy commands)
- Prepare host directories:
  mkdir -p /data/lab-nextcloud-development/{db,nextcloud,caddy_data,caddy_config}
  chmod -R 755 /data/lab-nextcloud-development
- Run locally for debug:
  docker compose -f docker/docker-compose.yml up -d

If something's unclear
- Ask for the intended deployment target (Portainer via Terraform vs. plain Docker) and whether the `external-services` network exists on the host; these two determine the correct Cloudflared/Caddy setup.

End of file
