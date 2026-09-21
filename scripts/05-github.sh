#!/usr/bin/env bash

set -euo pipefail

echo "[5/6] Configuring GitHub access..."

DEPLOY_HOME="/home/$DEPLOY_USER"
SSH_DIR="$DEPLOY_HOME/.ssh"
GITHUB_KEY="$SSH_DIR/github_repo"

if [[ ! -f "$GITHUB_KEY" ]]; then

    sudo -u "$DEPLOY_USER" ssh-keygen \
        -t ed25519 \
        -C "$APP_NAME-server" \
        -f "$GITHUB_KEY" \
        -N ""

fi

ssh-keyscan github.com >> "$SSH_DIR/known_hosts" 2>/dev/null

sort -u "$SSH_DIR/known_hosts" -o "$SSH_DIR/known_hosts"

cat > "$SSH_DIR/config" <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_repo
    IdentitiesOnly yes
EOF

chmod 600 "$SSH_DIR/config"
chmod 600 "$SSH_DIR/known_hosts"

chown -R "$DEPLOY_USER":"$DEPLOY_USER" "$SSH_DIR"

echo
echo "========================================"
echo " GITHUB DEPLOY KEY"
echo "========================================"
echo
cat "$GITHUB_KEY.pub"
echo
echo "Add the key above to:"
echo
echo "GitHub repository"
echo " -> Settings"
echo " -> Deploy keys"
echo " -> Add deploy key"
echo
echo "Do NOT enable write access."
echo