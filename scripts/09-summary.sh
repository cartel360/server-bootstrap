#!/usr/bin/env bash

set -euo pipefail

DEPLOY_HOME="/home/$DEPLOY_USER"
GITHUB_KEY="$DEPLOY_HOME/.ssh/github_repo"
CI_KEY="$DEPLOY_HOME/.ssh/github_actions_deploy"

SERVER_IP=$(hostname -I | awk '{print $1}')

echo
echo "============================================================"
echo "                 SERVER BOOTSTRAP COMPLETE"
echo "============================================================"
echo

echo "APPLICATION"
echo "------------------------------------------------------------"
echo "Application name : $APP_NAME"
echo "Application path : $APP_DIR"
echo "Repository       : $GITHUB_REPO"
echo

echo "SERVER"
echo "------------------------------------------------------------"
echo "Server IP        : $SERVER_IP"
echo "Deploy user      : $DEPLOY_USER"
echo

echo "============================================================"
echo "1. SERVER -> GITHUB ACCESS"
echo "============================================================"
echo
echo "Add the following PUBLIC key to:"
echo
echo "GitHub Repository"
echo "  -> Settings"
echo "  -> Deploy keys"
echo "  -> Add deploy key"
echo
echo "Do NOT enable write access."
echo
echo "Public key:"
echo "------------------------------------------------------------"

if [[ -f "$GITHUB_KEY.pub" ]]; then
    cat "$GITHUB_KEY.pub"
else
    echo "WARNING: GitHub repository key not found."
fi

echo
echo "------------------------------------------------------------"
echo

echo "============================================================"
echo "2. GITHUB ACTIONS -> SERVER ACCESS"
echo "============================================================"
echo
echo "Add these values to:"
echo
echo "GitHub Repository"
echo "  -> Settings"
echo "  -> Secrets and variables"
echo "  -> Actions"
echo

echo "DEPLOY_HOST"
echo "------------------------------------------------------------"
echo "$SERVER_IP"
echo

echo "DEPLOY_USER"
echo "------------------------------------------------------------"
echo "$DEPLOY_USER"
echo

echo "DEPLOY_PATH"
echo "------------------------------------------------------------"
echo "$APP_DIR"
echo

echo "DEPLOY_SSH_KEY"
echo "------------------------------------------------------------"

if [[ -f "$CI_KEY" ]]; then
    cat "$CI_KEY"
else
    echo "WARNING: GitHub Actions deployment key not found."
fi

echo
echo "============================================================"
echo "3. IMPORTANT"
echo "============================================================"
echo
echo "After copying DEPLOY_SSH_KEY into GitHub Actions Secrets,"
echo "consider removing the CI/CD private key from the server:"
echo
echo "rm $CI_KEY"
echo
echo "The public key should remain authorized at:"
echo
echo "$DEPLOY_HOME/.ssh/authorized_keys"
echo

echo "============================================================"
echo "                    SETUP COMPLETE"
echo "============================================================"