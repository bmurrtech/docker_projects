
# Ghost Blog Deployment Tutorial for Dedicated Server

This tutorial explains how to deploy a **Ghost blog** on your dedicated server using a script that automates the setup process. It simplifies the steps and avoids using Portainer. It also helps in setting up **Cloudflare DNS**, obtaining SSL certificates from **Let's Encrypt**, and promoting the certificate to production.

## Prerequisite
Before running the script, ensure that you have configured your **Cloudflare DNS API** with both **read and write permissions** for managing the DNS challenge. This is necessary for the ACME certificate process.

---

## Step-by-Step Guide

### 1. **Make Your User a Sudo User**

Ensure your user has sudo privileges to install necessary dependencies and make system-level changes.

```
sudo usermod -aG sudo your_username
```

### 2. **Create a `/bin` Directory in Your User Directory**

Create a directory for executable scripts in your user's home directory.

```
mkdir ~/bin
```

### 3. **Download `deploy_ghost.sh` Script Using `wget`**

Download the `deploy_ghost.sh` script from the raw GitHub URL. This script will automate the Ghost blog deployment.

```
cd ~/bin
wget https://raw.githubusercontent.com/yourgithubusername/repositoryname/main/deploy_ghost.sh
```

**Note**: Replace `https://raw.githubusercontent.com/yourgithubusername/repositoryname/main/deploy_ghost.sh` with the actual raw URL of the `deploy_ghost.sh` script on GitHub.

### 4. **Make the Script Executable**

Make the `deploy_ghost.sh` script executable by changing its permissions.

```
chmod +x deploy_ghost.sh
```

### 5. **Run the Script**

Now, run the `deploy_ghost.sh` script to start the Ghost blog setup.

```
./deploy_ghost.sh
```

The script will prompt you to provide the following information:
- **Cloudflare API token** (with read and write permissions)
- **Email address** for **Let's Encrypt** certificate
- **Domain name** for your Ghost blog (e.g., `blog.cybersoar.us`)
- Other necessary details like database and Ghost configuration.

### 6. **Promote to Production**

After the blog is up and running, the script will create a **`promote_to_production.sh`** script inside the `/home/your_username/bin` folder.

This script is used to promote the **Let's Encrypt staging certificate** to a **production-ready certificate**.

- **Note**: You need to **manually run** the `promote_to_production.sh` script after confirming the blog is functional and accessible to the public.
  
```
./promote_to_production.sh
```

### 7. **Rate Limit Caution for Let's Encrypt**

Let's Encrypt has a **rate limit of 5 certificate requests per week** for the same domain. To avoid hitting the limit, the script uses the **staging server** for testing purposes by default.

- **Staging Certificates** are **not trusted by browsers** but allow you to test the configuration. After confirming that the website is working fine, you should run the `promote_to_production.sh` script to issue a **production certificate** from Let's Encrypt.

### 8. **Security Risk and Update Caution**

**Security Risk**: If you don't keep your **Ghost blog** updated, your website will become vulnerable to security issues. It's recommended to either **set up a cron job** or manually update the blog to keep it patched.

- **Cron Job Caution**: While setting up a **cron job** for updates is ideal for minor patches, it may not be suitable for **major version updates** that could potentially **break the site**. 

- **Backup Caution**: Ensure you **back up** your blog regularly. If you don't have backups and a major update breaks the site, recovery can be difficult and time-consuming.

### Conclusion

- The **deploy_ghost.sh** script simplifies the process of deploying your Ghost blog with Cloudflare DNS, obtaining SSL certificates, and configuring your environment.
- Always ensure that your blog is regularly updated to mitigate potential security risks, and consider setting up a backup strategy to make recovery easier in case of any issues.


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


## Troubleshooting: Manually Cloning and Uploading `docker-compose.yml`

If you encounter an error when trying to pull the repository through Portainer, you can manually clone the repository to your local machine and upload the `docker-compose.yml` file to Portainer using the **upload** option.

### Steps to Manually Clone and Upload:

1. **Open a terminal** on your local machine.

2. **Run the following command** to manually clone the repository:
   ```bash
   git clone https://github.com/bmurrtech/docker_projects.git
   ```

3. **Navigate to the `ghost_blog` folder** where the `docker-compose.yml` is located:
   ```bash
   cd docker_projects/ghost_blog
   ```

4. **Log in to Portainer**.

5. **Create a new stack** in Portainer:
   - Go to the **Stacks** section and click **Add stack**.
   - **Upload the `docker-compose.yml` file** from the `ghost_blog` folder on your local machine by clicking **Upload**.

6. **Deploy the stack** as usual by clicking **Deploy the stack**.

---

### Entering Environment Variables Manually (Optional)

If you don’t want to store the `.env` file on your local machine, you can manually enter the environment variables in Portainer.

1. **Scroll down to the Environment Variables section** in the Portainer stack creation screen.

2. **Click on the "Add an environment variable" button**.

3. **Map the environment variables correctly**. You need to enter the following variables:
   - **MYSQL_PASSWORD**: The password for the `ghost` MySQL user.
   - **MYSQL_ROOT_PASSWORD**: The root password for MySQL.
   - **DOMAIN_NAME**: Your Ghost blog's domain name.

4. **Example values** you should enter:
   | Variable             | Value                |
   |----------------------|----------------------|
   | `MYSQL_PASSWORD`      | your-ghost-db-password |
   | `MYSQL_ROOT_PASSWORD` | your-root-password   |
   | `DOMAIN_NAME`         | yourdomain.com       |

5. **Deploy the stack** once all environment variables have been added correctly.

---

By following these steps, you can bypass the repository pull issue and still deploy the Ghost blog stack successfully.
