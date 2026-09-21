#!/usr/bin/env bash

set -euo pipefail

echo "[3/6] Configuring deployment user..."

if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
    useradd \
        --create-home \
        --shell /bin/bash \
        "$DEPLOY_USER"

    echo "Created user: $DEPLOY_USER"
else
    echo "User $DEPLOY_USER already exists."
fi

usermod -aG docker "$DEPLOY_USER"

mkdir -p /var/www
mkdir -p "$APP_DIR"

chown -R "$DEPLOY_USER":"$DEPLOY_USER" "$APP_DIR"

DEPLOY_HOME="/home/$DEPLOY_USER"

mkdir -p "$DEPLOY_HOME/.ssh"
touch "$DEPLOY_HOME/.ssh/authorized_keys"

chmod 700 "$DEPLOY_HOME/.ssh"
chmod 600 "$DEPLOY_HOME/.ssh/authorized_keys"

chown -R "$DEPLOY_USER":"$DEPLOY_USER" "$DEPLOY_HOME/.ssh"

echo "Deployment user configured."