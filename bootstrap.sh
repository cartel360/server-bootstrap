#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "       SERVER BOOTSTRAP"
echo "========================================"
echo

if [[ $EUID -ne 0 ]]; then
    echo "Please run with sudo:"
    echo "sudo ./bootstrap.sh"
    exit 1
fi

read -rp "Deployment user [deploy]: " DEPLOY_USER
DEPLOY_USER=${DEPLOY_USER:-deploy}

read -rp "Application name: " APP_NAME

read -rp "Application directory [/var/www/$APP_NAME]: " APP_DIR
APP_DIR=${APP_DIR:-/var/www/$APP_NAME}

read -rp "GitHub repository SSH URL: " GITHUB_REPO

export DEPLOY_USER
export APP_NAME
export APP_DIR
export GITHUB_REPO

echo
echo "Configuration"
echo "----------------------------------------"
echo "User:       $DEPLOY_USER"
echo "Application: $APP_NAME"
echo "Directory:  $APP_DIR"
echo "Repository: $GITHUB_REPO"
echo

read -rp "Continue? [Y/n]: " CONTINUE
CONTINUE=${CONTINUE:-Y}

if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    exit 0
fi

bash "$SCRIPT_DIR/scripts/01-system.sh"
bash "$SCRIPT_DIR/scripts/02-docker.sh"
bash "$SCRIPT_DIR/scripts/03-deploy-user.sh"
bash "$SCRIPT_DIR/scripts/04-firewall.sh"
bash "$SCRIPT_DIR/scripts/05-github.sh"
bash "$SCRIPT_DIR/scripts/06-security.sh"

echo
echo "========================================"
echo "       BOOTSTRAP COMPLETE"
echo "========================================"
echo
echo "Application: $APP_NAME"
echo "Directory:   $APP_DIR"
echo "Deploy user: $DEPLOY_USER"
echo
echo "Follow the instructions above to add"
echo "the generated SSH keys to GitHub."