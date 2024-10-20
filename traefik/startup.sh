#!/bin/sh

LOGFILE="./setup.log"

# Log function to print to both the console and log file
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a $LOGFILE
}

# Create necessary directories
mkdir -p ./config/conf ./config/certs

# Check if .env exists; if not, copy .env.example
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
    log "Created .env from .env.example. Please customize it."
  else
    log "Error: .env.example not found!"
    exit 1
  fi
else
  log ".env already exists. Skipping creation."
fi

# Ensure acme.json exists with proper permissions
if [ ! -f ./config/certs/acme.json ]; then
  touch ./config/certs/acme.json
  chmod 600 ./config/certs/acme.json
  log "Created acme.json and set appropriate permissions."
else
  log "acme.json already exists. Skipping creation."
fi

log "Setup completed successfully. You can now start the stack using:"
log "  docker-compose up -d"
