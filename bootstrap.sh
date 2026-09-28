#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="${1:-full}"

# --------------------------------------------------
# Error handling
# --------------------------------------------------

trap 'echo; echo "❌ Bootstrap failed on line $LINENO"; echo "Fix the problem and run the script again."; echo' ERR

# --------------------------------------------------
# Root check
# --------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "❌ Please run with sudo:"
    echo
    echo "sudo ./bootstrap.sh"
    exit 1
fi

if [[ "$MODE" == "nginx" ]]; then

    echo
    echo "========================================"
    echo "       NGINX APP SETUP"
    echo "========================================"
    echo

    read -rp "Application name: " APP_NAME

    if [[ -z "$APP_NAME" ]]; then
        echo "❌ Application name is required."
        exit 1
    fi

    read -rp "Domain/subdomain: " APP_DOMAIN

    if [[ -z "$APP_DOMAIN" ]]; then
        echo "❌ Domain is required."
        exit 1
    fi

    read -rp "Application host port: " APP_PORT

    if [[ -z "$APP_PORT" ]]; then
        echo "❌ Application port is required."
        exit 1
    fi

    export APP_NAME
    export APP_DOMAIN
    export APP_PORT

    bash "$SCRIPT_DIR/scripts/08-nginx.sh"

    exit 0
fi

# --------------------------------------------------
# Configuration
# --------------------------------------------------

echo
echo "========================================"
echo "       SERVER BOOTSTRAP"
echo "========================================"
echo

read -rp "Deployment user [deploy]: " DEPLOY_USER
DEPLOY_USER=${DEPLOY_USER:-deploy}

read -rp "Application name: " APP_NAME

if [[ -z "$APP_NAME" ]]; then
    echo "❌ Application name is required."
    exit 1
fi

read -rp "Application directory [/var/www/$APP_NAME]: " APP_DIR
APP_DIR=${APP_DIR:-/var/www/$APP_NAME}

read -rp "GitHub repository SSH URL: " GITHUB_REPO

if [[ -z "$GITHUB_REPO" ]]; then
    echo "❌ GitHub repository is required."
    exit 1
fi

export DEPLOY_USER
export APP_NAME
export APP_DIR
export GITHUB_REPO

echo
echo "Configuration"
echo "----------------------------------------"
echo "Deployment user : $DEPLOY_USER"
echo "Application     : $APP_NAME"
echo "Directory       : $APP_DIR"
echo "Repository      : $GITHUB_REPO"
echo

read -rp "Continue? [Y/n]: " CONTINUE
CONTINUE=${CONTINUE:-Y}

if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    echo "Bootstrap cancelled."
    exit 0
fi

# --------------------------------------------------
# Helper
# --------------------------------------------------

run_step() {

    local number="$1"
    local name="$2"
    local script="$3"

    echo
    echo "========================================"
    echo "[$number] $name"
    echo "========================================"
    echo

    bash "$SCRIPT_DIR/$script"

    echo
    echo "✓ $name completed"
}

# --------------------------------------------------
# Bootstrap
# --------------------------------------------------

run_step "1/9" \
    "System setup" \
    "scripts/01-system.sh"

run_step "2/9" \
    "Docker installation" \
    "scripts/02-docker.sh"

run_step "3/9" \
    "Deployment user" \
    "scripts/03-deploy-user.sh"

run_step "4/9" \
    "Application preflight checks" \
    "scripts/04-app-preflight.sh"

run_step "5/9" \
    "Firewall configuration" \
    "scripts/05-firewall.sh"

run_step "6/9" \
    "GitHub configuration" \
    "scripts/06-github.sh"

run_step "7/9" \
    "Security configuration" \
    "scripts/07-security.sh"

run_step "8/9" \
    "Nginx Setup" \
    "scripts/00-nginx.sh"

run_step "9/9" \
    "Setup summary" \
    "scripts/09-summary.sh"

echo
echo "========================================"
echo "       ✅ BOOTSTRAP COMPLETE"
echo "========================================"
echo
echo "Application : $APP_NAME"
echo "Directory   : $APP_DIR"
echo "Deploy user : $DEPLOY_USER"
echo