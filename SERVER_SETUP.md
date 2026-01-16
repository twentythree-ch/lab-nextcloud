# Server Setup (Ubuntu 25.10)

This document lists the host prerequisites and installation steps required to run the lab-nextcloud Docker stack on Ubuntu 25.10.

## Overview

Needed on the host:
- Docker Engine (container runtime)
- Docker Compose (Compose V2 plugin)
- Portainer (for stack management)
- NetBird (VPN/mesh for remote deployment access)
- Extras: `git`, `curl`, `jq`, `terraform` (optional if you run Terraform locally), `ufw` (recommended firewall)

## Quick setup (commands)
Run these commands as a user with `sudo` privileges.

1. Prepare prerequisites

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release software-properties-common git jq ufw
```

2. Install Docker Engine (official convenience script)

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

Log out and back in (or `newgrp docker`) to apply group changes.

> **Optional: Rootless mode**  
> To run Docker as a non-privileged user without `sudo`, consider rootless mode:
> ```bash
> dockerd-rootless-setuptool.sh install
> ```
> See https://docs.docker.com/go/rootless/ for details.
>
> ⚠️ **Caveats for this stack:**
> - The Docker socket moves to `$XDG_RUNTIME_DIR/docker.sock` (e.g., `/run/user/1000/docker.sock`), so Portainer's `-v /var/run/docker.sock:...` mount must be updated.
> - Bind-mount paths outside your home (like `/data/lab-nextcloud-*`) may fail due to UID remapping. You'd need to relocate data under `~/` or configure subordinate UID/GID mappings.
> - For this stack, **standard (rootful) Docker is simpler**; rootless adds security but requires extra configuration.

3. Install Portainer (recommended as a Docker Compose stack)

```bash
# create Portainer data directories
sudo mkdir -p /data/portainer/{portainer_data,caddy/certs,caddy/caddy_data,caddy/caddy_config}
sudo chmod -R 755 /data/portainer
```

Create a `docker-compose.yml` for Portainer (e.g., in `/data/portainer/docker-compose.yml`):

```yaml
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9000"
      - "8000"
      - "9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /data/portainer/portainer_data:/data
    networks:
      internal:

  caddy:
    image: caddy:alpine
    container_name: portainer2-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /data/portainer/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - /data/portainer/caddy/certs:/etc/caddy/certs:ro
      - /data/portainer/caddy/caddy_data:/data
      - /data/portainer/caddy/caddy_config:/config
    networks:
      internal:  # To communicate with portainer
      external-services:
        ipv4_address: 172.25.0.5
    depends_on:
      - portainer

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: portainer-tunnel
    restart: always
    command: tunnel run
    environment:
      - TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}
      - TUNNEL_TRANSPORT_PROTOCOL=http2
    depends_on:
      - portainer
    networks:
      external-services:
      internal:

networks:
  internal:
    driver: bridge
  external-services:
    external: true
```

> **Note:** 
> - The `external-services` network must exist on the host (created in step 6).
> - Configure your Cloudflare Tunnel to route traffic to `http://172.25.0.5:80` (Caddy's IP).
> - Create a Caddyfile at `/data/portainer/caddy/Caddyfile` to reverse proxy to Portainer.

Example `/data/portainer/caddy/Caddyfile`:

```caddyfile
:80 {
    reverse_proxy portainer:9000 {
        # Required headers for Portainer auth to work behind proxy
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto https

        # WebSocket support (for Portainer real-time updates)
        header_up Connection {>Connection}
        header_up Upgrade {>Upgrade}
    }
}
```

> ⚠️ **Important:** The `X-Forwarded-Proto https` is critical — Cloudflare terminates TLS, so Portainer must know the original request was HTTPS for CSRF validation to pass.

Create a `.env` file in `/data/portainer/.env`:

```bash
# Cloudflare Tunnel token (from Zero Trust dashboard)
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiYWJjZGVm...your-token-here
```

> ⚠️ **Security:** Restrict permissions and never commit secrets:
> ```bash
> sudo chmod 600 /data/portainer/.env
> ```

