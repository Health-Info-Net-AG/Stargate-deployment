# HIN Gateway Deployment on Cloudscale Using an Image

## Get the Image File URL

- Refer to the [VM Catalog](VM-Catalog.md?h=qcow2) for available images with URLs.
- Copy the `qcow2` URL to your clipboard.

## Import the Image File in Cloudscale

- In the Cloudscale WebUI, navigate to the "Custom Images" menu and click "Import a Custom Image".
- Set an appropriate **Image Name**.
- Define a **Slug**, e.g., "stargate".
- Paste the HIN Gateway image URL into the **Download URL** field.
- Set **Source Format** to the upload format, recommended: `qcow2`.
- Configure additional settings as needed.
- Click **Import**.

## Create a VM

- Navigate to **Servers** and click **Launch a new Server**.
- Enter your preferred **FQDN** or hostname.
- Under **Operating System**, select **Custom Images** and choose your imported image.
- Under **Compute Flavor**, select **Flex-4-2** or **Flex-8-2** depending on expected load (can be adjusted later). See [Server Requirements](../index.md#server-requirements) for details.
- Under **Storage Capacity**, set at least **30 GB**. Please refer to [Server Requirements](../index.md#server-requirements).
- Under **Server Location**, select your preferred zone.
- Under **Network Management**, enable only **IPv4** if the HIN Gateway instance must be internet-accessible (e.g., for Office 365).
- Under **Access Security**, select your SSH key (usable with the `almalinux` user).
- Under **Password**, set any secure password you prefer.

!!! tip "Without a password, SSH password authentication is disabled"
    You must still use the initial password provided by HIN for your first login. However, if you do not set a new password, cloud-init will disable SSH password authentication for all users, allowing SSH access only via public key authentication.

- Click **Launch**.

!!! warning "Attach the Data Disk first"
    Before the first boot, attach a second, blank disk of at least 30 GB. On first boot the appliance formats it as the Data Disk (`VEREIGN-DATA`, mounted at `/var/data`) and keeps all config and data there; without it the boot fails and rolls back. See [Installation guide → Step 4](../Installation-guide.md#step-4-load-vm-image).

## Install HIN Gateway

After the VM has been successfully created, proceed with the installation and onboarding steps as described in the provided [instructions](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/)

!!! tip "Support"

    For any questions or issues related to the deployment and operation of the HIN Gateway appliance, please contact HIN support.

    Please include relevant information such as the customer name, appliance version, and screenshots/[logs](../Docker-advanced.md#provide-logs-to-support) where applicable, to help us process your request efficiently.
