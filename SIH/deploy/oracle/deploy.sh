#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
env_file="$script_dir/.env"
repo_dir="${REPO_DIR:-$HOME/sih}"
branch="master"

if [[ ! -f "$env_file" ]]; then
    echo "Copy .env.example to .env and set REPO_URL and RFSCHEDULER_ALLOWED_ORIGINS." >&2
    exit 1
fi
set -a
# shellcheck disable=SC1090
source "$env_file"
set +a
if [[ -z "${REPO_URL:-}" || "$REPO_URL" == *OWNER/REPO.git ]]; then
    echo "Set REPO_URL in $env_file before deploying." >&2
    exit 1
fi
if [[ -z "${RFSCHEDULER_ALLOWED_ORIGINS:-}" || "$RFSCHEDULER_ALLOWED_ORIGINS" == *your-project.vercel.app* ]]; then
    echo "Set RFSCHEDULER_ALLOWED_ORIGINS to the Vercel site origin." >&2
    exit 1
fi

sudo apt-get update
sudo apt-get install -y ca-certificates curl git
if ! command -v docker >/dev/null 2>&1 || ! sudo docker compose version >/dev/null 2>&1; then
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    . /etc/os-release
    printf 'Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/docker.asc\n' \
        "${UBUNTU_CODENAME:-$VERSION_CODENAME}" "$(dpkg --print-architecture)" \
        | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
sudo systemctl enable --now docker

sudo tee /usr/local/sbin/oracle-deploy-open-ports >/dev/null <<'PORTS'
#!/bin/sh
set -eu
for port in 80 443; do
    iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null \
        || iptables -I INPUT 1 -p tcp --dport "$port" -j ACCEPT
done
PORTS
sudo chmod 755 /usr/local/sbin/oracle-deploy-open-ports
sudo tee /etc/systemd/system/oracle-deploy-ports.service >/dev/null <<'UNIT'
[Unit]
Description=Allow HTTP and HTTPS through the Oracle Ubuntu host firewall
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/oracle-deploy-open-ports
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable oracle-deploy-ports.service
sudo systemctl restart oracle-deploy-ports.service

export GIT_LFS_SKIP_SMUDGE=1
if [[ ! -d "$repo_dir/.git" ]]; then
    git clone --branch "$branch" --single-branch "$REPO_URL" "$repo_dir"
else
    git -C "$repo_dir" fetch origin "$branch"
    git -C "$repo_dir" switch "$branch"
    git -C "$repo_dir" merge --ff-only "origin/$branch"
fi

target_dir="$repo_dir/deploy/oracle"
mkdir -p "$target_dir/checkpoints"
if [[ "$(cd "$script_dir" && pwd -P)" != "$(cd "$target_dir" && pwd -P)" ]]; then
    if [[ ! -f "$script_dir/checkpoints/index.json" ]]; then
        echo "Place the checkpoint index and model files in $script_dir/checkpoints first." >&2
        exit 1
    fi
    sudo cp -a "$script_dir/checkpoints/." "$target_dir/checkpoints/"
fi
if [[ ! -f "$target_dir/checkpoints/index.json" ]]; then
    echo "Missing $target_dir/checkpoints/index.json." >&2
    exit 1
fi
sudo chown -R 10001:10001 "$target_dir/checkpoints"

if [[ -z "${PUBLIC_HOST:-}" ]]; then
    public_ip="$(curl -fsS --max-time 10 https://api.ipify.org)"
    if [[ ! "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Could not determine the VM public IPv4; set PUBLIC_HOST in .env." >&2
        exit 1
    fi
    PUBLIC_HOST="${public_ip//./-}.sslip.io"
fi
if [[ "$(cd "$script_dir" && pwd -P)" != "$(cd "$target_dir" && pwd -P)" ]]; then
    cp "$env_file" "$target_dir/.env"
fi
sed -i '/^PUBLIC_HOST=/d' "$target_dir/.env"
printf '\nPUBLIC_HOST=%s\n' "$PUBLIC_HOST" >> "$target_dir/.env"

cd "$target_dir"
sudo env COMPOSE_PARALLEL_LIMIT=1 docker compose --env-file .env up -d --build --remove-orphans
curl --retry 30 --retry-delay 5 --retry-all-errors --max-time 10 --fail \
    "https://$PUBLIC_HOST/health"
echo "Backend healthy at https://$PUBLIC_HOST"
