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
# create Portainer data directory
sudo mkdir -p /data/portainer
sudo chmod 755 /data/portainer
```

Create a `docker-compose.yml` for Portainer (e.g., in `/data/portainer/docker-compose.yml`):

```yaml
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"   # optional: remove if only accessing via tunnel
      - "9443:9443"   # optional: remove if only accessing via tunnel
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /data/portainer:/data

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
```

> **Note:** Create a Cloudflare Tunnel in the Zero Trust dashboard and configure it to route traffic to `http://portainer:9000`. Set the `CLOUDFLARE_TUNNEL_TOKEN` in a `.env` file in the same directory or pass it directly.

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

Follow official NetBird install instructions; example using their APT repo:

```bash
curl -fsSL https://repo.netbird.io/install.sh | sudo bash
sudo systemctl enable --now netbird
# then use `netbird join <your-join-key>` per NetBird instructions
```

5. Create required Docker network and host directories for lab-nextcloud

The compose expects an `external-services` network to exist on the host and host data directories under `/data/lab-nextcloud-{environment}`.

```bash
sudo docker network create external-services || true
sudo mkdir -p /data/lab-nextcloud-development/{db,nextcloud,caddy_data,caddy_config}
sudo chown -R $USER: /data/lab-nextcloud-development
sudo chmod -R 755 /data/lab-nextcloud-development
```

6. Recommended optional installs

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
