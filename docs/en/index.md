# Stargate Deployment Information

**(DE) Hinweis zu Übersetzungen**
Für verlässliche Informationen nutzen Sie bitte die offiziellen Übersetzungen über den Sprachschalter ![web-icon](assets/web-icon.png){ width="16" } . Automatische Browser-Übersetzungen können Inhalte verfälschen.
{: style="font-size: 0.85em;" }

**(FR) Remarque concernant les traductions**
Pour obtenir des informations fiables, veuillez utiliser les traductions officielles accessibles via le sélecteur de langue ![web-icon](assets/web-icon.png){ width="16" } . Les traductions automatiques du navigateur peuvent déformer le contenu.
{: style="font-size: 0.85em;" }

**(IT) Avvertenza sulle traduzioni**
Per informazioni affidabili, utilizzare le traduzioni ufficiali accessibili tramite il selettore della lingua ![web-icon](assets/web-icon.png){ width="16" } . Le traduzioni automatiche del browser possono alterare i contenuti.
{: style="font-size: 0.85em;" }

**(EN) Translation notice**
For reliable information, please use the official translations available via the language selector ![web-icon](assets/web-icon.png){ width="16" } . Automatic browser translations may distort the content.
{: style="font-size: 0.85em;" }

![Logo](assets/stargate_visual.png)

