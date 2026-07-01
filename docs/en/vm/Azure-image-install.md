# Stargate Azure deployment using an image

Deploy Stargate on Azure

## Azure Port 25 (SMTP) Requirements

!!! warning
    Before beginning installation on Microsoft Azure, review the following requirements related to outbound SMTP connectivity on port 25. Skipping this step may result in email delivery failures after installation.

Whether port 25 is available depends on your Azure subscription type:

- :white_check_mark: **Enterprise Agreement (EA) or MCA-E** - Outbound SMTP on port 25 is not blocked. Note that external domains may still reject emails - this is outside Azure's control.
- :white_check_mark: **Enterprise Dev/Test** - Blocked by default, but can be removed. To request removal, go to *Diagnose and Solve* > *Cannot send email (SMTP-Port 25)* in the Azure Virtual Network resource in the Azure portal.
- :x: **All other subscription types** - Blocked and **cannot be unblocked**.

Reference: [Troubleshoot outbound SMTP connectivity in Azure](https://learn.microsoft.com/en-us/troubleshoot/azure/virtual-network/troubleshoot-outbound-smtp-connectivity)

## Get the image file

- Download the latest VHD image file. Please refer to [VM Catalog](VM-Catalog.md?h=vhd)

## Upload the Azure VHD image file

- Navigate to <https://portal.azure.com/#home>
- Click **Storage accounts**.
- Select the storage account to use or create a new one.
- Click **Block service** and then **Containers**.
- Select the Container to upload the file to or create a new one if you do not have a Container.
- Click **Upload** and choose the VHD image file.
- Make sure that the Blob type is Page Blob.

## Create the image

- Navigate to <https://portal.azure.com/#home>
- Click **Images**.
- Click **Create**.
- Choose the Resource group to be used or create a new one.
- Type a Name for the image.
- Choose OS type **Linux** and **VM generation Gen 2**
- At Storage blob, click browse and select the newly uploaded VHD image.
- Click **Review and create**.
- Click **Create**.

## Create a VM

- Navigate to <https://portal.azure.com/#home>
- Click **Virtual Machines**.
- Click **Create**, and choose Virtual Machine from the drop-down menu.
- Choose the Resource group.
- Type a Name for the VM.
- At Image, click "**See all images**", click "**My Images**" and choose the new image that was created.
- Choose the VM size.
- Choose authentication type.
- Click **Next: Disks**
- Select OS disk size at least 20 GiB. Please refer to [Server Requirements](../index.md#server-requirements).
- Click **Review + create**
- Click **Create**

## Find the public IP address of the new VM and add inbound firewall rules

- Navigate to <https://portal.azure.com/#home>
- Click **Virtual Machines**.
- Click on the new VM.
- You can see the public IP address under "Primary NIC public IP"
- Scroll down to Networking and click on it
- Click **+ Create port rule**, Inbound port rule, Destination port ranges 25, Protocol TCP, name it SMTP, repeat the same step with Destination port range 1587 and name it mxengine

## Install HIN Gateway

After the VM has been successfully created, proceed with the installation and onboarding steps as described in the provided [instructions](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/)

!!! tip "Support"

    For any questions or issues related to the deployment and operation of the Stargate appliance, please contact HIN support.

    Please include relevant information such as the customer name, appliance version, and screenshots/[logs](../Docker-advanced.md#provide-logs-to-support) where applicable, to help us process your request efficiently.
