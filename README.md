# Docker Projects Deployment via Portainer

This guide will walk you through deploying Docker projects (any services or stacks) using Portainer. We'll use a GitHub repository to pull the `docker-compose.yml` directly from Portainer, and you'll create a local `.env` file to provide environment variables as needed for each project.

## Prerequisites

- **Portainer** is installed and running.
- **Traefik** (optional) is configured separately to handle routing and SSL, especially for projects requiring HTTPS, such as web applications.
- Any environment variables needed for your Docker project (such as API tokens, database credentials, etc.) should be prepared in advance.

---

## Step 1: Set Up the Stack in Portainer

### 1.1 Log in to Portainer

Open your Portainer instance in your browser (e.g., `http://<your-server-ip>:9000`) and log in with your credentials.

### 1.2 Create a New Stack

1. In the left sidebar, click on **Stacks**.
2. Click **Add Stack** in the top-right corner.
3. Give your stack a name (e.g., `my_project_stack`).
4. Under **Repository**, enter the following details:
    - **Repository URL**: `https://github.com/bmurrtech/docker_projects.git`
    - **Repository Reference**: leave blank
    - **Compose Path**: `<project_folder>/docker-compose.yml` (Replace `<project_folder>` with the folder for the project, e.g., `ghost_blog`).

Portainer will now be set to pull the `docker-compose.yml` directly from your GitHub repository for the selected project.

![example_repo_config](https://i.imgur.com/YpSpSIR.png)

---

## Step 2: Use the Provided `.env.example` File

For projects that require environment variables (such as API tokens, credentials, or domain names), you need to create a local `.env` file. If the repository includes a .env.example file, it will often list all the required environment variables with placeholders. You can copy the .env.example to create your .env file, and fill in your own values.

### How to Find the Required Variables if no .env.example File
- Check the docker-compose.yml File:
- Open the docker-compose.yml file for the specific project you're deploying.
- Look for any variables that are wrapped in ${}. These indicate that the value for those variables will be supplied through the .env file.
- Example:

```yaml
environment:
  - MYSQL_PASSWORD=${MYSQL_PASSWORD}
  - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
```

### 2.1 Create Your Own `.env` File on Your Local Machine or Add the Specific Environment Variables Required 

On your local machine, create a file named `.env` using a text editor (e.g., Notepad, VSCode) and add the relevant content. For example:

```bash
# Example for a MySQL-based project:
MYSQL_PASSWORD=your-db-password
MYSQL_ROOT_PASSWORD=your-root-password
DOMAIN_NAME=yourdomain.com
```

---

### Entering Environment Variables Manually (Optional)

![example_variables_add](https://i.imgur.com/V40hQE2.png)

If you don’t want to store the `.env` file on your local machine, you can manually enter the environment variables in Portainer.

1. **Scroll down to the Environment Variables section** in the Portainer stack creation screen.

2. **Click on the "Add an environment variable" button**.

3. **Map the environment variables correctly**. You need to enter the variables as required by the project, such as:
   - **DB_USER**: The username for the database.
   - **DB_PASSWORD**: The password for the database.
   - **DOMAIN_NAME**: The domain name for your project (if applicable).

4. **Example values** you should enter:
   | Variable             | Value                |
   |----------------------|----------------------|
   | `DB_USER`            | your-db-user         |
   | `DB_PASSWORD`        | your-db-password     |
   | `DOMAIN_NAME`        | yourdomain.com       |

6. **Deploy the stack** once all environment variables have been added correctly.

---

### 2.2 Upload the `.env` File to Portainer

1. Scroll down to the **Environment variables** section in Portainer.
2. Click **Upload .env file** and upload the `.env` file you just created.
3. Verify that the correct environment variables are shown.

---

## Step 3: Deploy the Stack

After you’ve set up the repository and uploaded the `.env` file, you’re ready to deploy the stack:

1. Scroll to the bottom and click **Deploy the stack**.
2. Portainer will now pull the `docker-compose.yml` file from your GitHub repository and create the services for your Docker project.

---

## Step 4: Access Your Project

Once the stack has been deployed:

1. **Access Your Project**:
   - Depending on the project, open your browser and navigate to the appropriate domain or IP address (e.g., `http://<your-server-ip>:port` or `https://yourdomain.com`).

2. **Manage the Stack**:
   - You can manage the services directly in Portainer by going to the **Containers** section. From there, you can view logs, restart services, or troubleshoot if necessary.

---

## Troubleshooting

- **Project Not Accessible**: If you can’t access your project, verify that:
  - If using Traefik, make sure it is properly routing traffic to the container.
  - The environment variables in the `.env` file are correct.
  - Use Portainer to check the **logs** of the containers to diagnose issues.

---

## Example `.env` File

Here’s an example of what your `.env` file could look like for a MySQL-based project:

```bash
MYSQL_PASSWORD=mydbpassword123
MYSQL_ROOT_PASSWORD=myrootpassword123
DOMAIN_NAME=myproject.com
```

Make sure to replace the placeholder values with your actual credentials and settings.

---

## Example `docker-compose.yml` File

The following is an example of a `docker-compose.yml` file provided for a generic project in this repository:

```yaml
version: "3.8"

services:
  app:
    image: your-app-image:latest
    restart: always
    environment:
      - APP_ENV=production
      - DB_HOST=db
      - DB_USER=${DB_USER}
      - DB_PASSWORD=${DB_PASSWORD}
    volumes:
      - ./app_data:/var/lib/app_data
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`${DOMAIN_NAME}`)"
      - "traefik.http.routers.app.entrypoints=websecure"
      - "traefik.http.routers.app.tls=true"
      - "traefik.http.services.app.loadbalancer.server.port=8080"
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
      - MYSQL_DATABASE=appdb
      - MYSQL_USER=${DB_USER}
      - MYSQL_PASSWORD=${DB_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
    volumes:
      - ./db_data:/var/lib/mysql
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
  app_data:
  db_data:
```

---

## Troubleshooting: Manually Cloning and Uploading `docker-compose.yml`

If you encounter an error when trying to pull the repository through Portainer, you can manually clone the repository to your local machine and upload the `docker-compose.yml` file to Portainer using the **upload** option.

### Steps to Manually Clone and Upload:

1. **Open a terminal** on your local machine.

2. **Run the following command** to manually clone the repository:
   ```bash
   git clone https://github.com/yourusername/docker_projects.git
   ```

3. **Navigate to the appropriate project folder** where the `docker-compose.yml` is located:
   ```bash
   cd docker_projects/<project_folder>
   ```

4. **Log in to Portainer**.

5. **Create a new stack** in Portainer:
   - Go to the **Stacks** section and click **Add stack**.
   - **Upload the `docker-compose.yml` file** from the project folder on your local machine by clicking **Upload**.

6. **Deploy the stack** as usual by clicking **Deploy the stack**.

---

By following these steps, you can deploy any Docker project using Portainer with ease.
