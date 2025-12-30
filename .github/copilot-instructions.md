# Copilot / AI Agent Instructions for lab-nextcloud

Summary
- Short: Docker Compose stack that runs Nextcloud (FPM), PostgreSQL, Redis, Caddy and Cloudflared.
- Primary deploy target: Portainer (Git-backed stacks or Web editor).

What to know before editing
- The canonical compose file is `docker/docker-compose.yaml` and expects host paths under `/data/lab-nextcloud`.
- Environment is driven by `.env` (copy from `.env.template`). Never commit `.env`.
- Caddy configuration lives in `docker/Caddyfile`. Nextcloud pre-configuration is in `docker/nextcloud-config.php`.

Architecture & important patterns
- Services:
  - `nextcloud`: image `nextcloud:stable-fpm-alpine` (PHP-FPM). It mounts `nextcloud_data` at `/var/www/html`.
  - `db`: `postgres:16-alpine` using a bind-mounted volume at `/data/lab-nextcloud/db`.
  - `redis`: `redis:7-alpine` with a required password from env.
  - `caddy`: `caddy:2-alpine` acts as reverse-proxy and serves files from `/var/www/html`.
  - `cloudflared`: Cloudflare Tunnel; in production it must point to the Caddy container IP (see below).
- Networks:
  - `internal`: internal bridge used for service-to-service communication.
  - `external-services`: an external host network that gives containers outbound access; must exist on the host (name: `external-services`).

Key operational details agents must respect
- Cloudflare Tunnel must be configured to target the Caddy container IP (example in README: `172.25.0.4:80`). Using `caddy:80` causes port/redirect issues. If you change networks or compose ordering, update the README and any automation that computes the IP.
- Volumes are bind-mounted to `/data/lab-nextcloud/*`. Any automation that migrates or backs up data should use these host paths.
- Nextcloud runtime config uses environment variables in the compose file (e.g., `NEXTCLOUD_DOMAIN`, `DB_PASSWORD`, `REDIS_PASSWORD`). Always reference `docker/docker-compose.yaml` when adding/removing envs.
- `trusted_proxies` is set to `caddy` in `docker/nextcloud-config.php` and via env in the compose. If renaming the proxy, update both places.

Developer workflows & useful commands
- **CI/CD deployment**: GitHub Actions in `.github/workflows/` handle automated deployment to Portainer:
  - `deploy.yml`: main workflow triggered on push to `main` (production) or `develop` (development)
  - `deploy-portainer-stack.yml`: reusable workflow handling NetBird tunnel, SCP file transfer, and Portainer API calls
  - Manual trigger: Actions → Deploy to Portainer → Run workflow (select environment)
  - Stack names: `lab-nextcloud-development`, `lab-nextcloud-production`
- Local/Portainer deploy: Use Portainer Stacks (Git or Web editor) as documented in README.md.
- Quick local bring-up (for debugging only):
  - Create host directories shown in README and set proper permissions.
  - `docker compose -f docker/docker-compose.yaml up -d`
  - View logs: `docker compose -f docker/docker-compose.yaml logs -f caddy nextcloud db redis cloudflared`
- Reset stack (destructive): `docker compose -f docker/docker-compose.yaml down -v` (back up `/data/lab-nextcloud` first).

Patterns and conventions to follow
- Config-as-data: prefer editing `.env.template` and host-mounted files (`docker/Caddyfile`, `docker/nextcloud-config.php`) rather than in-image changes.
- Security: secrets live in `.env` and are not committed. If creating automation, use secret stores or CI environment variables instead of committing passwords.
- Networking: services talk over `internal`; internet access comes via `external-services`. Code that needs external network access should be attached to `external-services` (e.g., `nextcloud`, `caddy`, `cloudflared`).

Files to reference when changing behavior
- Compose and services: `docker/docker-compose.yaml`
- Reverse proxy: `docker/Caddyfile`
- Nextcloud config example: `docker/nextcloud-config.php`
- High level instructions and Cloudflare notes: `README.md`
- GitHub Actions deployment: `.github/workflows/deploy.yml` and `.github/workflows/deploy-portainer-stack.yml`

Examples (copy commands)
- Prepare host directories:
  mkdir -p /data/lab-nextcloud/{db,nextcloud,caddy_data,caddy_config}
  chmod -R 755 /data/lab-nextcloud
- Run locally for debug:
  docker compose -f docker/docker-compose.yaml up -d

If something's unclear
- Ask for the intended deployment target (Portainer vs. plain Docker) and whether the `external-services` network exists on the host; these two determine the correct Cloudflared/Caddy setup.

End of file