Then start the stack:

```bash
cd /data/portainer
# Option 1: use .env file with CLOUDFLARE_TUNNEL_TOKEN=<your-token>
sudo docker compose up -d

# Option 2: pass token inline
# CLOUDFLARE_TUNNEL_TOKEN=<your-token> sudo docker compose up -d
```

4. Install NetBird (for remote mesh access)

Install NetBird using the official APT repository:

```bash
# add GPG key and repository
curl -sSL https://pkgs.netbird.io/debian/public.key | sudo gpg --dearmor --output /usr/share/keyrings/netbird-archive-keyring.gpg
echo 'deb [signed-by=/usr/share/keyrings/netbird-archive-keyring.gpg] https://pkgs.netbird.io/debian stable main' | sudo tee /etc/apt/sources.list.d/netbird.list

# install NetBird CLI
sudo apt-get update
sudo apt-get install -y netbird

# enable and start the service
sudo systemctl enable --now netbird
```

Join your NetBird network:

```bash
# Option 1: SSO login (opens browser)
netbird up

# Option 2: use a setup key (for headless servers)
netbird up --setup-key <YOUR_SETUP_KEY>

# check connection status
netbird status
```

> See https://docs.netbird.io/get-started/install/linux for more options.

5. Create deploy user for CI/CD access

Create a restricted `deploy` user that GitHub Actions can use via SSH certificate to manage `/data`:

```bash
# create deploy user (no login shell, restricted)
sudo useradd -r -m -d /home/deploy -s /bin/bash deploy

# create .ssh directory for authorized keys / certificates
sudo mkdir -p /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chown deploy:deploy /home/deploy/.ssh

# add the deploy user's public key or certificate (paste your key here)
echo "ssh-ed25519 AAAA... deploy-key" | sudo tee /home/deploy/.ssh/authorized_keys
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys
```

Grant the deploy user permission to manage `/data` only:

```bash
# give deploy user ownership of /data
sudo mkdir -p /data
sudo chown deploy:deploy /data
sudo chmod 755 /data

# allow deploy user to run specific commands via sudo (optional, for docker compose)
echo 'deploy ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/docker-compose, /usr/libexec/docker/cli-plugins/docker-compose' | sudo tee /etc/sudoers.d/deploy
sudo chmod 440 /etc/sudoers.d/deploy
```

> **Note:** The deploy user can create directories, chmod, and chown within `/data`. For GitHub Actions, store the SSH private key as a repository secret and use it to connect via NetBird IP.

6. Create required Docker network and host directories for lab-nextcloud

The compose expects an `external-services` network to exist on the host and host data directories under `/data/lab-nextcloud-{environment}`.

```bash
sudo docker network create external-services || true
sudo mkdir -p /data/lab-nextcloud-development/{db,nextcloud,caddy_data,caddy_config}
sudo chown -R $USER: /data/lab-nextcloud-development
sudo chmod -R 755 /data/lab-nextcloud-development
```

7. Recommended optional installs

- Terraform (if you plan to run Terraform locally for Portainer/stack deploys)
- `cloudflared` (optional; the repo uses a cloudflared container image so host binary is not required)
- `ufw` rules to restrict access to management ports (e.g., `9000`, `9443`) and allow required ports

Example Terraform install (optional):

```bash
# install Terraform (HashiCorp repository)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
```

## Notes & operational hints
- The stack uses Docker Compose (see `docker/docker-compose.yml`). The Compose V2 plugin (`docker compose`) is installed above.
- Portainer may be run as a container or deployed via the repository's CI/Terraform flow; running it as a container is the quickest.
- NetBird provides remote access for deployments; follow NetBird control-plane instructions to authorize hosts.
- Ensure the `external-services` Docker network exists on the host with the exact name; automation expects this network.
- Back up `/data/lab-nextcloud-{environment}` before destructive operations.

If you want, I can also add a systemd service snippet, stricter `ufw` rules, or CI deployment notes.
