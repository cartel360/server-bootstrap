#!/usr/bin/env bash

set -Eeuo pipefail

echo "[5/6] Configuring GitHub access..."

DEPLOY_HOME="/home/$DEPLOY_USER"
SSH_DIR="$DEPLOY_HOME/.ssh"

GITHUB_KEY="$SSH_DIR/github_repo"
CI_KEY="$SSH_DIR/github_actions_deploy"

# --------------------------------------------------
# Ensure SSH directory exists
# --------------------------------------------------

mkdir -p "$SSH_DIR"

touch "$SSH_DIR/authorized_keys"
touch "$SSH_DIR/known_hosts"

chmod 700 "$SSH_DIR"
chmod 600 "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/known_hosts"

chown -R "$DEPLOY_USER":"$DEPLOY_USER" "$SSH_DIR"

# --------------------------------------------------
# Server -> GitHub key
# --------------------------------------------------

if [[ ! -f "$GITHUB_KEY" ]]; then

    echo "Generating GitHub repository access key..."

    sudo -u "$DEPLOY_USER" ssh-keygen \
        -t ed25519 \
        -C "$APP_NAME-server" \
        -f "$GITHUB_KEY" \
        -N ""

else
    echo "✓ GitHub repository key already exists."
fi

# --------------------------------------------------
# GitHub known_hosts
# --------------------------------------------------

if ! ssh-keygen -F github.com -f "$SSH_DIR/known_hosts" >/dev/null 2>&1; then

    echo "Adding GitHub to known_hosts..."

    ssh-keyscan github.com >> "$SSH_DIR/known_hosts" 2>/dev/null

else
    echo "✓ GitHub already exists in known_hosts."
fi

chmod 600 "$SSH_DIR/known_hosts"

# --------------------------------------------------
# SSH config
# --------------------------------------------------

cat > "$SSH_DIR/config" <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_repo
    IdentitiesOnly yes
EOF

chmod 600 "$SSH_DIR/config"

chown -R "$DEPLOY_USER":"$DEPLOY_USER" "$SSH_DIR"

# --------------------------------------------------
# GitHub Actions -> Server key
# --------------------------------------------------

if [[ ! -f "$CI_KEY" ]]; then

    echo "Generating GitHub Actions deployment key..."

    sudo -u "$DEPLOY_USER" ssh-keygen \
        -t ed25519 \
        -C "$APP_NAME-github-actions" \
        -f "$CI_KEY" \
        -N ""

else
    echo "✓ GitHub Actions deployment key already exists."
fi

# --------------------------------------------------
# Authorize GitHub Actions public key
# --------------------------------------------------

CI_PUBLIC_KEY="$(cat "$CI_KEY.pub")"

if ! grep -qxF "$CI_PUBLIC_KEY" "$SSH_DIR/authorized_keys"; then

    echo "$CI_PUBLIC_KEY" >> "$SSH_DIR/authorized_keys"

    echo "✓ GitHub Actions key added to authorized_keys."

else
    echo "✓ GitHub Actions key already authorized."
fi

chmod 600 "$SSH_DIR/authorized_keys"

chown -R "$DEPLOY_USER":"$DEPLOY_USER" "$SSH_DIR"

# --------------------------------------------------
# Output
# --------------------------------------------------

echo
echo "========================================"
echo " SERVER -> GITHUB DEPLOY KEY"
echo "========================================"
echo
cat "$GITHUB_KEY.pub"
echo
echo "Add this PUBLIC key to:"
echo
echo "GitHub repository"
echo " -> Settings"
echo " -> Deploy keys"
echo " -> Add deploy key"
echo
echo "Do NOT enable write access."
echo

echo "========================================"
echo " GITHUB ACTIONS -> SERVER KEY"
echo "========================================"
echo
echo "The GitHub Actions private deployment key is stored at:"
echo
echo "$CI_KEY"
echo
echo "You will add this private key to GitHub Actions Secrets as:"
echo
echo "DEPLOY_SSH_KEY"
echo