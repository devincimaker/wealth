#!/usr/bin/env bash
# Deploys the wealth server to the box, from the Mac:
#   bash server/deploy/deploy.sh
# Builds the image ON the box (tar context over ssh, no registry), ships the
# compose file and the ingress guard, brings the stack up, and installs the
# ingress cron. /opt/wealth/.env is created once by hand and never touched here.
set -euo pipefail
cd "$(dirname "$0")/.."

HOST=deploy@91.98.45.41

tar czf - --exclude node_modules --exclude .env --exclude deploy . |
  ssh -o BatchMode=yes "$HOST" 'docker build -t wealth-server:latest -'

scp -o BatchMode=yes compose.yml deploy/ensure-ingress.sh "$HOST:/opt/wealth/"

ssh -o BatchMode=yes "$HOST" '
  set -euo pipefail
  chmod +x /opt/wealth/ensure-ingress.sh
  cd /opt/wealth && docker compose up -d
  # An empty crontab and a no-match grep both exit nonzero; neither is an error here.
  { crontab -l 2>/dev/null || true; } | { grep -v ensure-ingress.sh || true; } > /tmp/wealth-cron
  echo "* * * * * /opt/wealth/ensure-ingress.sh >> /opt/wealth/ingress.log 2>&1" >> /tmp/wealth-cron
  crontab /tmp/wealth-cron && rm /tmp/wealth-cron
  /opt/wealth/ensure-ingress.sh
'

for _ in $(seq 1 15); do
  if curl -sf -m 5 https://wealth.91.98.45.41.nip.io/health > /dev/null; then
    echo "wealth-server healthy"
    exit 0
  fi
  sleep 2
done
echo "Error: wealth-server did not become healthy" >&2
exit 1
