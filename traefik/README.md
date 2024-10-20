

# Traefik Setup Guide

```
/home/btm/traefik/
│
├── docker-compose.yml         # Docker Compose configuration
├── .env.example                       # Environment variables (personalized info, not tracked)
├── startup.sh                 # Initialization and stack launch script
├── config/                    # Traefik configuration directory
│   ├── traefik.yml            # Traefik main config (uses variables, tracked by Git)
│   ├── conf/                  # Additional Traefik configs (dynamic)
│   │   └── .gitkeep           # Placeholder to keep the folder in Git
│   ├── certs/                 # Store certificates
│   │   └── .gitkeep           # Placeholder to keep the folder in Git
```

## Download Required Files for Traefik Setup

To set up Traefik, you must manually download this file:

- `traefik.yml` for configuring Traefik

You can download these files directly to the your ideal folder path using `wget`.

### Step 1: Create the Necessary Directories

First, ensure the correct directory structure is created for storing these files:

```bash
mkdir -p traefik/config
```

### Step 2: Download the `traefik.yml` File

Use the following `wget` command to download the `traefik.yml` file:

```bash
wget https://raw.githubusercontent.com/bmurrtech/docker_projects/main/traefik/config/traefik.yml -P /path/to/your/desired/folder
```

Replace `/path/to/your/desired/folder/traefik/config` with the actual directory path where you want to save the `traefik.yml` file.

This will start Traefik and enable SSL certificate management via Let's Encrypt.


# Cloudflare API Token Configuration for Traefik

This document outlines the proper configuration for creating a Cloudflare API token to be used with Traefik's Let's Encrypt DNS challenge.

## Step 1: Create a New API Token

1. Go to your [Cloudflare Dashboard](https://dash.cloudflare.com/).
2. Under **My Profile**, select **API Tokens** and click **Create Token**.

## Step 2: Set API Token Permissions

- **Permissions**: Select **Zone: DNS: Edit**.
  - This permission allows Traefik to modify DNS records during the Let's Encrypt DNS challenge.
- Optionally, add another permission for **DNS: Read** to allow Traefik to read DNS records.

## Step 3: Set Zone Resources

- In the **Zone Resources** section:
  - Set it to **Include** and select **Specific Zone**.
  - Choose the specific domain that Traefik will be managing DNS for (e.g., `example.com`).

## Step 4: Client IP Address Filtering (Optional)

- If you have a **static IP address**, you can restrict the token to be usable only from that IP.
  - Set the **Operator** to `Equal` and add your **static public IP address** in the **Value** field.
  - This can be your **home IP** or **server's IP** depending on where Traefik is running.

To find your public IP address, use:
```bash
curl ifconfig.me
```

- If you don’t have a static IP, it’s better to leave this section empty.

## Step 5: Set TTL (Optional)

- Optionally, you can set the **Start Date** and **End Date** to limit how long the token will be valid.
- If you want the token to be valid indefinitely, you can leave this section blank.

## Step 6: Finalize the Token

1. Click **Continue to Summary** to review the settings.
2. Once verified, click **Create Token**.
3. **Copy the API Token** immediately, as you won’t be able to see it again.

## Step 7: Configure Traefik

1. Add the token to your `.env` file:

    ```bash
    CF_DNS_API_TOKEN=your-cloudflare-api-token
    ACME_EMAIL=your-email@example.com
    ```

2. Update your **`traefik.yml`** configuration for the DNS challenge:

    ```yaml
    certificatesResolvers:
      cloudflare:
        acme:
          email: "${ACME_EMAIL}"
          storage: "/etc/traefik/certs/acme.json"
          dnsChallenge:
            provider: cloudflare
            resolvers:
              - "1.1.1.1:53"   # Cloudflare DNS
              - "8.8.8.8:53"   # Google DNS
    ```

This will allow Traefik to use the API token to modify DNS records in Cloudflare and complete the DNS challenge for issuing certificates.

## Notes:

- Ensure that the **API token** has the correct permissions, particularly **Zone: DNS: Edit**.
- If you use **Client IP Address Filtering**, ensure that the IP address entered is static and matches where Traefik is running.
- Remember to **disable the Cloudflare proxy (orange cloud)** during the DNS challenge for the domain, but after confirmed, you can reenabled the proxy.

---

By following these steps, you will successfully configure the Cloudflare API token to work with Traefik for issuing SSL certificates via the Let's Encrypt DNS challenge.
