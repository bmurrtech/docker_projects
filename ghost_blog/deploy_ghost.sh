#!/bin/bash

# Function to prompt for user input with verification
function prompt_input {
    local var_name="$1"
    local prompt_text="$2"
    local user_input
    while true; do
        read -p "$prompt_text: " user_input
        echo "You entered: $user_input. Is this correct? (y/n)"
        read -n 1 correct
        echo
        if [[ $correct == "y" || $correct == "Y" ]]; then
            eval "$var_name='$user_input'"
            break
        else
            echo "Please re-enter the $var_name."
        fi
    done
}

# Prompt user for variables
prompt_input EMAIL "Enter your email"
prompt_input DOMAIN "Enter your domain"
prompt_input CF_API_TOKEN "Enter your Cloudflare API token"
prompt_input MYSQL_ROOT_PASSWORD "Enter your MySQL root password (used for Ghost)"

# Confirm installation settings
echo "Summary of configuration:"
echo "Email: $EMAIL"
echo "Domain: $DOMAIN"
echo "Cloudflare API Token: (hidden for security)"
echo "MySQL Root Password: (hidden for security)"
echo "Is this configuration correct? (y/n)"
read -n 1 final_confirm
echo
if [[ $final_confirm != "y" && $final_confirm != "Y" ]]; then
    echo "Exiting setup. Please restart the script to configure again."
    exit 1
fi

# Update system packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install MySQL 8
echo "Installing MySQL 8..."
wget https://dev.mysql.com/get/mysql-apt-config_0.8.22-1_all.deb
sudo dpkg -i mysql-apt-config_0.8.22-1_all.deb
sudo apt update
sudo apt install -y mysql-server
rm mysql-apt-config_0.8.22-1_all.deb

# Configure MySQL root password
echo "Configuring MySQL root user for password authentication..."
sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY '$MYSQL_ROOT_PASSWORD';
FLUSH PRIVILEGES;
EXIT
EOF

# Install Node.js (Node 18) for Ghost
echo "Setting up Node.js 18..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt update
sudo apt install -y nodejs

# Install Ghost CLI
echo "Installing Ghost CLI..."
sudo npm install -g ghost-cli

# Create a new directory for Ghost
echo "Creating Ghost directory..."
sudo mkdir -p /var/www/ghost
sudo chown $USER:$USER /var/www/ghost

# Navigate to the Ghost directory
cd /var/www/ghost

# Install Ghost
echo "Installing Ghost..."
ghost install --no-prompt --db=mysql --url="https://$DOMAIN" --dbhost=localhost --dbuser=root --dbpass="$MYSQL_ROOT_PASSWORD" --dbname=ghost_prod --process=systemd --no-setup-nginx --no-setup-ssl

# Download and install Traefik
echo "Downloading and installing Traefik..."
wget https://github.com/traefik/traefik/releases/download/v2.10.1/traefik_v2.10.1_linux_amd64.tar.gz
tar -xvzf traefik_v2.10.1_linux_amd64.tar.gz
sudo mv traefik /usr/local/bin/
rm traefik_v2.10.1_linux_amd64.tar.gz

# Create Traefik configuration files
echo "Configuring Traefik..."
sudo mkdir -p /etc/traefik /etc/traefik/conf /etc/traefik/certs

# Traefik main config
sudo bash -c "cat << EOF > /etc/traefik/traefik.yml
global:
  checkNewVersion: true
  sendAnonymousUsage: false

log:
  level: ERROR
  format: common

accesslog:
  format: common

entryPoints:
  web:
    address: ':80'
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ':443'

certificatesResolvers:
  staging:
    acme:
      email: "$EMAIL"
      storage: "/etc/traefik/certs/cloudflare-acme-staging.json"
      caServer: "https://acme-staging-v02.api.letsencrypt.org/directory"
      dnsChallenge:
        provider: cloudflare
        delayBeforeCheck: 0
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"

providers:
  file:
    directory: "/etc/traefik/conf"
    watch: true
EOF"

# Dynamic configuration for Ghost
sudo bash -c "cat << EOF > /etc/traefik/conf/dynamic.yml
http:
  routers:
    ghost:
      rule: 'Host(\`$DOMAIN\`)'
      entryPoints:
        - websecure
      service: ghost
      tls:
        certResolver: staging

  services:
    ghost:
      loadBalancer:
        servers:
          - url: 'http://127.0.0.1:2368'
EOF"

# Set permissions for ACME storage
echo "Setting permissions for Traefik..."
sudo touch /etc/traefik/certs/cloudflare-acme-staging.json
sudo chmod 600 /etc/traefik/certs/cloudflare-acme-staging.json

# Configure Traefik with Cloudflare API token as an environment variable
echo "Creating systemd service for Traefik with secure API token..."
sudo bash -c "cat << EOF > /etc/systemd/system/traefik.service
[Unit]
Description=Traefik
After=network.target

[Service]
Type=simple
Environment=CF_DNS_API_TOKEN=$CF_API_TOKEN
ExecStart=/usr/local/bin/traefik --configFile=/etc/traefik/traefik.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF"

# Secure systemd service file permissions
sudo chmod 600 /etc/systemd/system/traefik.service

# Start and enable Traefik
echo "Starting Traefik..."
sudo systemctl daemon-reload
sudo systemctl start traefik
sudo systemctl enable traefik

# Create the production promotion script
echo "Creating production promotion script..."
sudo bash -c "cat << EOF > /usr/local/bin/promote_to_production.sh
#!/bin/bash

# Update Traefik to use production Let's Encrypt server and remove staging certs
echo 'Switching to production certificate resolver...'
sudo sed -i 's/certResolver: staging/certResolver: production/' /etc/traefik/conf/dynamic.yml

# Update main Traefik config to use production resolver
sudo sed -i 's/certificatesResolvers.staging/certificatesResolvers.production/' /etc/traefik/traefik.yml

# Add production resolver to Traefik main config
sudo bash -c \"cat << PROD >> /etc/traefik/traefik.yml

  production:
    acme:
      email: \"$EMAIL\"
      storage: \"/etc/traefik/certs/cloudflare-acme-production.json\"
      caServer: \"https://acme-v02.api.letsencrypt.org/directory\"
      dnsChallenge:
        provider: cloudflare
        delayBeforeCheck: 0
        resolvers:
          - \"1.1.1.1:53\"
          - \"8.8.8.8:53\"
PROD\"

# Remove staging certificates
echo 'Removing staging certificates...'
sudo rm -f /etc/traefik/certs/cloudflare-acme-staging.json

# Restart Traefik to apply changes
echo 'Restarting Traefik...'
sudo systemctl restart traefik

echo 'Production setup complete.'
EOF"

# Make the promotion script executable
sudo chmod +x /usr/local/bin/promote_to_production.sh

echo "Setup completed. Access your Ghost blog at https://$DOMAIN"
echo "After testing staging, run 'sudo /usr/local/bin/promote_to_production.sh' to switch to production."
