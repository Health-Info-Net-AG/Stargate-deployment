# Stargate Bereitstellungsanleitung

--8<-- "docs/assets/Translation_notice.md"

![Logo](assets/stargate_visual.png)

[Was ist Stargate?](https://www.hin.ch/de/services/hin-mail/hin-gateway.cfm){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Schnellstart

### Installationsoptionen

* VM-Image-Installation:
    * [Azure VM-Image-Installation](vm/Azure-image-install.md)
    * [Windows 11 Pro (Hyper-V) Image-Installation](vm/Windows11pro-image-install.md)
    * [VMware-Image-Installation](vm/VMware-image-install.md)
    * [Proxmox-Image-Installation](vm/Proxmox-image-install.md)
    * [Cloudscale.ch Image-Installation](vm/Cloudscale-image-install.md)

!!! tip "🖨️"
    Sie können diese Dokumentation ausdrucken oder als PDF speichern. Besuchen Sie unsere [Druckseitenansicht](print_page).

### Exchange-Integration

* [Exchange-Integration](Exchange-integration.md) – Konfigurieren Sie Microsoft Exchange (Online und On-Premises)-Connectors und Transportregeln, um E-Mails über Stargate zu leiten

### Server-Anforderungen

|      | Minimum | Empfohlen |
| :--- | :-----: | :---------: |
| CPU, Kerne | 4 | 6 |
| RAM, GB | 8 | 12 |
| SSD, GB | 60 | 60 |

#### Allgemeine Anforderungen

* **Root-Zugriff**: Muss als Root oder mit `sudo` ausgeführt werden
* Unterstützte Distributionen:
    * RHEL 8, 9 und 10 kompatible Distributionen wie Alma Linux, Rocky Linux, CentOS Stream
    * Ubuntu 22 und 24
    * Debian 11, 12 und 13
* **Reale IPv4-Adresse**
* **Gültige DNS-Einträge**. Ihre Domain muss Folgendes haben:
    * MX-Einträge, die auf Ihre Mailserver verweisen
    * SPF-Eintrag, der die erlaubten sendenden Netzwerke definiert
    * Der Server muss in der Lage sein, DNS aufzulösen (MX, SPF, A-Einträge)
    * Wird für das Mail-Routing und die SPF-basierte Netzwerk-Allowlist verwendet

#### Eingehender Netzwerkzugriff (Firewall muss erlauben)

| Port | Protokoll | Zweck |
| :--- | :-------: | :---- |
| `25` | TCP | SMTP – Empfangen von E-Mails von externen Servern |
| `19818` | UDP+TCP | WireGuard – Verschlüsselter Tunnel für die Agent-zu-Agent-Kommunikation. Lesen Sie unser [Sicherheitsgutachten zu WireGuard](https://www.hin.ch/files/pdf1/wireguard-tunnel-en.pdf) |

#### Eingehender VM-Zugriff (von Ihrem Administrationsrechner zur HIN Gateway VM)

!!! info
    Diese Firewall-Regeln sollten nur zwischen Ihrem Administrationsrechner und der HIN Gateway VM angewendet werden. Es ist nicht erforderlich, diese Ports für das Internet freizugeben.

| Port | Protokoll | Zweck |
| :--- | :-------: | :---- |
| `80` | TCP | Leitet HTTP-Datenverkehr auf HTTPS um |
| `443` | TCP | Dient zur Verwaltung des HIN Gateway über das Web-Dashboard |
| `8180` | TCP | Wird von Keycloak zur Authentifizierung von Benutzern für das HIN Gateway Dashboard verwendet |
| `8190` | TCP | Optional. Erforderlich für die Fehlerbehebung und das Anzeigen von Protokollen |
| `22` | TCP | Optional. Erforderlich für die Fehlerbehebung und das Ändern der Konfiguration |

#### Ausgehender Netzwerkzugriff (Server muss erreichen können)

| Ziel | Port | Protokoll | Zweck |
| :--- | :--: | :-------: | :---- |
| hub.docker.com | `443` | TCP | Docker-Image-Registry |
| mxengine-dev.k8s.vereign-cdn.com | `443` | TCP | Entfernter Sealer-Dienst |
| smimekeys-ca-dev.k8s.vereign-cdn.com | `443` | TCP | S/MIME-CA-Dienst |
| loki.example.com | `443` | TCP | Log-Versand (Alloy → Loki, optional) |
| Update-Server von Alpine, AlmaLinux usw. | `80` | TCP | Verschiedene Update-Server |
| Ziel-Mailserver | `25` | TCP | Zustellung ausgehender E-Mails (via MX-Lookup) |
| DNS-Server | `53` | UDP+TCP | Ausgehend an öffentliche DNS-Server |
| NTP-Server | `123` | UDP | NTP synchronisiert die Uhren von Computern, Servern, Netzwerkgeräten und virtuellen Maschinen mit präzisen Zeitquellen |
| WireGuard-Peers (HIN-Netzwerk) | `19818` | UDP+TCP | WireGuard – Verschlüsselter Tunnel für die Agent-zu-Agent-Kommunikation |
| `witness-{1,2,3}.verify-mail.hin-infra.ch` | `443` | TCP | HIN KERI-Witness-Pool - erforderlich für die Verifizierung von Agent-Identitäten (idagent / watcher) |
| `app.hin.ch` | `443` | TCP | HIN Mitglieder- / Maildomain-Liste (mtaconf) |

??? tip "Firewall-Hinweis"

    Abhängig von Ihrer Firewall- oder NAT-Konfiguration müssen Sie den Datenverkehr für die erforderlichen Ports möglicherweise explizit zulassen. Weitere Informationen finden Sie in der Dokumentation Ihrer Firewall bzw. NAT-Konfiguration.

    Die VM muss **eingehende** Verbindungen auf den erforderlichen Dienstports **akzeptieren** und **Antworten zurück** an den Anfragenden senden können. Bei einer zustandsbehafteten Firewall (z. B. `iptables` mit `conntrack`) wird der Rückverkehr durch die `ESTABLISHED,RELATED`-Regeln automatisch zugelassen.

    Beispiel für eine `iptables`-Konfiguration:

    ```bash
    # Rückverkehr für bestehende Verbindungen zulassen
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Eingehende TCP-Verbindungen zu den offenen Ports zulassen
    iptables -A INPUT -p tcp -m multiport --dports 25,19818 -j ACCEPT

    # Ausgehende TCP-Verbindungen zu den offenen Ports zulassen
    iptables -A OUTPUT -p tcp -m multiport --dports 25,19818 -j ACCEPT

    # Eingehenden UDP-Port 19818 für WireGuard zulassen
    iptables -A INPUT -p udp --dport 19818 -j ACCEPT

    # Ausgehenden UDP-Port 19818 für WireGuard zulassen
    iptables -A OUTPUT -p udp --dport 19818 -j ACCEPT

    # Zusätzliche Dienste, die von der VM erreichbar sein müssen
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

## Kontaktieren Sie uns

!!! tip "Support"

    Bei Fragen oder Problemen im Zusammenhang mit der Bereitstellung und dem Betrieb der HIN Mail (Stargate)-Appliance wenden Sie sich bitte an den HIN-Support.

    Bitte fügen Sie relevante Informationen wie den Kundennamen, die Appliance-Version und Screenshots/[Logs](./Docker-advanced.md#logs-an-den-support-senden) hinzu, um die Bearbeitung Ihres Anliegens zu beschleunigen.

---

[![documentation](https://img.shields.io/github/check-runs/Health-Info-Net-AG/Stargate-deployment/main?nameFilter=Build%20documentation&style=for-the-badge&label=Documentation%20Build)](https://github.com/Health-Info-Net-AG/Stargate-deployment/actions/workflows/documentation.yml)
[![commit](https://img.shields.io/endpoint?style=for-the-badge&url=https://health-info-net-ag.github.io/Stargate-deployment/badges/build.json)](https://github.com/Health-Info-Net-AG/Stargate-deployment)
