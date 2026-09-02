#!/usr/bin/env bash
# Keeps wealth's site in the box's shared Caddyfile (/opt/habitron/Caddyfile).
# Only one process can own ports 80/443, and on this box that is habitron's
# Caddy; thrive's CI overwrites that Caddyfile on every deploy, so wealth's
# site block lives here and a cron re-asserts it (installed by deploy.sh as
# `* * * * *` for the deploy user). Nothing about wealth lives in thrive.
set -euo pipefail

CADDYFILE=/opt/habitron/Caddyfile
MARKER="wealth.91.98.45.41.nip.io"

grep -q "$MARKER" "$CADDYFILE" 2>/dev/null && exit 0

cat >> "$CADDYFILE" << 'EOF'

# Wealth voice-parse service. Appended by /opt/wealth/ensure-ingress.sh (cron,
# from the wealth repo); thrive deploys overwrite this file and the cron heals it.
wealth.91.98.45.41.nip.io {
	encode gzip
	reverse_proxy wealth-server:3002
}
EOF

cd /opt/habitron && docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile
echo "wealth ingress restored to $CADDYFILE"
