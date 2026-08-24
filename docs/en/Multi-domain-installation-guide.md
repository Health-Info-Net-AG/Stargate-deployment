# HIN Mail Gateway - Multi-Domain Technical Installation Process

!!! tip
    Technical Installation Process for Multi-Domain Mail Architecture with Microsoft 365

## Introduction

This document provides a comprehensive guide to the technical installation and migration process to the new [HIN Gateway](https://www.hin.ch/de/services/hin-mail/hin-gateway.cfm) ("Stargate Appliance"). It applies to Microsoft 365 mail architectures that operate **multiple trusted domains** within a single Microsoft 365 tenant, and covers both migrating all domains at once and migrating them gradually, in stages, one domain (or a small group of domains) at a time.

The guide is intended for HIN customers, IT administrators and system engineers who are responsible for deploying and configuring the new HIN Gateway, and for migrating from the existing Mail Gateway (MGW) to the new solution.

The HIN Gateway is a secure email gateway solution that enables trusted, encrypted and policy-driven communication within the HIN Trust Circle. It acts as a central intermediary between internal email infrastructures and external communication partners, ensuring that all email traffic is transmitted securely, complies with the organisation's policies and meets HIN's security standards.

## Overview of the mail flow

**Migration process**. <br> ![Migration process overview](assets/installation-guide/multi-domain-migration-scenario.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

- **Incoming emails** are routed via the HIN Gateway, where they are validated, decrypted (if necessary) and checked against trust and security policies before being forwarded to the internal mail server.
- **Outgoing emails** are sent from internal systems to the HIN Gateway, where encryption, routing and policy enforcement are applied before they are transmitted to external recipients.
- **Communication between HIN gateways** is secured by peer certificates and WireGuard tunnels, ensuring trusted communication between domains.
- **During a staged migration**, the existing MGW and the new HIN Gateway operate in parallel for a period of time: the MGW keeps serving the domains that have not yet been migrated on its existing public IP address (Public IP A), while the HIN Gateway serves the already migrated domains on a separate public IP address (Public IP B). A Microsoft 365 mail-flow rule routes each domain to the correct gateway based on the domain name until the migration is complete.

## Installation and migration process

The structured, step-by-step procedure described in this document covers the following points:

1. Preparation and fallback planning
2. Installation and configuration of the HIN Gateway
3. Domain activation and certificate validation
4. Mail server integration and routing configuration
5. Testing, transition to production and post-migration validation
6. Decommissioning of the existing MGW

### Choosing a migration strategy

Before starting, decide how the trusted domains will be moved to the HIN Gateway:

- **Recommended - all domains at once.** All trusted domains are switched over in a single maintenance window. No additional public IP address is required, no temporary connectors or mail-flow rules need to be created on Microsoft 365, and the rollback is simple: power off the HIN Gateway and power the existing MGW back on. This is the shortest cutover window and carries the lowest risk of configuration drift.
- **Alternative - staged, domain-by-domain migration.** Domains are migrated gradually, one (or a small group) at a time, while the remaining domains keep using the existing MGW. This reduces the blast radius of each step, but requires a second public IP address, temporary Microsoft 365 connectors and a domain-based mail-flow rule, careful handling of customer-specific headers, and a rollback that replays the exact change sequence in reverse.

!!! tip "Which scenario applies to you?"
    Choose **all domains at once** whenever your maintenance window and operational constraints allow it. Choose staged migration only when domains must be moved gradually, for example due to compliance windows, third-party dependencies or organisational constraints. The steps below apply to both scenarios; where a step depends on the chosen scenario, both variants are described.

HIN's objective in this process is to ensure a secure, smooth and fully validated migration that causes minimal disruption to operations and guarantees the uninterrupted continuity of email services.

## Frequently asked questions

!!! question "Can I perform the installation and migration on my own?"
    Yes, the installation and migration can be completed entirely by the customer, **except for "Step 1.3 - Export private key(s)"**.

    For security reasons and to keep your private key safe, you must contact HIN Support or join the planned migration call to receive the code required to export the private key from the currently operating Mail Gateway.

    If the installation and migration cannot be completed successfully, please join the planned support call with our engineers.

!!! question "Will there be any outage in email delivery during the migration?"
    This depends on the migration scenario you chose:

    - **All domains at once:** between **"Step 1.5 - Shutdown existing MGW VM"** and **"Step 18 - Configure mail server"**, all emails will be queued on the mail server. Once "Step 18 - Configure mail server" has been completed, the queued emails will be sent out or delivered to the mailbox.
    - **Staged migration:** the existing MGW stays online and keeps serving all domains that have not yet been migrated, so there is no queuing for those domains. For a domain being migrated in the current wave, emails are queued only for the short period between updating that domain's Microsoft 365 mail-flow rule and completing "Step 18 - Configure mail server" for it.

!!! question "Will any emails be lost during the installation and migration?"
    No, no emails will be lost during the installation and migration, in either scenario.

## Overview of the installation steps

| Step | Topic | Responsibility | Scenario |
| :--: | :---- | :------------: | :------- |
| 0 | Check prerequisites | Customer | |
| 1.1 | Smoke test | Customer | |
| 1.2 | Backing up the existing MGW | Customer | |
| 1.3 | Export private key(s) | Customer / HIN | |
| 1.4 | Contingency plan / fallback scenario | Customer | All at once / Staged |
| 1.5 | Shutdown existing MGW VM | Customer | All at once / Staged |
| 2 | WireGuard | Customer | |
| 3 | Select target VM | Customer | |
| 4 | Load VM image | Customer | |
| 5 | Network connection to the VM | Customer | All at once / Staged |
| 6 | Access via the browser | Customer | |
| 7 | Enter activation code | Customer | |
| 8 | Mesh network setup | Customer | All at once / Staged |
| 9 | Establishing secure mesh network | Customer | |
| 10 | Login to Keycloak | Customer | |
| 11 | Update password | Customer | |
| 12 | Update account information | Customer | |
| 13 | Initial configuration and domain setup | Customer | |
| 14 | Configure mail transport | Customer | |
| 15 | Configure whitelist headers | Customer | |
| 16 | Peer certificates | HIN | |
| 17 | Validate peer certificates | Customer | |
| 18 | Configure mail server | Customer | All at once / Staged |
| 19 | Test prior to switchover | Customer | |
| 20 | Validation after switchover | Customer | |
| 21 | Take existing MGW out of service | Customer | All at once / Staged |
| 22 | Change the password of the VM | Customer | |
| Annex 1 | Backing up and restoring the appliance settings | Customer | |

## Detailed steps

### Step 0 - Check prerequisites

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Please ensure that all necessary preparatory steps have been completed before the HIN Gateway migration activities begin.

The following items must be available or confirmed before the installation:

- **Credentials will be delivered to you by HIN**
    - VM credential
    - Keycloak credential
    - Activation code

- **Export of private key**
    - If you are working on a Windows machine that has access to the Mail Gateway VM via port 22, we can support you during the call in enabling the private key export from the MGW.
    - If you do not have access to such a machine, please contact HIN Support by email or phone (<support@hin.ch> / 0848 830 740) to help you establish a support connection via System Administration → Support Connection → Connect.
- **Download latest** version of [VM image](vm/VM-Catalog.md)
- **Firewall**:
    - Allow traffic: any-to-HIN Gateway and HIN Gateway-to-any
        - WireGuard, please refer to [Server Requirements - Inbound Network Access](./index.md#inbound-network-access-firewall-must-allow):
            - Configure the WireGuard port `19818` (TCP/UDP) in your firewall
                - Incoming and outgoing traffic
    - Allow traffic: your administrative machine-to-HIN Gateway VM
        - Installation requirements:
            - HTTPS port `443`
                - Incoming and outgoing traffic
            - Keycloak port `8180`
                - Incoming and outgoing traffic
        - Troubleshooting requirements (optional needed to see logs, modify all parameters):
            - SSH port `22`
                - Incoming and outgoing traffic
            - Dozzle port `8190`
                - Incoming and outgoing traffic
- **DHCP access** should be available for "[Step 5 - Network connection to the VM](#step-5-network-connection-to-the-vm)" (recommended).
- **Backup requirements** - see "Annex 1 - Backing up and restoring the appliance settings".
- Confirmation that the existing MGW will **not** be deleted until acceptance has been completed.
- Access to DNS, mail server connectors, transport rules, and relay settings.
- **Domain inventory** - for every trusted domain that will be migrated, record the following information:

    | Item | Description |
    |------|-------------|
    | Domain name and owner | The domain and the person or team responsible for it |
    | Sec-prefix status | Whether the `sec.<domain>` security prefix is configured |
    | Forwarding / outgoing server | The current relay configuration on the MGW |
    | Header check | Any customer-specific header check configured on the MGW |
    | Certificate file | The existing S/MIME certificate (`.p12`/`.pfx`) for the domain |
    | Test mailbox | A mailbox in the domain that can be used for the smoke test |
    | Migration wave | The wave the domain belongs to (staged migration only) |

- **Microsoft 365 configuration** - record the existing connectors, transport rules, routing rules, DNS records and firewall/NAT settings that apply to every domain.
- **Staged migration only** - reserve a second public IP address (**Public IP B**) for the HIN Gateway and plan its firewall/NAT path. The existing MGW keeps using its current public IP address (**Public IP A**) until all domains have been migrated.

!!! info "Why WireGuard?"
    The WireGuard port fulfils two important functions:

    1. The HIN Gateway uses this port to obtain peer certificates from the HIN CA.
    2. It uses this port to establish a secure tunnel to other HIN Gateways, through which secure data exchange (e.g. email traffic) takes place.

!!! tip "Private key export"
    If you are working on a Windows machine that has access to the Mail Gateway VM via port 22, we can support you during the call in enabling the private key export from the MGW.

    If you do not have access to such a machine, please contact HIN Support by email or phone (**support@hin.ch** / **0848 830 740**) to help you establish a support connection via **System Administration → Support Connection → Connect**.

### Step 1.1 - Smoke test

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Send a test email to the following recipients, where you have access to the mailbox to check correct receipt:

- An HIN email address or HIN community domain of yours, for example: `user@hin.ch`
- An email address outside of the HIN community, for example: `user@bluewin.ch`

Verify that both emails are delivered successfully, including subject, content and attachment (if sent).

Repeat this test for a mailbox in **every trusted domain** that will be migrated, and record the HIN Community and external delivery results per domain before making any changes.

### Step 1.2 - Backing up the existing MGW

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Create a backup of the existing MGW appliance and ensure that the VM is retained until the migration has been successfully completed and formally accepted. For more information, see "Annex 1 - Backing up and restoring the appliance settings".

!!! info "Check current MGW routing configuration"
    Before shutting down the existing MGW, check the following configuration values and note them down. You will likely need them later when configuring the HIN Gateway:

    1. Log in to the MGW and go to **"Mail System → Outgoing server"** and check whether anything is configured there.
    2. For each domain hosted on the MGW, go to `Mail System → <domain> → Forwarding server` and `Mail System → <domain> → Send ALL outgoing mails from this domain to the following SMTP server`, and record the current values.
    <br> ![domain-relay-host](assets/installation-guide/step1.2-domain-relay-host.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

!!! tip "MGW header check"
    If you use the `Header check` option in the MGW, note down the configured value as well. You can set up the same header check later in the HIN Gateway.

!!! tip "Staged migration - change protocol"
    If you are migrating in stages, keep a change protocol that records, for every change you make: the previous value, the new value, the test result and the rollback action. This log is essential to reverse a wave correctly if a rollback is required.

### Step 1.3 - Export private key(s)

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)
:heavy_plus_sign:
![Responsibility HIN](https://img.shields.io/badge/Responsibility-HIN-orange)

!!! warning "HIN assistance required"
    An unlock code is required for this step. The code is provided by a HIN Support Engineer.
If you would like to continue the installation on your own, please contact HIN Support to request the unlock code. Otherwise, the unlock code will be provided during the planned migration call.

<!-- !!! info
    Please download tool `HIN_Migration-Tool_v*.exe` under the Link: [link](https://link) -->

1. Log into the existing MGW webGUI.
2. Open **"Mail System"**. <br> ![Open Mail System](assets/installation-guide/step1.3-2-open-mail-system.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
3. Run the application by clicking on [**`HIN_Migration-Tool_v*.exe`**](https://images.hin.ch/mgw/HIN_MigrationTool-v3.0.exe) if you want to install it yourself. Alternatively, you can wait until the migration call, where the support engineer will assist you with the installation. <br> ![HIN Migration Tool](assets/installation-guide/step1.3-3-migration-tool.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
4. Enter the unlock code that the support engineer provides to you. <br> ![Enter unlock code](assets/installation-guide/step1.3-4-unlock-code.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
5. Select **"Enable export"**. <br> ![Enable export](assets/installation-guide/step1.3-5-enable-export.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
6. Enter the MGW IP address. <br> ![Enter MGW IP address](assets/installation-guide/step1.3-6-mgw-ip.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
7. Wait for confirmation. <br> ![Wait for confirmation](assets/installation-guide/step1.3-7-confirmation.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
8. Select the trusted domain in the MGW webGUI. <br> ![Select trusted domain](assets/installation-guide/step1.3-8-trusted-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
9. Scroll down and select the managed fingerprint. <br> ![Select managed fingerprint](assets/installation-guide/step1.3-9-managed-fingerprint.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
10. Scroll down to the **"PKCS12 download"** category (you may optionally enter a password to encrypt the key). Press **"Download PKCS12"** and save the `*.p12` file on the computer. <br> ![PKCS12 download](assets/installation-guide/step1.3-10-pkcs12-download.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
11. Return to the `HIN_Migration-Tool_v*.exe` application and disable the **Export** button. <br> ![Disable export](assets/installation-guide/step1.3-11-disable-export.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

!!! tip "Multiple domains"
    Repeat steps 8-10 above for **every trusted domain** that uses its own private key, selecting the correct domain and fingerprint each time. Save each exported `*.p12` file with a name that clearly identifies the domain it belongs to, so that it can be imported into the correct domain later (see "Step 13 - Initial configuration and domain setup"). Only disable the **Export** button (step 11) once all required files have been downloaded.

### Step 1.4 - Contingency plan / fallback scenario

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

**All domains at once** - if a rollback is required:

1. Stop the new HIN Gateway.
2. Power on the existing MGW.
3. Verify that inbound and outbound email traffic is functioning correctly via the existing MGW, for all domains.

**Staged migration** - if a rollback is required for a domain in the current wave:

1. Keep the existing MGW running - do not stop it.
2. Point the affected domain's Microsoft 365 mail-flow rule back to the MGW.
3. Reverse the connector, transport-rule and header-rule changes made for that domain, in the opposite order in which they were made (see the change protocol from "Step 1.2 - Backing up the existing MGW").
4. Route the affected domain back to the MGW and verify that inbound and outbound traffic for that domain is functioning correctly.
5. Retest both the rolled-back domain and any domains already migrated in earlier waves, to confirm they are unaffected.

### Step 1.5 - Shutdown existing MGW VM

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

**All domains at once:**

Shut down the existing MGW VM.

!!! warning
    This step will interrupt the mail flow. During the interruption, emails will be queued on the mail server and delivered after the installation has been completed (see "Step 18 - Configure mail server").

**Staged migration:**

Do **not** shut down the existing MGW VM. It must remain online, on its existing public IP address (Public IP A), to keep serving all domains that have not yet been migrated. Shut down the MGW only once the final migration wave has passed acceptance (see "Step 21 - Take existing MGW out of service").

### Step 2 - WireGuard

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Ensure you have configured the WireGuard port `19818` (TCP/UDP) in your firewall:

- Incoming and outgoing traffic
- Allow traffic: any-to-HIN Gateway and HIN Gateway-to-any

!!! tip "Staged migration"
    Apply these firewall rules to the HIN Gateway's public IP address (Public IP B). The existing MGW path on its own public IP address (Public IP A) remains active and unaffected while both gateways run in parallel.

### Step 3 - Select target VM

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Select one of the available virtual images and provision it as described in the installation guide on the HIN Gateway service page:

!!! info
    For security and supportability reasons, ensure that your hypervisor is not running an end-of-life version. The HIN Gateway appliance is supported on the latest hypervisor release and the immediately preceding major version.

- VM Image Installation:
    - [Azure VM Image](vm/Azure-image-install.md)
    - [Windows 11 Pro (Hyper-V) Image](vm/Windows11pro-image-install.md)
    - [VMware image](vm/VMware-image-install.md)
    - [Proxmox image](vm/Proxmox-image-install.md)
    - [Cloudscale](vm/Cloudscale-image-install.md)
- [Configuration of Microsoft Exchange](Exchange-integration.md)

### Step 4 - Load VM image

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Upload the selected VM image to your hypervisor.

### Step 5 - Network connection to the VM

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

**All domains at once:** the HIN Gateway can reuse the existing production IP address, but only once the MGW has been stopped (see "Step 1.5 - Shutdown existing MGW VM").

**Staged migration:** configure a separate address for the HIN Gateway VM, together with the firewall/NAT mapping for Public IP B, while the MGW continues to use Public IP A. Follow the same static-IP configuration described below.

Ensure that the VM has a network connection and that a static IP address has been assigned to it.

**Option A:** Configure the IP address of the virtual machine directly in the hypervisor you are using.

**Option B:** You can configure your router's DHCP server to always assign the same IP address based on the VM's MAC address.

**Option C:** Log in locally via the VM console and manually configure a static IP address.
NOTE: The VM image runs an automatic installation during the first boot. If the network is not configured at this stage, the installation will fail because the server’s IP address cannot be determined.

Add an IP address on Linux:

1. Run the "nmtui" command in the console

    ```bash
    nmtui
    ```

2. Use the arrow keys to navigate, then press "Enter" to select the "Ethernet connection" for which you want to change the IP address. <br> ![Add IP Addr](assets/ip_addr_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
3. Navigate to "IPv4 Configuration" and change the setting from "Automatic" to "Manual". <br> ![Add IP Addr](assets/ip_addr_2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
4. Use the arrow keys to navigate to the fields where you can enter the IP address, gateway, and DNS server. Then select "OK". <br> ![Add IP Addr](assets/ip_addr_3.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
5. After saving the IP address configuration, run the following command in the console:

    ```bash
    sudo systemctl restart NetworkManager
    ```

??? warning "Network must be configured before first boot"
    The VM image runs an automatic installation on first boot. If the network is not yet configured (no IP address assigned via DHCP or static config), the installation will fail because the server IP cannot be detected.

    If this happens, configure the network manually, then run:

    ```bash
    cd /root/stargate-deployment/docker-compose
    ./scripts/purge.sh
    # Update configuration with a new ip, by editing it with nano
    # SERVER_STATIC_IP=<NEW IP>
    nano customer-config.sh
    # OR use sed
    # sed -i 's/old IP/new IP/g' customer-config.sh
    ./scripts/install.sh
    ```

    The install script will auto-detect the server's IP from the default route. Any reachable IP (public or private) is sufficient - the actual public endpoint is configured later through the dashboard.

!!! tip
    If you used Option C and configured the network manually, you must run the following commands:

    ```bash
    cd /root/stargate-deployment/docker-compose
    ./scripts/purge.sh
    # Update configuration with a new ip, by editing it with nano
    # SERVER_STATIC_IP=<NEW IP>
    nano customer-config.sh
    # OR use sed
    # sed -i 's/old IP/new IP/g' customer-config.sh
    ./scripts/install.sh
    ```

    The installation script will automatically detect the server’s IP address from the default route. Any reachable IP address, whether public or private, is sufficient. The actual public endpoint is configured later through the dashboard.
    
    After the scripts have completed successfully, proceed to "Step 6 – Access via the browser"
    
    !!! question
        If you do not have the HIN admin credentials, please contact HIN Support by email or phone (**support@hin.ch** / **0848 830 740**). Please refer to [Support Section](./Support.md).

        [Click here to send an Email](mailto:support@hin.ch?subject=Password%20required%20for%20VM%20installation.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20password%20for%20a%20VM%20installation.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Step 6 - Access via the browser

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Open a browser and enter the IP address configured for the VM. You should see the initial setup screen.

```plain
https://<VM IP address>
```

### Step 7 - Enter activation code

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Select your preferred language and enter the activation code that you received via email from HIN. Click on "Next".

![Activation code entry screen](assets/installation-guide/step7-activation-code.png)

!!! question "I do not have an activation code"
    If you do not have the activation code, please contact HIN Support by email or phone (**<support@hin.ch>** / **0848 830 740**). Please refer to [Support Section](./Support.md).

    [Click here to send an Email](mailto:support@hin.ch?subject=Activation%20code%20required.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20activation%20code%20for%20my%20HIN%20Gateway%20installation.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Step 8 - Mesh network setup

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Verify the mesh network configuration:

- **IP address** - The **public IP** of the outgoing traffic (auto-detected).
- **Transport** - The transport protocol (default: `tcp`).
- **Port** - The WireGuard port (default: `19818`).

??? question "What is public IP?"
    This is an IP address that Machine will use to be accessible via internet.
    This is **not** internal Machine IP address after Firewall or NAT, e.g. `10.0.0.0/8`, `172.16.0.0/12` or `192.168.0.0/16`.

!!! tip "Verify the endpoint matches your scenario"
    Confirm that the detected public IP address matches the migration scenario you chose: the reused production endpoint for an all-at-once migration, or **Public IP B** for a staged migration.

Confirm that the values are correct and click "Next".

![Mesh network setup screen](assets/installation-guide/step8-mesh-network.png)

### Step 9 - Establishing secure mesh network

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

The system will now establish the secure mesh network connection. This step connects the HIN Gateway to the Iris Agent and synchronises certificates.

Wait until the process completes. The status indicators will show "Up" when the connection is successfully established. Click "Finish".

![Establishing secure mesh network](assets/installation-guide/step9-mesh-connecting.png)

!!! failure "If the connection fails"
    If the Iris Agent or certificate synchronisation status remains "Down":

    - Verify that port `19818` (TCP/UDP) is open in your firewall (see "Step 2 - WireGuard").
    - Verify that the IP address in "Step 8 - Mesh network setup" is correct and reachable from the internet.
    - Restart the process or contact HIN Support by email or phone (**support@hin.ch** / **0848 830 740**).

### Step 10 - Login to Keycloak

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

!!! warning
    Port `8180` needs to be open for Keycloak. It does not need to be accessible from the internet to the whole world. Rather, it should be accessible between **your administrative machine** and the VM you are installing. Otherwise, you will not be able to connect to Keycloak and proceed with the installation.

    ??? tip "What to do if I see a connection error"
        Please check if port `8180` is open from your machine to the VM. As soon as you update the configuration, go back to the UI at `https://<VM IP address>` and click the "Login" button.

Once the mesh network is established, you will be redirected to the Keycloak login page. Enter the username and password received from HIN.

![Keycloak login page](assets/installation-guide/step10-keycloak-login.png)

!!! question
    If you do not have these login details, please contact HIN Support by email or phone (**<support@hin.ch>** / **0848 830 740**). Please refer to [Support Section](./Support.md).

    [Click here to send an Email](mailto:support@hin.ch?subject=Keycloak%20login%20required.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20Keycloak%20login%20details%20for%20my%20HIN%20Gateway.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Step 11 - Update password

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

On first login, you will be prompted to change your password. Enter a new secure password and confirm it.

![Update password screen](assets/installation-guide/step11-update-password.png)

### Step 12 - Update account information

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Complete your account profile by entering your first name and last name. The email address is pre-filled. Click "Submit" to continue.

![Update account information screen](assets/installation-guide/step12-account-info.png)

### Step 13 - Initial configuration and domain/s setup

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

On this screen, configure your initial settings for **every trusted domain**:

- Verify that all your current trusted domain(s) within the HIN Community are displayed correctly.
- Select which trusted domain(s) should be **Enabled** to obtain peer certificates from the HIN Certification Authority (HIN CA), if not -to import already existing certificates.
- Indicate for which domain(s) the `sec.<domain>` prefix is already configured ("Use sec-prefix").

??? tip "How to check if my domain is set up with a Security Prefix?"
    You can open our online tool in your browser: <https://trust.hin.ls-infra.me/>, enter `sec.<domain>`, and click the **Check** button. If you see the message:

    ✅ This domain is encrypted.

    Then your domain is set up with a Security Prefix, and you have to enable the **Use sec-prefix** option.

- Verify that the organization name and domain owners are correct. <br> ![Screenshot](assets/step_13_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" } <br> ![Screenshot](assets/step_13_2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
- Import the existing S/MIME certificate file (`.p12`/`.pfx`) from the existing MGW, for each domain that has its own certificate:
    1. Expand the domain and select the **P12/PFX File** option.
    2. If no password has been set for the certificate file, leave the password field empty.
    3. Click **"Import Certificate"**.
    4. After the certificate has been imported, the message *Certificate imported successfully* is displayed.
- Click **"Save Configuration"** at the end of the page to save the changes.

![Initial setup screen](assets/installation-guide/step13-initial-setup.png)

!!! warning
    - At least one domain must be **Enabled** to continue with the onboarding process. The "Save configuration" button will only become active once this requirement is met.
    - If you notice that not all trusted domains are displayed or that the organisational information is incorrect, please contact HIN Support by email or phone (**<support@hin.ch>** / **0848 830 740**).

!!! danger "Import your existing private key"
    If you do **not** import the private key from your existing MGW, a new key will be issued. This may result in messages not being decryptable for up to **6 hours**, which could lead to **data loss**.

!!! tip "All at once or staged?"
    - **All domains at once:** prepare and enable all domains together for the planned maintenance window.
    - **Staged migration:** enable only the domains that belong to the **current migration wave**. Keep a record of which domains were enabled in each wave.

![Setup screen](assets/installation-guide/step13-initial-setup2.png)

| Setting | Description |
|---------|-------------|
| **Mail server host name** | The FQDN of this mail gateway instance (e.g. `mail.example.com`). |
| **Mail server IP addresses** | The public IP address(es) of this server. Add additional IPs if the server is reachable on multiple addresses. |
| **DNS** | DNS of the host which will be used to resolve MX and other DNS records |



### Step 14 - Configure mail transport

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

##### Settings page

On this page under `Settings` menu, configure your global mail transport settings for the secure mail relay setup which are common for the whole instance. Detailed configuration for each domain can be performed under `Domains` -> `$domain`

![Mail transport configuration screen](assets/installation-guide/step14-mail-transport2.png)

The following settings are available `Settings` menu:

| Setting | Description |
|---------|-------------|
| **Mail server host name** | The FQDN of this mail gateway instance (e.g. `mail.example.com`). |
| **Mail server IP addresses** | The public IP address(es) of this server. Add additional IPs if the server is reachable on multiple addresses. |
| **DNS** | DNS of the host which will be used to resolve MX and other DNS records |
| **Default inbound relay** | The default SMTP relay for inbound delivery |
| **Default outbound relay** | The default SMTP relay for outbound delivery |


##### Domains page

Under the **Domains** menu, for each available domain you can configure specific transport route:

![Domain transport configuration screen](assets/installation-guide/step14-domain-mail-transport.png)

| Setting | Description |
|---------|-------------|
| **Inbound relay** | The  SMTP relay for inbound delivery for selected domain |
| **Outbound relay** | The SMTP relay for outbound delivery for selected domain. This setting corespond to `Forwarding server` setting from old MGW |
| **Trusted networks** | Additional networks allowed to relay through this gateway. |
| **ARC** | Recommended to keep it as is |
| **Configure TLS** | TLS certificate settings for SMTP connections and from the `Generate TLS certificate` button you can generate TLS certificate|


!!! note
    Ensure that all relay host and domain configurations are correct before proceeding.

!!! tip "Staged migration"
    Configure only the domains that the HIN Gateway is intended to process in the active wave, unless otherwise instructed by HIN. Domains scheduled for a later wave keep using the MGW and do not need a HIN Gateway transport configuration yet.

Once the configuration has been reviewed and completed, click "Save" to continue.

### Step 15 - Configure whitelist headers

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Click **"Domains"**, then select **"Whitelist headers"**.

Enter the key exactly as configured in the mail server, repeating this for every domain that uses a customer-specific header check.

![Screenshot](assets/step_15_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

!!! tip "Staged migration"
    While the MGW and the HIN Gateway run in parallel, verify that header-based rules behave correctly on **both** appliances before moving the next domain to the HIN Gateway.

### Step 16 - Peer certificates

![Responsibility HIN](https://img.shields.io/badge/Responsibility-HIN-orange)

Peer certificates are issued by the HIN Certification Authority (HIN CA) for enabled domains.

Once the onboarding is complete, navigate to the **Peer certificates** section in the dashboard and click the **"Sync certificates"** button to synchronise your peer certificates from the HIN CA. In a staged migration, repeat this synchronisation each time a new wave of domains is enabled.

![Peer certificates screen](assets/installation-guide/step15-peer-certificates.png)

### Step 17 - Validate peer certificates

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Ensure that your domain has received its policy-based peer certificate under **"Domains"**. The status of each domain must be **"Good"**.

![Screenshot](assets/step_17_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

In a staged migration, validate the status for every domain in the current wave and record the result before redirecting that domain's mail flow to the HIN Gateway.

!!! question
    Contact HIN Support by email or phone (**<support@hin.ch>** / **0848 830 740**) if you encounter any issues.

### Step 18 - Configure mail server and HIN Gateway

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

**All domains at once:**

If you followed the recommended approach by exporting the private key, importing it into the HIN Gateway, and keeping the **same IP address** as the existing MGW, no changes are required on the email server, and no temporary Microsoft 365 connectors or split rules are needed.

Otherwise, configure your mail server or the associated components so that traffic is routed via the new HIN Gateway. Check and update the following settings, if required:

- SMTP relay / smart host
- Connectors
- Transport rules
- Routing domains

**Staged migration:**

Keep the MGW running on its existing public IP address (Public IP A). Route the HIN Gateway through the reserved public IP address (Public IP B), then:

1. Create two connectors in Exchange Online - one **Inbound** and one **Outbound** - pointing to the HIN Gateway.
2. Add a Microsoft 365 mail-flow rule that routes by domain: the domain(s) in the current wave go to the HIN Gateway, all remaining domains stay on the MGW.
3. Record the rule priority and all header-related changes in your change protocol (see "Step 1.2 - Backing up the existing MGW").
4. Repeat gradually - move one additional domain (or wave) at a time until every domain is on the HIN Gateway.

!!! warning "Customer-specific headers"
    Some domains rely on custom X-headers (routing, anti-spam allow-lists, compliance tags). Confirm that the HIN Gateway's connectors preserve or replicate these headers before cutting a domain over - missing headers can cause mis-routing or rejected mail.

See [Exchange Integration](Exchange-integration.md) for detailed instructions.

#### HIN Gateway config

- Go to the `Settings` page and, for each domain, add a **Relay host** using the value you recorded from the MGW's `Forwarding server` field in "Step 1.2 - Backing up the existing MGW".
  <br> ![domain-relay-host](assets/installation-guide/step18-add-domain-relay.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

- On the same `Settings` page, set the **Default relay host**.
- If you are using Microsoft 365 / Exchange Online, add its published outbound IP ranges to **`Settings` → `Trusted networks`** so the HIN Gateway trusts and relays mail coming from Exchange Online:

    ```text
    40.92.0.0/15
    40.107.0.0/16
    51.4.72.0/24
    51.4.80.0/27
    51.5.72.0/24
    51.5.80.0/27
    52.100.0.0/14
    104.47.0.0/17
    2a01:111:f400::/48
    2a01:111:f403::/48
    2a01:4180:4050:400::/64
    2a01:4180:4050:800::/64
    2a01:4180:4051:400::/64
    2a01:4180:4051:800::/64
    ```

  <br> ![domain-relay-host](assets/installation-guide/step18-add-default-relay-and-network.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Step 19 - Test prior to switchover

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Repeat the "Step 1.1 - Smoke test" for every domain in the current migration wave. In addition to the smoke test, please test and confirm the following, for each domain:

**Outgoing:**

- Verify that the mail server is configured to send emails to the HIN Gateway using an SMTP relay or Exchange connector.
- Verify that the HIN Gateway can send emails to recipients outside the HIN Community.
- Verify that the HIN Gateway can send emails to recipients inside the HIN Community via WireGuard.

**Incoming:**

- Verify that encrypted emails can be received from the HIN Community via WireGuard. A sender from the `hin.ch` domain is the easiest test path.
- Verify that encrypted emails can be received from the HIN Community via SMTP using S/MIME.
- Verify that replies from senders outside the HIN Community to an initial secure email (HIN Mail-SEAL) can reach the HIN Gateway.
- Verify that plain-text emails can be received from external senders outside the HIN Community.

**Staged migration only:**

Also test at least one domain that has **not** been migrated in the current wave, and confirm that it is still routed through the MGW.

### Step 20 - Validation after switchover

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Confirm, for every domain in the current migration wave:

- Emails delivered
- Encryption applied
- No delays or bounces
- Logging successful

**Staged migration:** also verify the routing split on both appliances after each wave - domains in the current wave use the HIN Gateway, remaining domains still use the MGW. Complete the [**Acceptance Report**](https://www.hin.ch/files/pdf1/gateway-acceptance-en.pdf) only once **every domain has been migrated and validated**, and return it to your HIN representative.

**All domains at once:** complete the [**Acceptance Report**](https://www.hin.ch/files/pdf1/gateway-acceptance-en.pdf) once all domains have been validated, and return it to your HIN representative.

### Step 21 - Take existing MGW out of service

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

!!! warning
    Do not delete or decommission the existing MGW VM while **any domain** still uses it. In a staged migration, wait until the final wave has passed acceptance (see "Step 20 - Validation after switchover") before proceeding with this step.

1. **Ensure there is no active traffic** - check:
    - No domains are pointing to the MGW (DNS, SMTP, connectors, transport rules, header rules).
    - No emails are being forwarded via the old appliance.
2. **Archive logs** - export and save:
    - Email logs
    - Security/audit logs
    - Required for compliance and troubleshooting
3. **Clean-up (optional)** - remove:
    - Firewall rules
    - DNS entries
    - Routing configurations that reference the existing MGW

### Step 22 - Change the password of the VM

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Please make sure that the VM credentials which were provided to you initially are changed to your own defined password, and keep them in a secured and safe place.

Keep the retained MGW credentials available until final acceptance, in case a rollback is still required.

## Annex 1 - Backing up and restoring the appliance settings

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

To back up or restore the settings of your HIN appliance, click the **"Administration"** menu in the web administration portal.

![Screenshot](assets/annex_1_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Backing up settings

Before you create a backup of the current HIN appliance settings, you must set a backup password. This password is required if you need to restore the backup later.

- To set or change the backup password, click **"Change Password"**.
- To create and download a backup file, click **"Download"**.

### Changing the backup password

To change the password for future backups, click **"Change Password"**.

!!! note
    The new password only applies to backups created **after** the password has been changed. Existing backup files remain protected by the password that was set when they were created.

### Restoring settings

To restore appliance settings from a backup file, click **"Import Backup File..."**.

In the dialog window, select the required backup file and enter the password associated with that backup. The appliance settings will then be restored from the selected backup file.

### Backup using SCP

The MGW supports backing up the appliance via SCP.

To use this option, the public key of the system that will access the MGW must be stored under **"Backup using SCP"**. The backup is generated automatically every day at midnight and is stored on the MGW as `backup.tgz`.

Using the configured public key, the backup file can be retrieved via SCP with the operating system user `backup`. A typical SCP command to retrieve the backup file is:

```bash
scp backup@192.168.1.60:/backup.tgz .
```

This command downloads the file `backup.tgz` from the MGW to the current local directory.

!!! note
    If you enter a new public key, the existing key will be replaced.

!!! note "Staged migration"
    A staged migration also relies on the external change protocol described in "Step 1.2 - Backing up the existing MGW", and on backups or exports of the Microsoft 365 connectors, transport rules and header rules, as well as the MGW configuration. These items are **not** included in the HIN Gateway appliance backup described above.
