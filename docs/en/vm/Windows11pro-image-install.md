# Windows 11 Pro deployment using an image

Deploy Stargate on Windows Pro (non-Pro versions do not support Hyper-V)

## Install Hyper-V

- Click the Start button, then type "Turn Windows features on or off"
- Click on that button
- Check Hyper-V and click "OK"
- After the installation completes, click "Restart now" and wait for Windows to boot again

**Note:** We recommend deploying the VM using Hyper-V Generation 2

## Get the image

- Download the .vhdx image file. Please refer to [VM Catalog](VM-Catalog.md?h=vhdx)

## Import the image file and create a VM with it

- Click the "Start" button and type "Hyper-V Quick Create"
- Click on that icon
- Choose "Local installation source"
- Uncheck "This machine will run Windows"
- Click "Change installation source", navigate to the downloaded .VHDX image and click on it
- Click "Create virtual machine"
- Click "Edit settings"
- Under "Memory", choose "RAM" 8192 MB. Please refer to [Server Requirements](../index.md#server-requirements).
- Under "Processor", choose "Number of virtual processors" 4. Please refer to [Server Requirements](../index.md#server-requirements).
- Click "OK"
- Click "Connect"
- Click "Start"

## Install HIN Gateway

After the VM has been successfully created, proceed with the installation and onboarding steps as described in the provided [instructions](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/)

!!! tip "Support"

    For any questions or issues related to the deployment and operation of the Stargate appliance, please contact HIN support.

    Please include relevant information such as the customer name, appliance version, and screenshots/[logs](../Docker-advanced.md#provide-logs-to-support) where applicable, to help us process your request efficiently.
