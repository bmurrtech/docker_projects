#!/bin/sh

# Load environment variables from .env
export $(grep -v '^#' .env | xargs)

LOGFILE="$TRAEFIK_CONFIG_PATH/setup.log"
MARKER_FILE="$TRAEFIK_CONFIG_PATH/.setup_done"
TRAEFIK_YML_URL="https://raw.githubusercontent.com/bmurrtech/docker_projects/refs/heads/main/traefik/config/traefik.yml"

log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a $LOGFILE
}

# Check if setup was already completed
if [ -f "$MARKER_FILE" ]; then
  log "Setup already completed. Skipping."
  exit 0
fi

# Ensure necessary directories exist
log "Ensuring required directories exist..."
mkdir -p "$TRAEFIK_CONFIG_PATH/conf" "$TRAEFIK_CONFIG_PATH/certs"

# Check if traefik.yml is a directory and remove it
if [ -d "$TRAEFIK_CONFIG_PATH/traefik.yml" ]; then
  log "Error: traefik.yml is a directory. Removing it."
  rm -rf "$TRAEFIK_CONFIG_PATH/traefik.yml"
fi

# Download traefik.yml if it doesn't exist
if [ ! -f "$TRAEFIK_CONFIG_PATH/traefik.yml" ]; then
  log "Downloading traefik.yml from $TRAEFIK_YML_URL"
  if command -v wget > /dev/null; then
    wget -O "$TRAEFIK_CONFIG_PATH/traefik.yml" "$TRAEFIK_YML_URL"
  elif command -v curl > /dev/null; then
    curl -o "$TRAEFIK_CONFIG_PATH/traefik.yml" "$TRAEFIK_YML_URL"
  else
    log "Error: Neither wget nor curl is available to download traefik.yml"
    exit 1
  fi
  log "Downloaded traefik.yml successfully."
else
  log "traefik.yml already exists. Skipping download."
fi

# Ensure acme.json exists with proper permissions
if [ ! -f "$TRAEFIK_CONFIG_PATH/certs/acme.json" ]; then
  touch "$TRAEFIK_CONFIG_PATH/certs/acme.json"
  chmod 600 "$TRAEFIK_CONFIG_PATH/certs/acme.json"
  log "Created acme.json with secure permissions."
else
  log "acme.json already exists. Skipping creation."
fi

# Create marker file to indicate setup completion
touch "$MARKER_FILE"
log "Setup completed successfully."
