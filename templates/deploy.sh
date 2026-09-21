#!/usr/bin/env bash

set -euo pipefail

APP_DIR="${1:-}"

if [[ -z "$APP_DIR" ]]; then
    echo "Usage:"
    echo "./deploy.sh /var/www/my-app"
    exit 1
fi

cd "$APP_DIR"

echo "Pulling latest code..."

git fetch origin
git pull origin main

echo "Building containers..."

docker compose \
    --env-file .env.prod \
    up -d \
    --build

echo "Removing unused images..."

docker image prune -f

echo "Deployment complete."