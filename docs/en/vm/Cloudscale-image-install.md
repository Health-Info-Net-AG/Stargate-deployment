# Stargate Deployment on Cloudscale Using an Image

## Get the Image File URL

- Refer to the [VM Catalog](VM-Catalog.md?h=qcow2) for available images with URLs.
- Copy the `qcow2` URL to your clipboard.

## Import the Image File in Cloudscale

- In the Cloudscale WebUI, navigate to the "Custom Images" menu and click "Import a Custom Image".
- Set an appropriate **Image Name**.
- Define a **Slug**, e.g., "stargate".
- Paste the Stargate image URL into the **Download URL** field.
- Set **Source Format** to the upload format, recommended: `qcow2`.
- Configure additional settings as needed.
- Click **Import**.

## Create a VM

- Navigate to **Servers** and click **Launch a new Server**.
- Enter your preferred **FQDN** or hostname.
- Under **Operating System**, select **Custom Images** and choose your imported image.
- Under **Compute Flavor**, select **Flex-4-2** or **Flex-8-2** depending on expected load (can be adjusted later). See [Server Requirements](../index.md#server-requirements) for details.
- Under **Storage Capacity**, set at least **20 GB**. Please refer to [Server Requirements](../index.md#server-requirements).
- Under **Server Location**, select your preferred zone.
- Under **Network Management**, enable only **IPv4** if the Stargate instance must be internet-accessible (e.g., for Office 365).
- Under **Access Security**, select your SSH key (usable with the `almalinux` user).
- Click **Launch**.

## Install HIN Gateway

After the VM has been successfully created, proceed with the installation and onboarding steps as described in the provided [instructions](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/)

!!! tip "Support"

    For any questions or issues related to the deployment and operation of the Stargate appliance, please contact HIN support.

    Please include relevant information such as the customer name, appliance version, and screenshots/[logs](../Docker-advanced.md#provide-logs-to-support) where applicable, to help us process your request efficiently.
