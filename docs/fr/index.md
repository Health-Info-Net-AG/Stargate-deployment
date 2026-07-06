# Instruction de déploiement Stargate

![Logo](assets/stargate_visual.png)

[Qu'est-ce que Stargate ?](https://www.hin.ch/de/services/hin-mail/hin-gateway.cfm){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Démarrage rapide

### Options d'installation

* Installation par image VM:
    * [Installation par image VM Azure](vm/Azure-image-install.md)
    * [Installation par image VM Windows 11 Pro (Hyper-V)](vm/Windows11pro-image-install.md)
    * [Installation par image VM VMware](vm/VMware-image-install.md)
    * [Installation par image VM Proxmox](vm/Proxmox-image-install.md)
    * [Installation par image VM Cloudscale.ch](vm/Cloudscale-image-install.md)

!!! tip "🖨️"
    Vous pouvez obtenir cette documentation imprimée ou sauvegardée en PDF, veuillez visiter notre [Page d'impression](print_page).

### Intégration Exchange

* [Intégration Exchange](Exchange-integration.md) - Configurez les connecteurs Microsoft Exchange (Online et On-Premises) et les règles de transport pour acheminer les courriels via Stargate

### Exigences du serveur

|      | Minimum | Recommandé |
| :--- | :-----: | :--------: |
| CPU, Cœurs | 4 | 6 |
| RAM, GB | 8 | 12 |
| SSD, GB | 60 | 60 |

#### Exigences communes

* **Accès root**: Doit être exécuté en tant que root ou avec `sudo`
* Distributions prises en charge:
    * Distributions compatibles RHEL 8, 9 et 10 telles que Alma Linux, Rocky Linux, CentOS Stream
    * Ubuntu 22 et 24
    * Debian 11, 12 et 13
* **Adresse IPv4 réelle**
* **Enregistrements DNS valides**. Votre domaine doit avoir:
    * Des enregistrements MX pointant vers vos serveurs de courrier
    * Un enregistrement SPF définissant les réseaux d'envoi autorisés
    * Le serveur doit être capable de résoudre le DNS (enregistrements MX, SPF, A)
    * Utilisé pour le routage du courrier et la liste d'autorisation réseau basée sur SPF

#### Accès réseau entrant (le pare-feu doit autoriser)

| Port | Protocole | Objectif |
| :--- | :-------: | :------- |
| `25` | TCP | SMTP - réception des courriels des serveurs externes |
| `8084` | TCP | HTTP - rappel de scellement du service de scellement distant |
| `19818` | UDP+TCP | WireGuard - tunnel crypté pour la communication agent-à-agent. Lisez notre [Évaluation de sécurité WireGuard](https://www.hin.ch/files/pdf1/wireguard-tunnel-en.pdf) |

#### Accès réseau sortant (le serveur doit atteindre)

| Destination | Port | Protocole | Objectif |
| :---------- | :--: | :-------: | :------- |
| hub.docker.com | `443` | TCP | Registre d'images Docker |
| mxengine-dev.k8s.vereign-cdn.com | `443` | TCP | Service de scellement distant |
| smimekeys-ca-dev.k8s.vereign-cdn.com | `443` | TCP | Service CA S/MIME |
| loki.example.com | `443` | TCP | Envoi de logs (Alloy → Loki, optionnel) |
| Serveur de mise à jour d'Alpine, AlmaLinux, etc. | `80` | TCP | Divers serveurs de mise à jour |
| Serveurs de courrier de destination | `25` | TCP | Livraison des courriels sortants (via recherche MX) |
| Serveurs DNS | `53` | UDP+TCP | Sortant vers les serveurs DNS publics |
| Serveurs NTP | `123` | UDP | NTP synchronise les horloges des ordinateurs, serveurs, équipements réseau et machines virtuelles avec des sources de temps précises |
| Accès au réseau interne pour Keycloak | `8090` | TCP | Utilisé pour authentifier les utilisateurs dans le tableau de bord HIN Gateway via Keycloak |

## Contactez-nous

!!! tip "Support"

    Pour toute question ou problème lié au déploiement et au fonctionnement de l'appliance HIN Mail (Stargate), veuillez contacter le support HIN.

    Veuillez inclure des informations pertinentes telles que le nom du client, la version de l'appliance, et des captures d'écran/[logs](./Docker-advanced.md#fournir-les-logs-au-support) le cas échéant, pour nous aider à traiter votre demande efficacement.

---

[![documentation](https://img.shields.io/github/check-runs/Health-Info-Net-AG/Stargate-deployment/main?nameFilter=Build%20documentation&style=for-the-badge&label=Documentation%20Build)](https://github.com/Health-Info-Net-AG/Stargate-deployment/actions/workflows/documentation.yml)
[![commit](https://img.shields.io/endpoint?style=for-the-badge&url=https://health-info-net-ag.github.io/Stargate-deployment/badges/build.json)](https://github.com/Health-Info-Net-AG/Stargate-deployment)
