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

3. Install Portainer (recommended as a Docker stack / container)

```bash
# create volumes
sudo docker volume create portainer_data

# recommended: run Portainer with Docker Compose or as a stack. Quick run:
sudo docker run -d --name portainer --restart=always \
  -p 9000:9000 -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data portainer/portainer-ce:latest
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
