# kokrubam.ink

**[kokrubam.ink](https://kokrubam.ink)** — Kokborok-English dictionary website powered by [dictpress](https://github.com/knadh/dictpress).

**kokrubam** (ককরুবম) is the Kokborok word for "dictionary" — from *kok* (word) + *rubam* (collection).

## Quick Deploy

```bash
# On your Ubuntu server:
git clone git@github.com:Kok-Rubam/kokrubam.ink.git
cd kokrubam.ink
sudo ./setup.sh
```

The setup script builds dictpress from source (ARM64), imports the dictionary data, and configures nginx + systemd.

## Manual Steps After Setup

1. Change admin password in `/opt/dictpress/config.toml`
2. Create Cloudflare Origin CA certificate and save to `/etc/ssl/cloudflare/`
3. Open ports 80/443 in OCI Security List
4. Fix iptables: add 80/443 BEFORE the REJECT line in `/etc/iptables/rules.v4`
5. Point kokrubam.ink DNS to server via Cloudflare (proxied, Full Strict SSL)

## Structure

```
config.toml              # dictpress configuration
data/kokborok-en.csv     # dictionary data (9,841 entries)
nginx/kokrubam.ink       # nginx reverse proxy config
systemd/dictpress.service # systemd unit file
setup.sh                 # automated server setup
site/                    # custom theme (added after initial setup)
```

## Data Source

Dictionary authored by **Bishnu Charan Debbarma**.

## License

[MIT](LICENSE)
