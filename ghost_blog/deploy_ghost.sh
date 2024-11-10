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
prompt_input EMAIL "Enter your email for Let's Encrypt notifications"
prompt_input DOMAIN "Enter your domain for the Ghost site (e.g., https://yourdomain.com)"
prompt_input CF_API_TOKEN "Enter your Cloudflare API token"
prompt_input MYSQL_ROOT_PASSWORD "Enter a secure MySQL root password"
prompt_input GHOST_DB_NAME "Enter a name for the Ghost database (e.g., ghost_prod)"
prompt_input GHOST_DB_USER "Enter a MySQL username for Ghost (e.g., ghost_user)"
prompt_input GHOST_DB_PASSWORD "Enter a password for the Ghost MySQL user"

# Confirm installation settings
echo "Summary of configuration:"
echo "Email: $EMAIL"
echo "Domain: $DOMAIN"
echo "Cloudflare API Token: (hidden for security)"
echo "MySQL Root Password: (hidden for security)"
echo "Ghost Database Name: $GHOST_DB_NAME"
echo "Ghost Database User: $GHOST_DB_USER"
echo "Ghost Database User Password: (hidden for security)"
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

# Configure MySQL root user for password authentication
echo "Configuring MySQL root user to use password authentication..."
sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY '$MYSQL_ROOT_PASSWORD';
FLUSH PRIVILEGES;
EOF

# Create a dedicated Ghost database and user
echo "Creating Ghost database and user..."
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE $GHOST_DB_NAME;
CREATE USER '$GHOST_DB_USER'@'localhost' IDENTIFIED BY '$GHOST_DB_PASSWORD';
GRANT ALL PRIVILEGES ON $GHOST_DB_NAME.* TO '$GHOST_DB_USER'@'localhost';
FLUSH PRIVILEGES;
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
sudo npm install -g ghost-cli@latest

# Ensure the Ghost installation directory has correct permissions
echo "Creating and setting up Ghost installation directory..."
sudo mkdir -p /var/www/ghost
sudo chown $USER:$USER /var/www/ghost
sudo chmod 755 /var/www/ghost
cd /var/www/ghost

# Echo instructions to manually verify Ghost installation
echo "Ghost setup instructions:"
echo "Run the following command to install Ghost in /var/www/ghost and follow the prompts to configure it:"
echo "  ghost install --db=mysql --dbhost=localhost --dbuser=$GHOST_DB_USER --dbpass=$GHOST_DB_PASSWORD --dbname=$GHOST_DB_NAME --process=systemd --no-setup-nginx --no-setup-ssl --url=\"$DOMAIN\""
echo
echo "After completing the Ghost setup, manually verify it by running:"
echo "  ghost status"
echo "and check that your site is accessible at $DOMAIN."

# Download and install Traefik
echo "Downloading and installing Traefik..."
wget https://github.com/traefik/traefik/releases/download/v2.10.1/traefik_v2.10.1_linux_amd64.tar.gz
tar -xvzf traefik_v2.10.1_linux_amd64.tar.gz
sudo mv traefik /usr/local/bin/
rm traefik_v2.10.1_linux_amd64.tar.gz

# Create Traefik configuration files
echo "Configuring Traefik for HTTPS with Cloudflare DNS challenge..."
sudo mkdir -p /etc/traefik /etc/traefik/conf /etc/traefik/certs

# Main Traefik configuration with HTTPS and Let's Encrypt staging
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

# Dynamic Traefik configuration for Ghost (dynamic.yml)
sudo bash -c "cat << EOF > /etc/traefik/conf/dynamic.yml
http:
  routers:
    ghost:
      rule: \"Host(\`$DOMAIN\`)\"
      entryPoints:
        - websecure
      service: ghost
      tls:
        certResolver: staging

  services:
    ghost:
      loadBalancer:
        servers:
          - url: \"http://127.0.0.1:2368\"
EOF"

# Set restrictive permissions on sensitive files
echo "Setting restrictive permissions on Traefik configuration files..."
sudo chmod 600 /etc/traefik/traefik.yml /etc/traefik/certs/cloudflare-acme-staging.json /etc/traefik/conf/dynamic.yml
sudo chown root:root /etc/traefik/traefik.yml /etc/traefik/certs/cloudflare-acme-staging.json /etc/traefik/conf/dynamic.yml

# Cloudflare API token set as an environment variable in Traefik service
echo "Creating secure systemd service for Traefik with Cloudflare token..."
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

# Secure permissions for the Traefik service file
sudo chmod 600 /etc/systemd/system/traefik.service
sudo chown root:root /etc/systemd/system/traefik.service

# Start and enable Traefik
echo "Starting Traefik..."
sudo systemctl daemon-reload
sudo systemctl start traefik
sudo systemctl enable traefik

# Completion message
echo "Setup completed. After manually installing Ghost as instructed above, verify the installation by running 'ghost status' and checking your site at $DOMAIN."
echo "For production, run 'sudo /usr/local/bin/promote_to_production.sh' to switch to production certificates after confirming that everything works in staging mode."
