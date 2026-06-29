# Aperçu des applications

## Applications

* **smimekeys-client** - Service client de clés S/MIME (port `8081`)
* **policy** - Service de politiques (port `8082`)
* **irisagent** - Service IRIS Agent (port `8083`, WireGuard: `19818/udp`, `19818/tcp`)
* **mxengine** - Service MX Engine (port `8084`, SMTP: `1587`)
* **stalwart** - Serveur mail Stalwart MTA (port `25`, `10026`)
* **clamav** - Antivirus ClamAV ; analyse les courriels au stade SMTP DATA de Stalwart via le protocole milter (port `7357`)
* **mtaconf** - Démon de configuration MTA (API: `8080`)
* **dashboard** - Interface d'administration web pour l'intégration, la gestion des domaines et la surveillance (port `443`)
* **policy-sync** - Synchronise les politiques OPA/Rego du dépôt Git vers la base de données (s'exécute en continu)

## Infrastructure

* **PostgreSQL** - Base de données (port `5432`)
* **Vault** - Gestion des secrets (port interne `8200`, non publié sur l'hôte)
* **MinIO** - Stockage compatible S3 (API sur le port hôte `9000` ; console non publiée sur l'hôte)
* **Keycloak** - Fournisseur d'identité et authentification OIDC (port `8180`)
* **APISIX** - Passerelle API avec authentification OIDC bearer (port `9080`)
* **NATS** - Messagerie inter-services (déclenche les rechargements de Stalwart depuis le tableau de bord)

## Conteneurs d'initialisation

* **vault-init** - Initialise et désceau Vault lors du premier démarrage
* **seaweedfs-init** - Crée le bucket S3
* **apisix-init** - Génère la configuration APISIX à partir du modèle
* **keycloak-init** - Définit le mot de passe administrateur initial

## Surveillance

* **node-exporter** - Métriques de l'hôte pour Prometheus (port `9100`)
* **version-collector** - Collecte les versions des applications depuis les points de terminaison `/liveness` pour node-exporter
* **Alloy** - Collecteur de logs pour Loki (transporte les logs des applications)
* **Dozzle** - Visualisateur de logs de conteneurs en temps réel (port `8190`, HTTPS, derrière le SSO Keycloak via oauth2-proxy ; optionnel, activé avec `DOZZLE_ENABLED`)
* **oauth2-proxy** - Partie fiable OIDC qui authentifie l'accès Dozzle auprès de Keycloak (démarre avec Dozzle)

Voir [Surveillance et Logs](Monitoring.md) pour une configuration détaillée et l'utilisation.

## Aperçu de l'architecture

![Architecture](assets/arch-gateway.png)

## Aperçu de l'architecture VM

![Aperçu VM](assets/vm-arch-gateway.png)
