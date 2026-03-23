#!/bin/bash
set -euo pipefail

# kokrubam.ink — combined setup + deploy script
# Usage: sudo ./deploy.sh
#
# First run: installs deps, builds dictpress, sets up nginx + systemd
# Subsequent runs: pulls latest, reimports data, restarts services

DEPLOY_DIR="/opt/dictpress"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DICTPRESS_SRC="/tmp/dictpress-build"
DB_FILE="kokrubam.db"

echo ""
echo "=== kokrubam.ink deploy ==="
echo "  Repo:   $REPO_DIR"
echo "  Deploy: $DEPLOY_DIR"
echo ""

# -------------------------------------------------------
# 1. Pull latest changes
# -------------------------------------------------------
echo "[1/8] Pulling latest changes..."
cd "$REPO_DIR"
git pull --ff-only || echo "  (git pull skipped — may not be a git repo)"

# -------------------------------------------------------
# 2. System dependencies (skip if nginx already installed)
# -------------------------------------------------------
if ! command -v nginx &> /dev/null; then
    echo "[2/8] Installing system dependencies..."
    apt update
    apt install -y build-essential pkg-config git nginx
else
    echo "[2/8] System dependencies already installed. Skipping."
fi

# -------------------------------------------------------
# 3. Rust toolchain (skip if cargo exists)
# -------------------------------------------------------
if ! sudo -u "$SUDO_USER" bash -c 'source ~/.cargo/env 2>/dev/null && command -v cargo' &> /dev/null; then
    echo "[3/8] Installing Rust toolchain..."
    sudo -u "$SUDO_USER" bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
else
    echo "[3/8] Rust already installed. Skipping."
fi

# -------------------------------------------------------
# 4. Build dictpress binary (skip if binary exists)
# -------------------------------------------------------
if [ ! -f "$DEPLOY_DIR/dictpress" ]; then
    echo "[4/8] Building dictpress from source (this may take 5-10 min)..."
    if [ ! -d "$DICTPRESS_SRC" ]; then
        sudo -u "$SUDO_USER" git clone https://github.com/knadh/dictpress.git "$DICTPRESS_SRC"
    fi
    sudo -u "$SUDO_USER" bash -c "source ~/.cargo/env && cd $DICTPRESS_SRC && cargo build --release"
    mkdir -p "$DEPLOY_DIR"
    cp "$DICTPRESS_SRC/target/release/dictpress" "$DEPLOY_DIR/"
else
    echo "[4/8] dictpress binary exists. Skipping build."
fi

# -------------------------------------------------------
# 5. Copy config + site theme
# -------------------------------------------------------
echo "[5/8] Deploying config and theme..."
mkdir -p "$DEPLOY_DIR/site/pages" "$DEPLOY_DIR/site/static"
cp "$REPO_DIR/config.toml" "$DEPLOY_DIR/"
cp -r "$REPO_DIR/site/"* "$DEPLOY_DIR/site/"

# -------------------------------------------------------
# 6. Stop, reimport data, restart dictpress
# -------------------------------------------------------
echo "[6/8] Importing dictionary data..."
systemctl stop dictpress 2>/dev/null || true

cd "$DEPLOY_DIR"
rm -f "$DB_FILE"
./dictpress --db="$DB_FILE" install
cp "$REPO_DIR/data/kokborok-en.csv" "$DEPLOY_DIR/"
./dictpress --db="$DB_FILE" import --file=kokborok-en.csv

# Service user + permissions
id dictpress &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin dictpress
chown -R dictpress:dictpress "$DEPLOY_DIR"

# -------------------------------------------------------
# 7. Install/restart systemd + nginx (idempotent)
# -------------------------------------------------------
echo "[7/8] Starting services..."
cp "$REPO_DIR/systemd/dictpress.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable dictpress
systemctl start dictpress

cp "$REPO_DIR/nginx/kokrubam.ink" /etc/nginx/sites-available/
ln -sf /etc/nginx/sites-available/kokrubam.ink /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
if [ -f /etc/ssl/cloudflare/kokrubam.ink.pem ]; then
    nginx -t && systemctl reload nginx
else
    echo "  WARNING: No SSL cert at /etc/ssl/cloudflare/kokrubam.ink.pem"
    echo "  nginx not reloaded — add cert first, then: sudo nginx -t && sudo systemctl reload nginx"
fi

# -------------------------------------------------------
# 8. Health check
# -------------------------------------------------------
echo "[8/8] Health check..."
sleep 2
if curl -sf http://127.0.0.1:9000 > /dev/null; then
    echo "  dictpress is running!"
else
    echo "  WARNING: dictpress not responding. Check: journalctl -u dictpress -f"
fi

echo ""
echo "=== Deploy complete! ==="
echo "  Site: https://kokrubam.ink"
echo "  Logs: journalctl -u dictpress -f"
echo ""
