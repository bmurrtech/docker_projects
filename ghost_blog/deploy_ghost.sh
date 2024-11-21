#!/bin/bash

# Function to prompt for user input with verification
function prompt_input {
    local var_name="$1"
    local prompt_text="$2"
    local user_input
    while true; do
        read -s -p "$prompt_text: " user_input  # -s hides input
        echo
        echo "You entered: [hidden for security]. Is this correct? (y/n)"
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
prompt_input DOMAIN "Enter your domain for the Ghost site (e.g., blog.yourdomain.com)"
prompt_input CF_API_TOKEN "Enter your Cloudflare API token"
prompt_input MYSQL_ROOT_PASSWORD "Enter a secure MySQL root password"
prompt_input GHOST_DB_NAME "Enter a name for the Ghost database (e.g., ghost_prod)"
prompt_input GHOST_DB_USER "Enter a MySQL username for Ghost (e.g., ghostuser)"
prompt_input GHOST_DB_PASSWORD "Enter a password for the Ghost MySQL user"
prompt_input HOME_IP "Enter your home IP address for SSH access"
prompt_input GHOST_USER "Enter your sudo username (the user running this script)"

# Confirm installation settings
echo "Summary of configuration:"
echo "Email: $EMAIL"
echo "Domain: $DOMAIN"
echo "Cloudflare API Token: (hidden for security)"
echo "MySQL Root Password: (hidden for security)"
echo "Ghost Database Name: $GHOST_DB_NAME"
echo "Ghost Database User: $GHOST_DB_USER"
echo "Ghost Database User Password: (hidden for security)"
echo "Home IP for SSH access: $HOME_IP"
echo "Sudo User: $GHOST_USER"
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

# Install UFW if not already installed
echo "Installing UFW firewall..."
sudo apt install ufw -y

# Configure UFW firewall rules
echo "Configuring UFW firewall rules..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow HTTP and HTTPS traffic
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow SSH from your home IP
sudo ufw allow from $HOME_IP to any port 22

# Deny access to port 2236
sudo ufw deny 2236

# Enable UFW
echo "Enabling UFW firewall..."
sudo ufw --force enable

# Harden SSH configuration
echo "Hardening SSH configuration..."
sudo sed -i "/^#*AllowUsers /d" /etc/ssh/sshd_config
echo "AllowUsers $GHOST_USER" | sudo sudo tee -a /etc/ssh/sshd_config

# Do not disable root login to avoid disconnecting current session
# Instead, ensure only the specified user can SSH in
# Copy SSH keys if necessary (assuming already done manually)

# Restart SSH service
echo "Restarting SSH service..."
sudo systemctl restart sshd

# Install and configure Fail2Ban
echo "Installing and configuring Fail2Ban..."
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Configure Fail2Ban to ignore home IP
echo "Configuring Fail2Ban to ignore your home IP..."
sudo bash -c "cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = 127.0.0.1/8 $HOME_IP
EOF"

# Restart Fail2Ban service
sudo systemctl restart fail2ban

# Secure shared memory
echo "Securing shared memory..."
if ! grep -q 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' /etc/fstab; then
    sudo bash -c "echo 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' >> /etc/fstab"
fi

# Install unattended-upgrades
echo "Installing unattended-upgrades for automatic security updates..."
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure --priority=low unattended-upgrades

# Install MySQL 8
echo "Installing MySQL 8..."
wget https://dev.mysql.com/get/mysql-apt-config_0.8.22-1_all.deb
sudo dpkg -i mysql-apt-config_0.8.22-1_all.deb
sudo apt update
sudo apt install -y mysql-server
rm mysql-apt-config_0.8.22-1_all.deb

# Configure MySQL root user for password authentication
echo "Configuring MySQL root user to use password authentication..."
sudo mysql <<MYSQL_EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY '$MYSQL_ROOT_PASSWORD';
FLUSH PRIVILEGES;
MYSQL_EOF

# Create a dedicated Ghost database and user
echo "Creating Ghost database and user..."
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<MYSQL_EOF
CREATE DATABASE $GHOST_DB_NAME;
CREATE USER '$GHOST_DB_USER'@'localhost' IDENTIFIED BY '$GHOST_DB_PASSWORD';
GRANT ALL PRIVILEGES ON $GHOST_DB_NAME.* TO '$GHOST_DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_EOF

# Fix the authentication plugin for Ghost user
echo "Changing authentication plugin for Ghost user to mysql_native_password..."
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<MYSQL_EOF
ALTER USER '$GHOST_DB_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$GHOST_DB_PASSWORD';
FLUSH PRIVILEGES;
MYSQL_EOF

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
sudo chown $GHOST_USER:$GHOST_USER /var/www/ghost
sudo chmod 755 /var/www/ghost

# Remove contents of /var/www/ghost but not the folder
echo "Cleaning up /var/www/ghost directory..."
sudo rm -rf /var/www/ghost/*

cd /var/www/ghost

# Run Ghost CLI installation
echo "Running Ghost CLI install..."
ghost install --db=mysql --dbhost=localhost --dbuser=$GHOST_DB_USER --dbpass=$GHOST_DB_PASSWORD --dbname=$GHOST_DB_NAME --process=systemd --no-setup-nginx --no-setup-ssl --url="$DOMAIN"

# Modify the config.production.json to force IPv4
echo "Modifying config.production.json to force IPv4 for MySQL connection..."
sudo sed -i 's/"host": "localhost"/"host": "127.0.0.1"/' /var/www/ghost/config.production.json

# Dynamic Traefik configuration for Ghost (dynamic.yml)
echo "Creating Traefik dynamic.yml configuration..."
sudo bash -c "cat <<EOF > /etc/traefik/conf/dynamic.yml
http:
  routers:
    ghost:
      rule: Host(\\\"\$DOMAIN\\\")
      entryPoints:
        - websecure
      service: ghost
      tls:
        certResolver: staging

  services:
    ghost:
      loadBalancer:
        servers:
          - url: http://127.0.0.1:2368
EOF"

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
      email: \"$EMAIL\"
      storage: \"/etc/traefik/certs/cloudflare-acme-staging.json\"
      caServer: \"https://acme-staging-v02.api.letsencrypt.org/directory\"
      dnsChallenge:
        provider: cloudflare
        delayBeforeCheck: 0
        resolvers:
          - \"1.1.1.1:53\"
          - \"8.8.8.8:53\"

providers:
  file:
    directory: \"/etc/traefik/conf\"
    watch: true
EOF"

# Dynamic Traefik configuration for Ghost (dynamic.yml)
sudo bash -c "cat << EOF > /etc/traefik/conf/dynamic.yml
http:
  routers:
    ghost:
      rule: \"Host(\\\`$DOMAIN\\\`)\"
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

# Clear bash history to ensure no sensitive data is logged
echo "Clearing bash history..."
history -c
history -w

# Completion message
echo "Setup completed."
echo "You may need to run the following command to start Ghost:"
echo "cd /var/www/ghost && ghost start"
echo "Verify the installation by running 'ghost status' and checking your site at https://$DOMAIN."
echo "For production, run 'sudo /usr/local/bin/promote_to_production.sh' to switch to production certificates after confirming that everything works in staging mode."
