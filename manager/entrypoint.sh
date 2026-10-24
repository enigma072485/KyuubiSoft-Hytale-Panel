#!/bin/sh
# ============================================================
# Manager Container Entrypoint
# Switches to manager user (UID 9999, same as hytale container)
# ============================================================

set -e

# UID/GID 9999 = same as hytale container for shared volume access
MANAGER_UID=9999
SHARED_GID=9999

echo "[Manager] Starting as UID $(id -u)..."

# Check if we're running as root (needed for user switching)
if [ "$(id -u)" = "0" ]; then
    # Set umask to ensure new files are group-writable
    umask 002

    # Add docker socket group to manager user for container management
    if [ -S /var/run/docker.sock ]; then
        DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
        echo "[Manager] Docker socket GID: $DOCKER_GID"

        # Create docker group with the socket's GID if it doesn't exist
        if ! getent group "$DOCKER_GID" >/dev/null 2>&1; then
            groupadd -g "$DOCKER_GID" docker 2>/dev/null || true
        fi

        # Add manager user to whatever group owns docker.sock
        DOCKER_GROUP=$(getent group "$DOCKER_GID" | cut -d: -f1)

        if [ -n "$DOCKER_GROUP" ]; then
            usermod -aG "$DOCKER_GROUP" manager
            echo "[Manager] Added manager to group $DOCKER_GROUP (GID: $DOCKER_GID)"
        else
            echo "[Manager] ERROR: Could not determine group for Docker GID $DOCKER_GID"
            exit 1
        fi
    fi
    echo "[Manager] Switching to manager user (UID: $MANAGER_UID)..."
    # gosu properly handles supplementary groups
    exec gosu manager "$@"
else
    # Already running as non-root, set umask and run
    umask 002
    exec "$@"
fi
