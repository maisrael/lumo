#!/bin/bash
# Probe the UniFi controller with your local (HA) account, using the legacy
# cookie-login flow. Reads credentials from .unifi-creds (gitignored).
#
# Create .unifi-creds next to this script with:
#   HOST="https://192.168.1.1"
#   USERNAME="your-local-unifi-user"
#   PASSWORD="your-password"
#   SITE="default"

set -euo pipefail
cd "$(dirname "$0")"
source .unifi-creds
SITE="${SITE:-default}"
JAR=/tmp/unifi-cookies.txt

echo "== login =="
BODY=$(/opt/homebrew/bin/jq -n --arg u "$USERNAME" --arg p "$PASSWORD" '{username:$u,password:$p}')
code=$(curl -ks -c "$JAR" -o /dev/null -w '%{http_code}' -X POST "$HOST/api/auth/login" \
  -H "Content-Type: application/json" -d "$BODY")
echo "login HTTP $code"
[ "$code" = "200" ] || { echo "login failed"; exit 1; }

echo "== health (WAN + throughput) =="
curl -ks -b "$JAR" "$HOST/proxy/network/api/s/$SITE/stat/health" \
  | /opt/homebrew/bin/jq '.data[] | {subsystem, status, wan_ip, gw_name,
      rx_bytes_r, tx_bytes_r, num_user, num_guest, "latency": .latency, "uptime": .uptime}' 2>/dev/null \
  || echo "health query failed"

echo "== client count =="
curl -ks -b "$JAR" "$HOST/proxy/network/api/s/$SITE/stat/sta" \
  | /opt/homebrew/bin/jq '.data | length' 2>/dev/null || echo "sta query failed"
