# Stargate VMware ESXi deployment using an image

Deploy Stargate on VMware

## Get the image file

- Download the latest OVA (or OVF and VMDK if you prefer) image file. Please refer to [VM Catalog](VM-Catalog.md?h=ova)

## Navigate to the ESXi web UI

- Click **Virtual Machines**
- Click **Create/Register VM**
- Choose "Deploy a virtual machine from an OVF or OVA file"
- Click **Next**
- Type a name for the VM
- Click **Next**
- Click to select files and choose the OVA image file (or OVF and VMDK if you prefer)
- Click **Next**
- Choose a storage to use
- Click **Next**
- Choose Network and Disk for provisioning
- Click **Next**
- Click **Finish**

!!! info "Data Disk included"
    The OVA already contains the appliance's Data Disk (`VEREIGN-DATA`, mounted at `/var/data`) — there is no extra disk to attach. See [Installation guide → Step 4](../Installation-guide.md#step-4-load-vm-image).

## Install HIN Gateway

After the VM has been successfully created, proceed with the installation and onboarding steps as described in the provided [instructions](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/)

!!! tip "Support"

    For any questions or issues related to the deployment and operation of the Stargate appliance, please contact HIN support.

    Please include relevant information such as the customer name, appliance version, and screenshots/[logs](../Docker-advanced.md#provide-logs-to-support) where applicable, to help us process your request efficiently.
