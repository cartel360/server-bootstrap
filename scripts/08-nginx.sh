#!/usr/bin/env bash

set -Eeuo pipefail

echo
echo "Configuring Nginx for:"
echo
echo "Application : $APP_NAME"
echo "Domain      : $APP_DOMAIN"
echo "Port        : ${APP_PORT:-"(auto-detect)"}"
echo

# --------------------------------------------------
# Install nginx if needed
# --------------------------------------------------

if ! command -v nginx >/dev/null 2>&1; then

    echo "Installing Nginx..."

    apt-get update
    apt-get install -y nginx

else
    echo "✓ Nginx already installed."
fi

systemctl enable nginx
systemctl start nginx

# --------------------------------------------------
# Existing routes
# --------------------------------------------------

echo
echo "Existing Nginx sites:"
echo "------------------------------------------------------------"

shopt -s nullglob
EXISTING_SITES=(/etc/nginx/sites-enabled/*)
shopt -u nullglob

if ((${#EXISTING_SITES[@]} == 0)); then
    echo "(none)"
else
    for SITE in "${EXISTING_SITES[@]}"; do
        NAME="$(basename "$SITE")"
        SERVER_NAMES="$(awk '/server_name/ {for (i = 2; i <= NF; i++) printf "%s ", $i; print ""}' "$SITE" | tr -d ';' | paste -sd ' ' -)"
        TARGET="$(awk '/proxy_pass/ {print $2}' "$SITE" | tr -d ';' | paste -sd ' ' -)"
        echo "$NAME"
        echo "  server_name: ${SERVER_NAMES:-unknown}"
        echo "  proxy_pass:  ${TARGET:-unknown}"
    done
fi

echo

# --------------------------------------------------
# Choose the host port for this application
# --------------------------------------------------

suggest_port() {
    local port=8001

    while ss -ltn | awk '{print $4}' | grep -Eq "[:.]${port}$"; do
        port=$((port + 1))
    done

    echo "$port"
}

detect_compose_ports() {
    local dir="$1"
    local env_args=()
    local compose_json
    local compose_cmd

    if [[ ! -d "$dir" ]]; then
        return 0
    fi

    if docker compose version >/dev/null 2>&1; then
        compose_cmd="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        return 0
    fi

    if [[ -f "$dir/.env.prod" ]]; then
        env_args=(--env-file .env.prod)
    fi

    compose_json="$(mktemp)"

    if ! (cd "$dir" && $compose_cmd "${env_args[@]}" config --format json > "$compose_json"); then
        rm -f "$compose_json"
        return 0
    fi

    jq -r '
        .services
        | to_entries[]
        | .key as $service
        | (.value.ports // [])[]
        | select((.published // "") != "" and (.published | tostring) != "null")
        | select((.target | tostring) as $target | ($target != "5432" and $target != "6379" and $target != "3306" and $target != "27017" and $target != "11211" and $target != "9200" and $target != "5672"))
        | [
            $service,
            (.published | tostring),
            (.target | tostring),
            (.host_ip // "")
          ]
        | @tsv
    ' "$compose_json"

    rm -f "$compose_json"
}

if [[ -z "${APP_PORT:-}" ]]; then

    echo "Looking for a published web port in:"
    echo "$APP_DIR"
    echo

    CANDIDATES=()

    if [[ -d "${APP_DIR:-}" ]]; then
        while IFS=$'\t' read -r SERVICE PUBLISHED TARGET HOST_IP; do
            [[ -z "${PUBLISHED:-}" ]] && continue
            CANDIDATES+=("${SERVICE}"$'\t'"${PUBLISHED}"$'\t'"${TARGET}"$'\t'"${HOST_IP}")
            echo "Found ${SERVICE}: host ${PUBLISHED} -> container ${TARGET}"
        done < <(detect_compose_ports "$APP_DIR" || true)
    else
        echo "Application directory does not exist yet."
    fi

    if ((${#CANDIDATES[@]} == 1)); then
        IFS=$'\t' read -r SERVICE APP_PORT TARGET HOST_IP <<< "${CANDIDATES[0]}"
        echo
        echo "Using host port ${APP_PORT} from ${SERVICE}."
    elif ((${#CANDIDATES[@]} > 1)); then
        echo
        echo "Select the port Nginx should route to:"
        echo

        for i in "${!CANDIDATES[@]}"; do
            IFS=$'\t' read -r SERVICE PUBLISHED TARGET HOST_IP <<< "${CANDIDATES[$i]}"
            echo "  $((i + 1))) ${SERVICE}  127.0.0.1:${PUBLISHED} -> ${TARGET}"
        done

        echo
        read -rp "Choice [1]: " CHOICE
        CHOICE=${CHOICE:-1}

        if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || ((CHOICE < 1 || CHOICE > ${#CANDIDATES[@]})); then
            echo "❌ Invalid port selection."
            exit 1
        fi

        IFS=$'\t' read -r SERVICE APP_PORT TARGET HOST_IP <<< "${CANDIDATES[$((CHOICE - 1))]}"
    else
        SUGGESTED="$(suggest_port)"
        echo
        echo "No published web port was found."
        echo "Suggested free host port: $SUGGESTED"
        echo
        read -rp "Application host port [$SUGGESTED]: " APP_PORT
        APP_PORT=${APP_PORT:-$SUGGESTED}
    fi
fi

if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || ((APP_PORT < 1 || APP_PORT > 65535)); then
    echo "❌ Application port must be a number from 1 to 65535."
    exit 1
fi

if ! [[ "$APP_DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
    echo "❌ Domain must be a hostname such as app.example.com."
    exit 1
fi

echo
echo "Checking application port..."

if ! ss -ltn | awk '{print $4}' | grep -Eq "[:.]${APP_PORT}$"; then

    echo
    echo "⚠ Warning:"
    echo "Nothing appears to be listening on port $APP_PORT."
    echo
    echo "Expected something like:"
    echo
    echo "127.0.0.1:$APP_PORT"
    echo
fi

# --------------------------------------------------
# Nginx config paths
# --------------------------------------------------

AVAILABLE="/etc/nginx/sites-available/$APP_DOMAIN"
ENABLED="/etc/nginx/sites-enabled/$APP_DOMAIN"

# --------------------------------------------------
# Backup existing config
# --------------------------------------------------

if [[ -f "$AVAILABLE" ]]; then

    BACKUP="${AVAILABLE}.backup.$(date +%Y%m%d%H%M%S)"

    cp "$AVAILABLE" "$BACKUP"

    echo "✓ Existing Nginx config backed up:"
    echo "$BACKUP"
fi

# --------------------------------------------------
# Write site configuration
# --------------------------------------------------

cat > "$AVAILABLE" <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $APP_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

echo "✓ Nginx configuration created."

# --------------------------------------------------
# Enable site
# --------------------------------------------------

if [[ ! -L "$ENABLED" ]]; then

    ln -s "$AVAILABLE" "$ENABLED"

    echo "✓ Site enabled."

else
    echo "✓ Site already enabled."
fi

# --------------------------------------------------
# Test nginx
# --------------------------------------------------

echo
echo "Testing Nginx configuration..."

if ! nginx -t; then

    echo
    echo "❌ Nginx configuration test failed."
    echo
    echo "Nginx was NOT reloaded."
    exit 1
fi

echo
echo "✓ Nginx configuration valid."

# --------------------------------------------------
# Reload nginx
# --------------------------------------------------

systemctl reload nginx

echo "✓ Nginx reloaded."

# --------------------------------------------------
# Summary
# --------------------------------------------------

echo
echo "========================================"
echo "       NGINX SETUP COMPLETE"
echo "========================================"
echo
echo "Domain:"
echo "  http://$APP_DOMAIN"
echo
echo "Proxy target:"
echo "  http://127.0.0.1:$APP_PORT"
echo
echo "Nginx config:"
echo "  $AVAILABLE"
echo
echo "Another application on this server:"
echo "  sudo ./bootstrap.sh app"
echo