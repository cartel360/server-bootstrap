# #!/usr/bin/env bash

# set -euo pipefail

# APP_DIR="${1:-}"

# if [[ -z "$APP_DIR" ]]; then
#     echo "Usage:"
#     echo "./deploy.sh /var/www/my-app"
#     exit 1
# fi

# cd "$APP_DIR"

# echo "Pulling latest code..."

# git fetch origin
# git pull origin main

# echo "Building containers..."

# docker compose \
#     --env-file .env.prod \
#     up -d \
#     --build

# echo "Removing unused images..."

# docker image prune -f

# echo "Deployment complete."




#!/usr/bin/env bash

set -Eeuo pipefail

APP_DIR="${1:-}"

if [[ -z "$APP_DIR" ]]; then
    echo "Usage:"
    echo "  ./deploy.sh /var/www/my-app"
    exit 1
fi

if [[ ! -d "$APP_DIR" ]]; then
    echo "ERROR: Application directory does not exist:"
    echo "$APP_DIR"
    exit 1
fi

cd "$APP_DIR"

echo
echo "============================================================"
echo " DEPLOYMENT"
echo "============================================================"
echo
echo "Application directory: $APP_DIR"
echo

# ------------------------------------------------------------
# Determine Compose command
# ------------------------------------------------------------

if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE="docker-compose"
else
    echo "ERROR: Docker Compose is not installed."
    exit 1
fi

# ------------------------------------------------------------
# Determine environment file
# ------------------------------------------------------------

ENV_ARGS=()

if [[ -f ".env.prod" ]]; then
    ENV_ARGS=(--env-file .env.prod)
    echo "Using environment file: .env.prod"
elif [[ -f ".env" ]]; then
    echo "Using environment file: .env"
else
    echo "No .env.prod or .env file found."
fi

# ------------------------------------------------------------
# Validate Compose configuration
# ------------------------------------------------------------

echo
echo "[1/6] Validating Docker Compose configuration..."

if ! $COMPOSE "${ENV_ARGS[@]}" config >/dev/null; then
    echo
    echo "ERROR: Docker Compose configuration is invalid."
    exit 1
fi

echo "✓ Docker Compose configuration is valid."

# ------------------------------------------------------------
# Generate resolved Compose JSON
# ------------------------------------------------------------

COMPOSE_JSON=$(mktemp)

cleanup() {
    rm -f "$COMPOSE_JSON"
}

trap cleanup EXIT

if ! $COMPOSE "${ENV_ARGS[@]}" config --format json > "$COMPOSE_JSON"; then
    echo
    echo "ERROR: Unable to inspect Docker Compose configuration."
    exit 1
fi

# ------------------------------------------------------------
# Port conflict check
# ------------------------------------------------------------

echo
echo "[2/6] Checking host port conflicts..."

PORT_CONFLICTS=0

while IFS='|' read -r SERVICE TARGET PUBLISHED HOST_IP PROTOCOL; do

    [[ -z "$PUBLISHED" ]] && continue
    [[ "$PUBLISHED" == "null" ]] && continue

    # Default protocol
    PROTOCOL=${PROTOCOL:-tcp}

    echo "Checking $SERVICE: host $PUBLISHED -> container $TARGET/$PROTOCOL"

    EXISTING=$(docker ps \
        --format '{{.Names}}|{{.Ports}}' \
        | grep -E "(^|[^0-9])${PUBLISHED}->|:${PUBLISHED}->" \
        || true)

    if [[ -n "$EXISTING" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "PORT CONFLICT"
        echo "------------------------------------------------------------"
        echo
        echo "Host port:      $PUBLISHED"
        echo "Requested by:   $SERVICE"
        echo "Container port: $TARGET"
        echo
        echo "Currently in use by:"
        echo "$EXISTING"
        echo

        case "$TARGET" in

            5432)
                echo "This appears to be PostgreSQL."
                echo
                echo "If PostgreSQL is only used by containers in this"
                echo "application, you usually do NOT need:"
                echo
                echo "  ports:"
                echo "    - \"$PUBLISHED:5432\""
                echo
                echo "Remove the ports section and connect internally using:"
                echo
                echo "  postgres:5432"
                echo
                ;;

            6379)
                echo "This appears to be Redis."
                echo
                echo "If Redis is only used internally, remove:"
                echo
                echo "  ports:"
                echo "    - \"$PUBLISHED:6379\""
                echo
                echo "Connect internally using:"
                echo
                echo "  redis:6379"
                echo
                ;;

            *)
                NEXT_PORT=$((PUBLISHED + 1))

                echo "Change the host-side port."
                echo
                echo "For example:"
                echo
                echo "  ports:"
                echo "    - \"127.0.0.1:${NEXT_PORT}:${TARGET}\""
                echo
                echo "The container can continue listening on:"
                echo
                echo "  $TARGET"
                echo
                ;;
        esac

        PORT_CONFLICTS=$((PORT_CONFLICTS + 1))
    fi

