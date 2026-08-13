#!/bin/sh
# olcrtc entrypoint for Railway: builds server.yaml from env vars.
#
# Required:
#   OLCRTC_ROOM_ID   room url/id (for jitsi: https://host/room)
#   OLCRTC_KEY       64 hex chars, or OLCRTC_KEY_FILE path with the key inside
# Optional:
#   OLCRTC_MODE            srv (default) | cnc
#   OLCRTC_AUTH_PROVIDER   jitsi (default) | telemost | wbstream | none
#   OLCRTC_AUTH_TOKEN      wbstream token (optional)
#   OLCRTC_TRANSPORT       datachannel (default) | vp8channel | seichannel | videochannel
#   OLCRTC_DNS             8.8.8.8:53 (default)
#   OLCRTC_DATA            /data (default)
#   OLCRTC_DEBUG           false (default)
#   OLCRTC_SOCKS_PROXY_ADDR/PORT   optional upsage SOCKS5 proxy for srv
#   OLCRTC_SOCKS_PROXY_USER/PASS   optional upstream SOCKS5 credentials (RFC 1929)
#   OLCRTC_SOCKS_ADDR/PORT         cnc listener, default 127.0.0.1:8808
#   OLCRTC_SOCKS_USER/PASS         optional auth for cnc listener
set -e

MODE="${OLCRTC_MODE:-srv}"
PROVIDER="${OLCRTC_AUTH_PROVIDER:-jitsi}"
ROOM="${OLCRTC_ROOM_ID:?OLCRTC_ROOM_ID required}"
TRANSPORT="${OLCRTC_TRANSPORT:-datachannel}"
DNS="${OLCRTC_DNS:-8.8.8.8:53}"
DATA="${OLCRTC_DATA:-/data}"
DEBUG="${OLCRTC_DEBUG:-false}"

if [ -n "${OLCRTC_KEY_FILE:-}" ]; then
    KEY=$(tr -d '[:space:]' <"$OLCRTC_KEY_FILE")
else
    KEY="${OLCRTC_KEY:?OLCRTC_KEY (64 hex) required}"
fi
case "$KEY" in
    *[!0-9a-fA-F]*) echo "invalid crypto key: must be 64 hex chars" >&2; exit 1 ;;
esac
[ "${#KEY}" -eq 64 ] || { echo "crypto key must be 64 hex chars" >&2; exit 1; }

mkdir -p "$DATA"

cat > /olcrtc.yaml <<EOF
mode: $MODE
auth:
  provider: $PROVIDER
EOF
[ -z "${OLCRTC_AUTH_TOKEN:-}" ] || printf '  token: %s\n' "$OLCRTC_AUTH_TOKEN" >> /olcrtc.yaml
printf 'room:\n  id: "%s"\ncrypto:\n  key: %s\n' "$ROOM" "$KEY" >> /olcrtc.yaml
cat >> /olcrtc.yaml <<EOF
net:
  transport: $TRANSPORT
  dns: $DNS
data: $DATA
debug: $DEBUG
EOF

if [ "$MODE" = "srv" ] && [ -n "${OLCRTC_SOCKS_PROXY_ADDR:-}" ]; then
    cat >> /olcrtc.yaml <<EOF
socks:
  proxy_addr: $OLCRTC_SOCKS_PROXY_ADDR
  proxy_port: ${OLCRTC_SOCKS_PROXY_PORT:-1080}
EOF
    if [ -n "${OLCRTC_SOCKS_PROXY_USER:-}" ]; then
        cat >> /olcrtc.yaml <<EOF
  proxy_user: $OLCRTC_SOCKS_PROXY_USER
  proxy_pass: $OLCRTC_SOCKS_PROXY_PASS
EOF
    fi
fi

if [ "$MODE" = "cnc" ]; then
    cat >> /olcrtc.yaml <<EOF
socks:
  host: ${OLCRTC_SOCKS_ADDR:-127.0.0.1}
  port: ${OLCRTC_SOCKS_PORT:-8808}
EOF
    if [ -n "${OLCRTC_SOCKS_USER:-}" ]; then
        cat >> /olcrtc.yaml <<EOF
  user: $OLCRTC_SOCKS_USER
  pass: $OLCRTC_SOCKS_PASS
EOF
    fi
fi

exec /usr/local/bin/olcrtc /olcrtc.yaml