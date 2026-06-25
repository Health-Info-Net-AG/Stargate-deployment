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

## Log in and initialize the Stargate instance

- Log in to the VM console with the `hinadmin` user in order to configure and install the Stargate components.
- To obtain the `hinadmin` password, send an email to <support@hin.ch> with the subject: **"Password required for VM installation."**

[Click here to send an Email](mailto:support@hin.ch?subject=Password%20required%20for%20VM%20installation.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20password%20for%20a%20VM%20installation.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

```shell
sudo su -
cd ~/stargate-deployment/docker-compose/
```

- Use vi/nano to edit `customer-config.sh`
- Configuration details can be found in the [README - Step 1: Configure Customer Settings](../Docker-deploy.md#step-1-configure-customer-settings)
- Run the install script:

```shell
./scripts/install.sh
```

!!! tip "Support"

    For any questions or issues related to the deployment and operation of the Stargate appliance, please contact HIN support.

    Please include relevant information such as the customer name, appliance version, and screenshots/[logs](../Docker-advanced.md#provide-logs-to-support) where applicable, to help us process your request efficiently.
