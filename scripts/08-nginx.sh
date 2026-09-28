#!/usr/bin/env bash

set -Eeuo pipefail

echo
echo "Configuring Nginx for:"
echo
echo "Application : $APP_NAME"
echo "Domain      : $APP_DOMAIN"
echo "Port        : $APP_PORT"
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
# Check application port
# --------------------------------------------------

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