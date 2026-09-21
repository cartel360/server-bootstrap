#!/usr/bin/env bash

set -euo pipefail

echo "[4/6] Configuring firewall..."

ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp

ufw --force enable

echo
ufw status

echo "Firewall configured."