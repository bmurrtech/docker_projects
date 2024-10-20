#!/bin/sh

# Load environment variables from .env
export $(grep -v '^#' .env | xargs)

LOGFILE="$TRAEFIK_CONFIG_PATH/setup.log"
MARKER_FILE="$TRAEFIK_CONFIG_PATH/.setup_done"

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

# Create traefik.yml if it doesn't exist
if [ ! -f "$TRAEFIK_CONFIG_PATH/traefik.yml" ]; then
  if [ -f "$TRAEFIK_CONFIG_PATH/traefik.example.yml" ]; then
    cp "$TRAEFIK_CONFIG_PATH/traefik.example.yml" "$TRAEFIK_CONFIG_PATH/traefik.yml"
    log "Created traefik.yml from traefik.example.yml."
  else
    touch "$TRAEFIK_CONFIG_PATH/traefik.yml"
    log "Created an empty traefik.yml file."
  fi
else
  log "traefik.yml already exists. Skipping creation."
fi

# Create marker file to indicate setup completion
touch "$MARKER_FILE"
log "Setup completed successfully."
