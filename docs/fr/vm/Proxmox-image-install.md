# Proxmox deployment using an image

Deploy Stargate on Proxmox

## Get the image file URL

- Please refer to [VM Catalog](VM-Catalog.md?h=qcow2) for a list of images with URLs.
- Copy URL to clipboard, for example `https://images.hin.ch/vm-images/Verimesh-HINGateway.v0.5.1.x86_64.qcow2`

## Import the image file in Proxmox

- In Proxmox WebUI, navigate to the Storage menu and click Import
- Click **Download from URL**, paste the copied URL and click "Query URL".
- Click Download and wait for "TASK OK" to appear at the end of the output log.
- Close the Task Viewer Download window.

## Create a VM

- Click "Create VM"
- Type a name for the VM
- Click "Next"
- Choose "Do not use any media"
- Click "Next"
- Click "Next"
- Click the "Trash icon" next to "scsi0" to remove it.
- Click "Import" and under "Select Image", choose the newly imported image file.
- Click "Next"
- Select 4 CPU cores and choose your CPU Type (or use "host"). Please refer to [Server Requirements](../index.md#server-requirements).
- Click "Next"
- Select 8192 MiB Memory. Please refer to [Server Requirements](../index.md#server-requirements).
- Click "Next"
- Click "Next"
- Wait until the VM creation process finishes and then click on the new VM, click "Console", click "Start Now"

## Install HIN Gateway

After the VM has been successfully created, proceed with the installation and onboarding steps as described in the provided [instructions](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/)

!!! tip "Support"

    For any questions or issues related to the deployment and operation of the Stargate appliance, please contact HIN support.

    Please include relevant information such as the customer name, appliance version, and screenshots/[logs](../Docker-advanced.md#provide-logs-to-support) where applicable, to help us process your request efficiently.