done < <(
    jq -r '
        .services
        | to_entries[]
        | .key as $service
        | (.value.ports // [])[]
        | [
            $service,
            (.target // ""),
            (.published // ""),
            (.host_ip // ""),
            (.protocol // "tcp")
          ]
        | @tsv
    ' "$COMPOSE_JSON" | tr '\t' '|'
)

# ------------------------------------------------------------
# container_name conflicts
# ------------------------------------------------------------

echo
echo "[3/6] Checking container name conflicts..."

CONTAINER_CONFLICTS=0

while IFS='|' read -r SERVICE CONTAINER_NAME; do

    [[ -z "$CONTAINER_NAME" ]] && continue
    [[ "$CONTAINER_NAME" == "null" ]] && continue

    EXISTING=$(docker ps -a \
        --filter "name=^/${CONTAINER_NAME}$" \
        --format '{{.Names}}' \
        || true)

    if [[ -n "$EXISTING" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "CONTAINER NAME CONFLICT"
        echo "------------------------------------------------------------"
        echo
        echo "Service:"
        echo "  $SERVICE"
        echo
        echo "Requested container_name:"
        echo "  $CONTAINER_NAME"
        echo
        echo "Existing container:"
        echo "  $EXISTING"
        echo
        echo "Recommended fix:"
        echo
        echo "Remove this from docker-compose.yml:"
        echo
        echo "  container_name: $CONTAINER_NAME"
        echo
        echo "Docker Compose will automatically generate a unique name."
        echo

        CONTAINER_CONFLICTS=$((CONTAINER_CONFLICTS + 1))
    fi

done < <(
    jq -r '
        .services
        | to_entries[]
        | select(.value.container_name != null)
        | [
            .key,
            .value.container_name
          ]
        | @tsv
    ' "$COMPOSE_JSON" | tr '\t' '|'
)

# ------------------------------------------------------------
# Fail if conflicts found
# ------------------------------------------------------------

if (( PORT_CONFLICTS > 0 || CONTAINER_CONFLICTS > 0 )); then

    echo
    echo "============================================================"
    echo " DEPLOYMENT PREFLIGHT FAILED"
    echo "============================================================"
    echo
    echo "Port conflicts:          $PORT_CONFLICTS"
    echo "Container name conflicts: $CONTAINER_CONFLICTS"
    echo
    echo "Fix the Docker Compose configuration and run deployment again."
    echo
    exit 1
fi

echo
echo "✓ No host port conflicts detected."
echo "✓ No container name conflicts detected."

# ------------------------------------------------------------
# Pull latest code
# ------------------------------------------------------------

echo
echo "[4/6] Pulling latest code..."

git fetch origin

CURRENT_BRANCH=$(git branch --show-current)

if [[ -z "$CURRENT_BRANCH" ]]; then
    CURRENT_BRANCH="main"
fi

git pull origin "$CURRENT_BRANCH"

echo "✓ Repository updated."

# ------------------------------------------------------------
# Deploy
# ------------------------------------------------------------

echo
echo "[5/6] Building and starting containers..."

$COMPOSE "${ENV_ARGS[@]}" up -d --build

echo
echo "✓ Containers started."

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

echo
echo "[6/6] Cleaning unused Docker images..."

docker image prune -f

echo
echo "============================================================"
echo " DEPLOYMENT COMPLETE"
echo "============================================================"
echo

$COMPOSE "${ENV_ARGS[@]}" ps