[What is Stargate?](https://www.hin.ch/de/services/hin-mail/hin-gateway.cfm){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Pre-Requisites

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Please ensure that all necessary preparatory steps have been completed before the HIN Gateway migration or new installation activities begin.

The following items must be available or confirmed before the installation:

- **Credentials will be delivered to you by HIN**
    - VM credential
    - Keycloak credential
    - Activation code

- **Export of private key**
!!! info
    Export of private keys is only for customers moving from existing MGW to a new HIN Gateway

    - If you are working on a Windows machine that has access to the Mail Gateway VM via port 22, we can support you during the call in enabling the private key export from the MGW.
    - If you do not have access to such a machine, please contact HIN Support by email or phone (support@hin.ch / 0848 830 740) to help you establish a support connection via System Administration → Support Connection → Connect.
- **Download latest** version of [VM image](vm/VM-Catalog.md)
- **Firewall** requirements for WireGuard.
  Configure the WireGuard port 19818 (TCP/UDP) in your firewall:
    - Incoming and outgoing traffic
    - Allow traffic: any-to-HIN Gateway and HIN Gateway-to-any
- **DHCP access** should be available. For more information see "Installation Guidelines".

- **Backup requirements** - see "Annex 1 - Backing up and restoring the appliance settings".
!!! info
    Backup requirements is only for customers moving from existing MGW to a new HIN Gateway

- Confirmation that the existing MGW will **not** be deleted until acceptance has been completed.
!!! info
    Keeping the existing MGW available till acceptance report have been completed is only for customers moving from existing MGW to a new HIN Gateway

- Access to DNS, mail server connectors, transport rules, and relay settings.

## Deployment Information

### Installation Options

* VM image installation:
    * [Azure VM image installation](vm/Azure-image-install.md)
    * [Windows 11 Pro (Hyper-V) image installation](vm/Windows11pro-image-install.md)
    * [VMware image installation](vm/VMware-image-install.md)
    * [Proxmox image installation](vm/Proxmox-image-install.md)
    * [Cloudscale.ch image installation](vm/Cloudscale-image-install.md)

!!! tip "🖨️"
    You can get this documentation printed or saved as PDF, please visit our [Print page view](print_page).

### Exchange Integration

* [Exchange integration](Exchange-integration.md) - Configure Microsoft Exchange (Online and On-Premises) connectors and transport rules to route mail through Stargate

### Server Requirements

|      | Minimum | Recommended |
| :--- | :-----: | :---------: |
| CPU, Cores | 4 | 6 |
| RAM, GB | 8 | 12 |
| SSD, GB | 60 | 60 |

#### Common Requirements

* **Root access**: Must be run as root or with `sudo`
* Supported distributions:
    * RHEL 8, 9 and 10 compatible distributions such as Alma Linux, Rocky Linux, CentOS Stream
    * Ubuntu 22 and 24
    * Debian 11, 12 and 13
* **Real IPv4 address**
* **Valid DNS records**. Your domain must have:
    * MX records pointing to your mail servers
    * SPF record defining allowed sending networks
    * Server must be able to resolve DNS (MX, SPF, A records)
    * Used for mail routing and SPF-based network allowlisting

#### Inbound Network Access (firewall must allow)

??? tip "Firewall note"

    Depending on your firewall or NAT configuration, you may need to explicitly allow traffic for the required ports. Refer to your firewall and NAT documentation for details.

    The VM must be able to **accept incoming** connections on the required service ports and **send responses back** to the requester. With a stateful firewall (such as `iptables` using `conntrack`), return traffic is automatically allowed by the `ESTABLISHED,RELATED` rules.

    Example `iptables` configuration:

    ```bash
    # Allow return traffic for established connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Allow inbound TCP connections to the open ports
    iptables -A INPUT -p tcp -m multiport --dports 25,8084,19818 -j ACCEPT

    # Allow outbound TCP connections to the open ports
    iptables -A OUTPUT -p tcp -m multiport --dports 25,8084,19818 -j ACCEPT

    # Allow inbound UDP port 19818 for Wireguard
    iptables -A INPUT -p udp --dport 19818 -j ACCEPT

    # Allow outbound UDP port 19818 for Wireguard
    iptables -A OUTPUT -p udp --dport 19818 -j ACCEPT

    # Additional Services that VM shall be able to reach
    # DNS
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

    # NTP
    iptables -A OUTPUT -p udp --dport 123 -j ACCEPT

    # HTTP
    iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT

    # HTTPS
    iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
    ```

| Port | Protocol | Purpose |
| :--- | :------: | :------ |
| `25` | TCP | SMTP - receiving mail from external servers |
| `8084` | TCP | HTTP - seal callback from remote sealer service |
| `19818` | UDP+TCP | WireGuard - encrypted tunnel for agent-to-agent communication. Read our [Security Assessment WireGuard](https://www.hin.ch/files/pdf1/wireguard-tunnel-en.pdf) |

#### Inbound VM Access (your administrative machine to the HIN Gateway VM)

!!! info
    These firewall rules should be applied only between your administrative machine and the HIN Gateway VM. There is no need to expose these ports to the Internet.

| Port | Protocol | Purpose |
| :--- | :------: | :------ |
| `80` | TCP | Redirects HTTP traffic to HTTPS |
| `443` | TCP | Used to manage the HIN Gateway through the web dashboard |
| `8180` | TCP | Used by Keycloak to authenticate users for the HIN Gateway dashboard |
| `8190` | TCP | Optional. Required for troubleshooting and viewing logs |
| `22` | TCP | Optional. Required for troubleshooting and modifying configuration |

#### Outbound Network Access (server must reach)

| Destination | Port | Protocol | Purpose |
| :---------- | :--: | :------: | :------ |
| hub.docker.com | `443` | TCP | Docker image registry |
| mxengine-dev.k8s.vereign-cdn.com | `443` | TCP | Remote sealer service |
| smimekeys-ca-dev.k8s.vereign-cdn.com | `443` | TCP | S/MIME CA service |
| loki.example.com | `443` | TCP | Log shipping (Alloy → Loki, optional) |
| Update Server of alpine, almalinux, etc. | `80` | TCP | Various Update servers |
| Destination mail servers | `25` | TCP | Outbound mail delivery (via MX lookup) |
| Standard DNS queries and responses | `53` | UDP + TCP | DNS resolve |
| `ntp.metas.ch` (default NTP server) | `123` | UDP | NTP synchronizes the clocks of computers, servers, network devices, and virtual machines with accurate time sources |
| `witness-1.verify-mail.hin-infra.ch`, `witness-2...`, `witness-3...` | `443` | TCP | KERI witness pool. The appliance contacts these the first time it starts and will not finish starting without them |

!!! note "Using your own NTP server"

    The appliance is preconfigured to use `ntp.metas.ch` (Swiss Federal Institute of Metrology).
    If your network does not permit outbound NTP, configure your own time server instead of
    opening port `123` to the internet - an internal server is fully supported.

    To set your own, create the file below on the appliance and reload. List as many
    servers as you need, one per line:

    ```bash
    sudo tee /var/data/vereign/chrony/ntp.sources <<'EOF'
    pool ntp1.example.local iburst
    pool ntp2.example.local iburst
    EOF
    sudo chronyc reload sources
    chronyc sources -v
    ```

    The file must be named exactly `ntp.sources`. With that name your list replaces the
    default; under any other name it is added to the default instead. Delete the file and
    reload to go back to `ntp.metas.ch`.

    Accurate time is not optional. If the clock drifts, certificate validation, message
    signing and sign-in sessions all begin to fail in ways that are hard to diagnose.

## Contact us

!!! tip "Support"

    For any questions or issues related to the deployment and operation of the HIN Mail (Stargate) appliance, please contact HIN support.

    Please include relevant information such as the customer name, appliance version, and screenshots/[logs](./Docker-advanced.md#provide-logs-to-support) where applicable, to help us process your request efficiently.

---

[![documentation](https://img.shields.io/github/check-runs/Health-Info-Net-AG/Stargate-deployment/main?nameFilter=Build%20documentation&style=for-the-badge&label=Documentation%20Build)](https://github.com/Health-Info-Net-AG/Stargate-deployment/actions/workflows/documentation.yml)
[![commit](https://img.shields.io/endpoint?style=for-the-badge&url=https://health-info-net-ag.github.io/Stargate-deployment/badges/build.json)](https://github.com/Health-Info-Net-AG/Stargate-deployment)
