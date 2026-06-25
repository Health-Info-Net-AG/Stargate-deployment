# Stargate Deployment Instruction


![Logo](assets/stargate_visual.png)

[What is Stargate?](https://www.hin.ch/de/services/hin-mail/hin-gateway.cfm){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Quick Start

### Installation options

* VM image installation:
    * [Azure VM image installation](vm/Azure-image-install.md)
    * [Windows 11 Pro (Hyper-V) image installation](vm/Windows11pro-image-install.md)
    * [VMware image installation](vm/VMware-image-install.md)
    * [Proxmox image installation](vm/Proxmox-image-install.md)
    * [Cloudscale.ch](vm/Cloudscale-image-install.md)

!!! tip "🖨️"
    You can get this documentation printed or saved as PDF, please visit our [Print page view](print_page).

### Exchange Integration

* [Exchange integration](Exchange-integration.md) - Configure Microsoft Exchange (Online and On-Premises) connectors and transport rules to route mail through Stargate

### Server Requirements

|      | Minimum | Recommended |
| :--- | :-----: | :---------: |
| CPU, Cores| 4 | 6 |
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

| Port | Protocol | Purpose |
|------|----------|---------|
| `25` | TCP | SMTP - receiving mail from external servers |
| `8084` | TCP | HTTP - seal callback from remote sealer service |
| `19818` | UDP+TCP | WireGuard - encrypted tunnel for agent-to-agent communication. Read our [Security Assessment WireGuard](https://www.hin.ch/files/pdf1/wireguard-tunnel-en.pdf) |

#### Outbound Network Access (server must reach)

| Destination | Port | Purpose |
|-------------|------|---------|
| hub.docker.com | `443`| Docker image registry |
| mxengine-dev.k8s.vereign-cdn.com | `443`| Remote sealer service |
| smimekeys-ca-dev.k8s.vereign-cdn.com | `443`| S/MIME CA service |
| loki.example.com | `443`| Log shipping (Alloy → Loki, optional) |
| Destination mail servers | `25` | Outbound mail delivery (via MX lookup) |

## Contact us

!!! tip "Support"

    For any questions or issues related to the deployment and operation of the HIN Mail (Stargate) appliance, please contact HIN support.

    Please include relevant information such as the customer name, appliance version, and screenshots/[logs](./Docker-advanced.md#provide-logs-to-support) where applicable, to help us process your request efficiently.

---

[![documentation](https://img.shields.io/github/check-runs/Health-Info-Net-AG/Stargate-deployment/main?nameFilter=Build%20documentation&style=for-the-badge&label=Documentation%20Build)](https://github.com/Health-Info-Net-AG/Stargate-deployment/actions/workflows/documentation.yml)
[![commit](https://img.shields.io/endpoint?style=for-the-badge&url=https://health-info-net-ag.github.io/Stargate-deployment/badges/build.json)](https://github.com/Health-Info-Net-AG/Stargate-deployment)
