#!/bin/bash
set -euo pipefail

# kokrubam.ink server setup script
# Run on Oracle Cloud Ubuntu ARM VM
# Usage: sudo ./setup.sh

DEPLOY_DIR="/opt/dictpress"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== kokrubam.ink setup ==="
echo "Repo: $REPO_DIR"
echo "Deploy: $DEPLOY_DIR"
echo ""

# -------------------------------------------------------
# Step 1: Install system dependencies
# -------------------------------------------------------
echo "--- Step 1: Installing dependencies ---"
apt update
apt install -y build-essential pkg-config git nginx

# -------------------------------------------------------
# Step 2: Install Rust (if not present)
# -------------------------------------------------------
if ! command -v cargo &> /dev/null; then
    echo "--- Step 2: Installing Rust ---"
    sudo -u "$SUDO_USER" bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
    source "/home/$SUDO_USER/.cargo/env"
else
    echo "--- Step 2: Rust already installed ---"
    source "/home/$SUDO_USER/.cargo/env" 2>/dev/null || true
fi

# -------------------------------------------------------
# Step 3: Build dictpress from source
# -------------------------------------------------------
echo "--- Step 3: Building dictpress (this may take 5-10 minutes) ---"
DICTPRESS_SRC="/tmp/dictpress-build"
if [ ! -d "$DICTPRESS_SRC" ]; then
    git clone https://github.com/knadh/dictpress.git "$DICTPRESS_SRC"
fi
cd "$DICTPRESS_SRC"
sudo -u "$SUDO_USER" bash -c "source ~/.cargo/env && cd $DICTPRESS_SRC && cargo build --release"

# -------------------------------------------------------
# Step 4: Set up deployment directory
# -------------------------------------------------------
echo "--- Step 4: Setting up $DEPLOY_DIR ---"
mkdir -p "$DEPLOY_DIR"
cp "$DICTPRESS_SRC/target/release/dictpress" "$DEPLOY_DIR/"
cp "$REPO_DIR/config.toml" "$DEPLOY_DIR/"

# Generate default site theme if not present
if [ ! -d "$DEPLOY_DIR/site" ]; then
    cd "$DEPLOY_DIR"
    ./dictpress new-config 2>/dev/null || true
fi

# Copy custom site theme if present in repo
if [ -d "$REPO_DIR/site" ]; then
    cp -r "$REPO_DIR/site/"* "$DEPLOY_DIR/site/"
fi

# -------------------------------------------------------
# Step 5: Initialize database and import data
# -------------------------------------------------------
echo "--- Step 5: Initializing database ---"
cd "$DEPLOY_DIR"
./dictpress --db=kokrubam.db install 2>/dev/null || echo "  (database may already exist)"

echo "--- Step 5b: Importing dictionary data ---"
cp "$REPO_DIR/data/kokborok-en.csv" "$DEPLOY_DIR/"
./dictpress import --file=kokborok-en.csv
echo "  Import complete."

# -------------------------------------------------------
# Step 6: Create service user and set permissions
# -------------------------------------------------------
echo "--- Step 6: Setting up service user ---"
id dictpress &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin dictpress
chown -R dictpress:dictpress "$DEPLOY_DIR"

# -------------------------------------------------------
# Step 7: Install systemd service
# -------------------------------------------------------
echo "--- Step 7: Installing systemd service ---"
cp "$REPO_DIR/systemd/dictpress.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable dictpress
systemctl restart dictpress
echo "  dictpress service started."

# -------------------------------------------------------
# Step 8: Install nginx config
# -------------------------------------------------------
echo "--- Step 8: Configuring nginx ---"
cp "$REPO_DIR/nginx/kokrubam.ink" /etc/nginx/sites-available/
ln -sf /etc/nginx/sites-available/kokrubam.ink /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Check if SSL certs exist
if [ ! -f /etc/ssl/cloudflare/kokrubam.ink.pem ]; then
    echo ""
    echo "  WARNING: Cloudflare Origin CA certificate not found!"
    echo "  Create it in Cloudflare Dashboard > SSL/TLS > Origin Server"
    echo "  Then save to:"
    echo "    /etc/ssl/cloudflare/kokrubam.ink.pem"
    echo "    /etc/ssl/cloudflare/kokrubam.ink-key.pem"
    echo ""
    echo "  Skipping nginx reload (will fail without SSL cert)."
    echo "  After adding certs, run: sudo nginx -t && sudo systemctl reload nginx"
else
    nginx -t && systemctl reload nginx
    echo "  nginx configured and reloaded."
fi

# -------------------------------------------------------
# Done
# -------------------------------------------------------
echo ""
echo "=== Setup complete! ==="
echo ""
echo "Remaining manual steps:"
echo "  1. Change admin password in $DEPLOY_DIR/config.toml"
echo "  2. Add Cloudflare Origin CA cert (if not done above)"
echo "  3. Open ports 80/443 in OCI Security List"
echo "  4. Fix iptables: add 80/443 BEFORE the REJECT rule in /etc/iptables/rules.v4"
echo "  5. Point kokrubam.ink DNS to this VM via Cloudflare (proxied)"
echo "  6. Set Cloudflare SSL mode to Full (Strict)"
echo ""
echo "Test locally: curl http://127.0.0.1:9000"
echo "Service logs: journalctl -u dictpress -f"
