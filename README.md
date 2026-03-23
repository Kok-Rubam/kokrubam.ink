# kokrubam.ink

**[kokrubam.ink](https://kokrubam.ink)** — Kokborok-English dictionary website powered by [dictpress](https://github.com/knadh/dictpress).

**kokrubam** (ককরুবম) is the Kokborok word for "dictionary" — from *kok* (word) + *rubam* (collection).

## Deploy

```bash
# First time — clone and run:
git clone git@github.com:Kok-Rubam/kokrubam.ink.git
cd kokrubam.ink
sudo ./deploy.sh

# Subsequent deploys — just run:
cd ~/kokrubam.ink
sudo ./deploy.sh
```

The script auto-detects first-time vs subsequent runs:
- **First time:** installs Rust, builds dictpress from source (ARM64), sets up nginx + systemd
- **Every run:** pulls latest, reimports dictionary data, restarts services, health check

## Manual Steps (First Time Only)

1. Change admin password in `/opt/dictpress/config.toml`
2. Create Cloudflare Origin CA certificate and save to `/etc/ssl/cloudflare/`
3. Open ports 80/443 in OCI Security List
4. Fix iptables: add 80/443 BEFORE the REJECT line in `/etc/iptables/rules.v4`
5. Point kokrubam.ink DNS to server via Cloudflare (proxied, Full Strict SSL)

## Structure

```
deploy.sh                # combined setup + deploy script
config.toml              # dictpress configuration
data/kokborok-en.csv     # dictionary data (~10,000 entries)
nginx/kokrubam.ink       # nginx reverse proxy config
systemd/dictpress.service # systemd unit file
site/                    # dictpress theme (Bengali headwords, Alar-style UI)
```

## Data Source

Dictionary authored by **Bishnu Charan Debbarma**.

## License

[MIT](LICENSE)
