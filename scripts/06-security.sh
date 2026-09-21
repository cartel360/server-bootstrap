#!/usr/bin/env bash

set -euo pipefail

echo "[6/6] Basic security configuration..."

apt-get install -y fail2ban

systemctl enable fail2ban
systemctl start fail2ban

echo "Fail2ban enabled."