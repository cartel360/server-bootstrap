#!/usr/bin/env bash

set -euo pipefail

echo "[1/6] Updating system..."

apt-get update
apt-get upgrade -y

apt-get install -y \
    curl \
    git \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw

echo "System packages installed."