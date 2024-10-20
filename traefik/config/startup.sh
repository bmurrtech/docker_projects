#!/bin/sh

# Create necessary directories if they don't exist
mkdir -p ./config/conf ./config/certs

# Check if .env exists; if not, copy .env.example
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
    echo "Created .env from .env.example. Please customize it with your settings."
  else
    echo "Error: .env.example not found! Please provide a .env file."
    exit 1
  fi
fi

# Check if traefik.yml exists; if not, copy traefik.example.yml
if [ ! -f ./config/traefik.yml ]; then
  if [ -f ./config/traefik.example.yml ]; then
    cp ./config/traefik.example.yml ./config/traefik.yml
    echo "Created traefik.yml from traefik.example.yml. Please customize it."
  else
    echo "Error: traefik.example.yml not found! Please provide a config template."
    exit 1
  fi
fi

# Ensure acme.json exists and set proper permissions
if [ ! -f ./config/certs/acme.json ]; then
  touch ./config/certs/acme.json
  chmod 600 ./config/certs/acme.json
  echo "Created acme.json and set appropriate permissions."
fi

# Inform the user to review and customize the files before starting the stack
echo "======================================================="
echo "Configuration setup is complete. Please review and customize:"
echo "  - .env"
echo "  - config/traefik.yml"
echo ""
echo "Once done, you can start the stack using:"
echo "  docker-compose up -d"
echo "Or launch it via your preferred method, such as Portainer."
echo "======================================================="
