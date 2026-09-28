#!/usr/bin/env bash

set -Eeuo pipefail

echo "Checking application conflicts..."

# --------------------------------------------------
# App directory
# --------------------------------------------------

if [[ -d "$APP_DIR" ]]; then

    if [[ -n "$(ls -A "$APP_DIR" 2>/dev/null)" ]]; then
        echo
        echo "⚠ Application directory already exists and is not empty:"
        echo
        echo "$APP_DIR"
        echo

        read -rp "Continue using this directory? [y/N]: " CONTINUE_DIR
        CONTINUE_DIR=${CONTINUE_DIR:-N}

        if [[ ! "$CONTINUE_DIR" =~ ^[Yy]$ ]]; then
            echo "Bootstrap cancelled."
            exit 1
        fi
    else
        echo "✓ Application directory already exists and is empty."
    fi

else
    echo "✓ Application directory is available."
fi

# --------------------------------------------------
# Show currently running Docker ports
# --------------------------------------------------

echo
echo "Currently published Docker ports:"
echo "------------------------------------------------------------"

docker ps \
    --format 'table {{.Names}}\t{{.Ports}}' \
    || true

echo

# --------------------------------------------------
# Show server listening ports
# --------------------------------------------------

echo "Currently listening TCP ports:"
echo "------------------------------------------------------------"

ss -ltn \
    | awk 'NR==1 || /LISTEN/' \
    || true

echo

# --------------------------------------------------
# Common port guidance
# --------------------------------------------------

echo "Port guidance"
echo "------------------------------------------------------------"
echo
echo "Multiple apps may safely use the same INTERNAL ports:"
echo
echo "  PostgreSQL : 5432"
echo "  Redis      : 6379"
echo "  Web app    : 8000"
echo
echo "Conflicts only occur when the same HOST port is published."
echo
echo "Examples:"
echo
echo "  App 1: 127.0.0.1:8001:8000"
echo "  App 2: 127.0.0.1:8002:8000"
echo "  App 3: 127.0.0.1:8003:8000"
echo
echo "PostgreSQL and Redis normally do not need host ports."
echo

# --------------------------------------------------
# Suggest next available web port
# --------------------------------------------------

find_available_port() {

    local port=8000

    while ss -ltn | awk '{print $4}' | grep -Eq "[:.]${port}$"; do
        port=$((port + 1))
    done

    echo "$port"
}

AVAILABLE_PORT=$(find_available_port)

echo "Suggested available web port:"
echo
echo "  $AVAILABLE_PORT"
echo
echo "Recommended Docker Compose mapping:"
echo
echo "  ports:"
echo "    - \"127.0.0.1:${AVAILABLE_PORT}:8000\""
echo

export SUGGESTED_APP_PORT="$AVAILABLE_PORT"

echo "✓ Preflight checks completed."