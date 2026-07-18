# Quick Start

!!! tip
    This is a condensed, checklist-style version of the installation and migration process for **single-domain Microsoft 365 mail architectures**. It is meant for administrators who already understand the process (e.g. repeat installs) and just need a fast reference.

    For full explanations, screenshots and troubleshooting, see the [**Full Installation Guide**](Installation-guide.md).

## Checklist

Use this list to track your progress. Each item links to the detailed instructions in the full guide.

- [ ] [Step 0 - Check prerequisites](Installation-guide.md#step-0-check-prerequisites) — Customer
- [ ] [Step 1.1 - Smoke test](Installation-guide.md#step-11-smoke-test) — Customer
- [ ] [Step 1.2 - Backing up the existing MGW](Installation-guide.md#step-12-backing-up-the-existing-mgw) — Customer
- [ ] [Step 1.3 - Export private key(s)](Installation-guide.md#step-13-export-private-keys) — Customer / HIN
- [ ] [Step 1.4 - Contingency plan / fallback scenario](Installation-guide.md#step-14-contingency-plan-fallback-scenario) — Customer
- [ ] [Step 1.5 - Shutdown existing MGW VM](Installation-guide.md#step-15-shutdown-existing-mgw-vm) — Customer
- [ ] [Step 2 - WireGuard](Installation-guide.md#step-2-wireguard) — Customer
- [ ] [Step 3 - Select target VM](Installation-guide.md#step-3-select-target-vm) — Customer
- [ ] [Step 4 - Load VM image](Installation-guide.md#step-4-load-vm-image) — Customer
- [ ] [Step 5 - Network connection to the VM](Installation-guide.md#step-5-network-connection-to-the-vm) — Customer
- [ ] [Step 6 - Access via the browser](Installation-guide.md#step-6-access-via-the-browser) — Customer
- [ ] [Step 7 - Enter activation code](Installation-guide.md#step-7-enter-activation-code) — Customer
- [ ] [Step 8 - Mesh network setup](Installation-guide.md#step-8-mesh-network-setup) — Customer
- [ ] [Step 9 - Establishing secure mesh network](Installation-guide.md#step-9-establishing-secure-mesh-network) — Customer
- [ ] [Step 10 - Login to Keycloak](Installation-guide.md#step-10-login-to-keycloak) — Customer
- [ ] [Step 11 - Update password](Installation-guide.md#step-11-update-password) — Customer
- [ ] [Step 12 - Update account information](Installation-guide.md#step-12-update-account-information) — Customer
- [ ] [Step 13 - Initial configuration and domain setup](Installation-guide.md#step-13-initial-configuration-and-domain-setup) — Customer
- [ ] [Step 14 - Configure mail transport](Installation-guide.md#step-14-configure-mail-transport) — Customer
- [ ] [Step 15 - Configure whitelist headers](Installation-guide.md#step-15-configure-whitelist-headers) — Customer
- [ ] [Step 16 - Peer certificates](Installation-guide.md#step-16-peer-certificates) — HIN
- [ ] [Step 17 - Validate peer certificates](Installation-guide.md#step-17-validate-peer-certificates) — Customer
- [ ] [Step 18 - Configure mail server and HIN Gateway](Installation-guide.md#step-18-configure-mail-server-and-hin-gateway) — Customer
- [ ] [Step 19 - Test prior to switchover](Installation-guide.md#step-19-test-prior-to-switchover) — Customer
- [ ] [Step 20 - Validation after switchover](Installation-guide.md#step-20-validation-after-switchover) — Customer
- [ ] [Step 21 - Take existing MGW out of service](Installation-guide.md#step-21-take-existing-mgw-out-of-service) — Customer
- [ ] [Step 22 - Change the password of the VM](Installation-guide.md#step-22-change-the-password-of-the-vm) — Customer
- [ ] [Annex 1 - Backing up and restoring the appliance settings](Installation-guide.md#annex-1-backing-up-and-restoring-the-appliance-settings) — Customer

!!! warning
    Between **Step 1.5** and **Step 18**, all mail is queued on the mail server — no messages are lost. Also, **Step 1.3** requires an unlock code from HIN Support and cannot be completed alone.

## Before you start

- **Credentials from HIN**: VM credential, Keycloak credential, activation code.
- **Latest VM image**: download from the [VM Catalog](vm/VM-Catalog.md).
- **Firewall ports open**: see table below.
- **DHCP** available for the new VM (recommended).
- **Backup** of the existing MGW taken (see Annex 1).
- **Access** to DNS, mail server connectors, transport rules and relay settings.
- Confirm the existing MGW will **not** be deleted until acceptance is complete.

### Required ports

| Source | Destination | Port | Protocol | Description |
| :----- | :----------- | :--- | :------: | :----------- |
| Any | HIN Gateway | `25` | TCP | SMTP - receiving mail from external servers |
| Any HIN Gateway | HIN Gateway | `19818` | TCP+UDP | WireGuard - peer certificates and secure tunnel between gateways |
| HIN Gateway | Any HIN Gateway | `19818` | TCP+UDP | WireGuard - peer certificates and secure tunnel between gateways |
| Remote sealer service | HIN Gateway | `8084` | TCP | Seal callback from remote sealer service |
| Admin machine | HIN Gateway VM | `443` | TCP | Web dashboard |
| Admin machine | HIN Gateway VM | `8180` | TCP | Keycloak login |
| Admin machine | HIN Gateway VM | `80` | TCP | Redirects HTTP to HTTPS |
| Admin machine | HIN Gateway VM | `22` | TCP | SSH (optional - troubleshooting) |
| Admin machine | HIN Gateway VM | `8190` | TCP | Dozzle logs (optional - troubleshooting) |
| HIN Gateway | hub.docker.com | `443` | TCP | Docker image registry |
| HIN Gateway | mxengine-dev.k8s.vereign-cdn.com | `443` | TCP | Remote sealer service |
| HIN Gateway | smimekeys-ca-dev.k8s.vereign-cdn.com | `443` | TCP | S/MIME CA service |
| HIN Gateway | loki.example.com | `443` | TCP | Log shipping (optional) |
| HIN Gateway | OS update servers (alpine, almalinux, etc.) | `80` | TCP | Package updates |
| HIN Gateway | Destination mail servers | `25` | TCP | Outbound mail delivery |
| HIN Gateway | DNS servers | `53` | TCP+UDP | DNS resolution |
| HIN Gateway | NTP servers | `123` | UDP | Time synchronization |

## Installation flow

### 1. Prepare and fall back

* Smoke test the existing MGW
* Back it up
* export MGW private key (with HIN's unlock code)
* shut down the existing MGW(do not delete the VM yet)
* open the mandatory network ports

### 2. Deploy the HIN Gateway VM

Make sure Wireguard port is open, pick and load a VM image for your hypervisor, and give the VM a static IP - the same as existing MGW before its first boot 

### 3. Initial setup wizard

Browse to the VM's IP after the VM image is loaded, enter the activation code, confirm the mesh network settings and wait for it to connect, then log in to Dashboard ( via Keycloak credentials provided by HIN) and set a new password and account details

### 4. Configure domains and certificates

Enable your trusted domain(s), import the existing S/MIME private key exported from old MGW. Skipping this it will generate new SMIME keys and may causes up to 6 hours of undecryptable mail. Configure mail transport and whitelist headers

### 5. Cut over mail flow

Point your mail server / Exchange connectors at the HIN Gateway (if you used the same IP address as old MGW, then there will be no need to change anything on email server side), add relay hosts and trusted networks, then perform a smoke test and submit the Acceptance Report to HIN.

### 6. Decommission

Confirm no traffic still points at the old MGW, then clean up and change the HIN Gateway VM's default password.

## Need more detail?

This page only summarizes the process. For step-by-step instructions, screenshots, and troubleshooting for every step above, see the [**Full Installation Guide**](Installation-guide.md).

If you get stuck, contact HIN Support by email or phone (**support@hin.ch** / **0848 830 740**), or see the [Support](Support.md) page.
