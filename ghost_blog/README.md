
# Ghost Blog Deployment via Portainer

This guide will walk you through deploying a Ghost blog with MySQL using Docker and Portainer. We'll use a GitHub repository to pull the `docker-compose.yml` directly from Portainer, and you'll create a local `.env` file to provide environment variables like database credentials and your domain name.

## Prerequisites

- **Portainer** is installed and running.
- **Traefik** is configured separately to handle routing and SSL to the custom "frontend" network.
- A valid **domain name** for your Ghost blog.
- (Optional) CloudFlare account configured with Traefik as a reverse proxy to view you blog on the internet.

---

## Step 1: Set Up the Stack in Portainer

### 1.1 Log in to Portainer

Open your Portainer instance in your browser (e.g., `http://<your-server-ip>:9000`) and log in with your credentials.

### 1.2 Create a New Stack

1. In the left sidebar, click on **Stacks**.
2. Click **Add Stack** in the top-right corner.
3. Give your stack a name (e.g., `ghost_blog_stack`).
4. Under **Repository**, enter the following details:
    - **Repository URL**: `https://github.com/bmurrtech/docker_projects.git`
    - **Repository Reference**: `main`
    - **Compose Path**: `ghost_blog/docker-compose.yml`

Portainer will now be set to pull the `docker-compose.yml` directly from your GitHub repository.

---

## Step 2: Create the `.env` File

You need to create a local `.env` file to provide environment variables that configure your MySQL credentials and domain name for Ghost.

### 2.1 Create the `.env` File on Your Local Machine

On your local machine, create a file named `.env` using a text editor (e.g., Notepad, VSCode) and add the following content:

```bash
# MySQL Database Credentials
MYSQL_PASSWORD=your-ghost-db-password
MYSQL_ROOT_PASSWORD=your-root-password

# Domain Name for Ghost Blog
DOMAIN_NAME=yourdomain.com
```

- **MYSQL_PASSWORD**: Set this to the password for the MySQL `ghost` user.
- **MYSQL_ROOT_PASSWORD**: Set this to the root password for MySQL.
- **DOMAIN_NAME**: Replace this with the domain name where Traefik will route traffic to your Ghost blog (e.g., `blog.example.com`).

### 2.2 Upload the `.env` File to Portainer

1. Scroll down to the **Environment variables** section in Portainer.
2. Click **Upload .env file** and upload the `.env` file you just created.
3. Verify that the correct environment variables are shown.

---

## Step 3: Deploy the Stack

After you’ve set up the repository and uploaded the `.env` file, you’re ready to deploy the stack:

1. Scroll to the bottom and click **Deploy the stack**.
2. Portainer will now pull the `docker-compose.yml` file from your GitHub repository and create the services for Ghost and MySQL.

---

## Step 4: Access the Ghost Blog

Once the stack has been deployed:

1. **Access Your Ghost Blog**:
   - Open your browser and navigate to `https://yourdomain.com` (replace with your actual domain).
   - Ghost should be accessible through the domain, and you can proceed with the initial setup.

2. **Manage the Stack**:
   - You can manage the services (Ghost and MySQL) directly in Portainer by going to the **Containers** section. From there, you can view logs, restart services, or troubleshoot if necessary.

---

## Troubleshooting

- **Ghost Blog Not Accessible**: If you can’t access your Ghost blog, verify that:
  - Traefik is properly routing traffic to the Ghost container.
  - The `DOMAIN_NAME` in the `.env` file is correct.
  - Use Portainer to check the **logs** of the Ghost and MySQL containers to diagnose issues.

---

## Example `.env` File

Here’s an example of what your `.env` file should look like:

```bash
MYSQL_PASSWORD=ghostpassword123
MYSQL_ROOT_PASSWORD=rootpassword123
DOMAIN_NAME=blog.example.com
```

Make sure to replace the placeholder values with your actual credentials and domain name.

---

## Example `docker-compose.yml` File

The following is the `docker-compose.yml` file provided in this repository:

```yaml
version: "3.8"

services:
  ghost:
    image: ghost:latest
    restart: always
    environment:
      - database__client=mysql
      - database__connection__host=db
      - database__connection__user=ghost
      - database__connection__password=${MYSQL_PASSWORD}
      - database__connection__database=ghostdb
      - url=https://${DOMAIN_NAME}
    volumes:
      - ./ghost_content:/var/lib/ghost/content
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.ghost.rule=Host(`${DOMAIN_NAME}`)"
      - "traefik.http.routers.ghost.entrypoints=websecure"
      - "traefik.http.routers.ghost.tls=true"
      - "traefik.http.routers.ghost.tls.certresolver=myresolver"
      - "traefik.http.services.ghost.loadbalancer.server.port=2368"
    networks:
      - frontend
      - internal
    depends_on:
      db:
        condition: service_healthy

  db:
    image: mysql:latest
    restart: always
    environment:
      - MYSQL_DATABASE=ghostdb
      - MYSQL_USER=ghost
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
    volumes:
      - ./mysql_data:/var/lib/mysql
    networks:
      - internal
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

networks:
  frontend:
    external: true
  internal:
    driver: bridge

volumes:
  ghost_content:
  mysql_data:
```

---

With this guide, you can deploy your Ghost blog using Portainer, and it will automatically pull the necessary files from the GitHub repository.
