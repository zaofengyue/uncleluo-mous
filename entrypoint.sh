#!/bin/sh
set -eu

export TERM="${TERM:-xterm}"
export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"

UUID_FILE="/etc/uuid.txt"

if [ -n "${UUID:-}" ]; then
  echo "$UUID" > "$UUID_FILE"
elif [ -f "$UUID_FILE" ]; then
  UUID="$(cat "$UUID_FILE")"
else
  UUID="$(cat /proc/sys/kernel/random/uuid)"
  echo "$UUID" > "$UUID_FILE"
fi

NGINX_PORT="${PORT:-8080}"
V2RAY_PORT="3000"
WS_PATH="/fengyue"

PLATFORM=""
if [ -n "${DOMAIN:-}" ]; then
  HOST="$DOMAIN"
elif [ -n "${VCAP_APPLICATION:-}" ]; then
  HOST="$(echo "$VCAP_APPLICATION" | jq -r '.application_uris[0] // empty' 2>/dev/null || true)"
  if [ -z "$HOST" ]; then
    HOST="$(echo "$VCAP_APPLICATION" \
      | grep -oE '"application_uris":\[[^]]+\]' \
      | sed -n 's/.*\[\s*"\([^"]\+\)".*/\1/p' | head -n1 || true)"
  fi
  PLATFORM="CloudFoundry"
elif [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  HOST="$RAILWAY_PUBLIC_DOMAIN"
  PLATFORM="Railway"
elif [ -n "${RENDER_EXTERNAL_HOSTNAME:-}" ]; then
  HOST="$RENDER_EXTERNAL_HOSTNAME"
  PLATFORM="Render"
elif [ -n "${ZEABUR_DOMAIN:-}" ]; then
  HOST="$ZEABUR_DOMAIN"
  PLATFORM="Zeabur"
elif [ -n "${KOYEB_PUBLIC_DOMAIN:-}" ]; then
  HOST="$KOYEB_PUBLIC_DOMAIN"
  PLATFORM="Koyeb"
else
  HOST="$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || \
          curl -s --max-time 5 https://ip.sb 2>/dev/null || \
          echo 'your-domain.com')"
fi

COUNTRY="$(curl -s --max-time 5 https://ipinfo.io/country 2>/dev/null || \
           curl -s --max-time 5 https://ifconfig.co/country-iso 2>/dev/null || \
           echo '')"

if [ -n "${NAME:-}" ]; then
  NAME="$NAME"
elif [ -n "$PLATFORM" ]; then
  NAME="${COUNTRY:+${COUNTRY}-}${PLATFORM}"
else
  ASN_ORG="$(curl -s --max-time 5 https://ipinfo.io/org 2>/dev/null || \
             curl -s --max-time 5 https://ifconfig.co/org 2>/dev/null || \
             echo '')"
  ASN_ORG="$(echo "$ASN_ORG" \
    | sed 's/^AS[0-9]* //' \
    | sed 's/,\? *Inc\.$//' \
    | sed 's/,\? *LLC\.*//' \
    | sed 's/,\? *Ltd\.*//' \
    | sed 's/,\? *Corp\.*//' \
    | sed 's/ *$//' \
    | cut -c1-20)"
  if [ -n "$COUNTRY" ] && [ -n "$ASN_ORG" ]; then
    NAME="${COUNTRY}-${ASN_ORG}"
  elif [ -n "$COUNTRY" ]; then
    NAME="${COUNTRY}-mous"
  else
    NAME="mous"
  fi
fi

cat > /etc/v2ray-config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": ${V2RAY_PORT},
    "listen": "127.0.0.1",
    "protocol": "vmess",
    "settings": {
      "clients": [{ "id": "${UUID}", "alterId": 0 }]
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": { "path": "${WS_PATH}" }
    }
  }],
  "outbounds": [{ "protocol": "freedom", "settings": {} }]
}
EOF

VMESS_JSON="$(cat <<EOT
{
  "v": "2",
  "ps": "${NAME}",
  "add": "${HOST}",
  "port": "443",
  "id": "${UUID}",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "${HOST}",
  "path": "${WS_PATH}",
  "tls": "tls"
}
EOT
)"

VMESS_LINK="vmess://$(printf '%s' "$VMESS_JSON" | base64 -w 0 2>/dev/null || printf '%s' "$VMESS_JSON" | base64)"

echo "================= VMESS ================="
echo "$VMESS_LINK"
echo "========================================="

SUB_CONTENT="$(printf '%s' "$VMESS_LINK" | base64 -w 0 2>/dev/null || printf '%s' "$VMESS_LINK" | base64)"

mkdir -p /var/www/html/sub
cp /index.html /var/www/html/index.html
printf '%s' "$SUB_CONTENT" > /var/www/html/sub/index.html

cat > /etc/nginx/sites-available/default <<NGINX
server {
    listen ${NGINX_PORT};
    server_name _;

    location / {
        root /var/www/html;
        index index.html;
    }

    location /sub {
        root /var/www/html;
        index index.html;
        default_type text/plain;
    }

    location ${WS_PATH} {
        proxy_pass http://127.0.0.1:${V2RAY_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
NGINX

nginx -g 'daemon off;' &

V2RAY_BIN=""
if command -v v2ray >/dev/null 2>&1; then
  V2RAY_BIN="$(command -v v2ray)"
else
  for p in /usr/local/bin/v2ray /usr/bin/v2ray /usr/local/v2ray/v2ray; do
    [ -x "$p" ] && V2RAY_BIN="$p" && break
  done
fi

if [ -z "$V2RAY_BIN" ]; then
  echo "FATAL: v2ray 未找到"
  exit 127
fi

exec "$V2RAY_BIN" run -config /etc/v2ray-config.json
