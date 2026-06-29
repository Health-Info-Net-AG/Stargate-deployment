# Panoramica delle applicazioni

## Applicazioni

* **smimekeys-client** - Servizio client chiavi S/MIME (porta `8081`)
* **policy** - Servizio policy (porta `8082`)
* **irisagent** - Servizio IRIS Agent (porta `8083`, WireGuard: `19818/udp`, `19818/tcp`)
* **mxengine** - Servizio MX Engine (porta `8084`, SMTP: `1587`)
* **stalwart** - Server di posta Stalwart MTA (porta `25`, `10026`)
* **clamav** - Antivirus ClamAV; scansiona le email nella fase SMTP DATA di Stalwart tramite il protocollo milter (porta `7357`)
* **mtaconf** - Demone di configurazione MTA (API: `8080`)
* **dashboard** - Interfaccia di amministrazione web per onboarding, gestione dei domini e monitoraggio (porta `443`)
* **policy-sync** - Sincronizza le policy OPA/Rego dal repository Git al database (viene eseguito in continuazione)

## Infrastruttura

* **PostgreSQL** - Database (porta `5432`)
* **Vault** - Gestione dei segreti (porta interna `8200`, non pubblicata sull'host)
* **MinIO** - Storage compatibile S3 (API sulla porta host `9000`; console non pubblicata sull'host)
* **Keycloak** - Provider di identità e autenticazione OIDC (porta `8180`)
* **APISIX** - Gateway API con autenticazione OIDC bearer (porta `9080`)
* **NATS** - Messaggistica inter-servizi (attiva i ricaricamenti di Stalwart dal dashboard)

## Container di inizializzazione

* **vault-init** - Inizializza e scongela Vault al primo avvio
* **seaweedfs-init** - Crea il bucket S3
* **apisix-init** - Genera la configurazione APISIX dal modello
* **keycloak-init** - Imposta la password amministratore iniziale

## Monitoraggio

* **node-exporter** - Metriche dell'host per Prometheus (porta `9100`)
* **version-collector** - Raccoglie le versioni delle app dagli endpoint `/liveness` per node-exporter
* **Alloy** - Collettore di log per Loki (invia i log delle app)
* **Dozzle** - Visualizzatore di log dei container in tempo reale (porta `8190`, HTTPS, dietro SSO Keycloak tramite oauth2-proxy; opzionale, abilitato con `DOZZLE_ENABLED`)
* **oauth2-proxy** - Parte affidabile OIDC che autentica l'accesso Dozzle contro Keycloak (si avvia insieme a Dozzle)

Vedere [Monitoraggio e Log](Monitoring.md) per configurazione dettagliata e utilizzo.

## Panoramica dell'architettura

![Architettura](assets/arch-gateway.png)

## Panoramica dell'architettura VM

![Panoramica VM](assets/vm-arch-gateway.png)
