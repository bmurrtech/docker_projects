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

# Create .env if missing
if [ ! -f "$TRAEFIK_CONFIG_PATH/.env" ]; then
  if [ -f "$TRAEFIK_CONFIG_PATH/.env.example" ]; then
    cp "$TRAEFIK_CONFIG_PATH/.env.example" "$TRAEFIK_CONFIG_PATH/.env"
    log "Created .env from .env.example."
  else
    log "Error: .env.example not found!"
    exit 1
  fi
else
  log ".env already exists. Skipping creation."
fi

# Create traefik.yml if missing
if [ ! -f "$TRAEFIK_CONFIG_PATH/traefik.yml" ]; then
  if [ -f "$TRAEFIK_CONFIG_PATH/traefik.example.yml" ]; then
    cp "$TRAEFIK_CONFIG_PATH/traefik.example.yml" "$TRAEFIK_CONFIG_PATH/traefik.yml"
    log "Created traefik.yml from traefik.example.yml."
  else
    log "Error: traefik.example.yml not found!"
    exit 1
  fi
else
  log "traefik.yml already exists. Skipping creation."
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
