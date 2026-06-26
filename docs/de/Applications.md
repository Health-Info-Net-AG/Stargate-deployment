# Anwendungsübersicht

## Anwendungen

* **smimekeys-client** – S/MIME-Schlüssel-Client-Dienst (Port `8081`)
* **policy** – Policy-Dienst (Port `8082`)
* **irisagent** – IRIS-Agent-Dienst (Port `8083`, WireGuard: `19818/udp`, `19818/tcp`)
* **mxengine** – MX-Engine-Dienst (Port `8084`, SMTP: `1587`)
* **stalwart** – Stalwart-MTA-Mailserver (Port `25`, `10026`)
* **clamav** – ClamAV-Antivirus; scannt E-Mails in der SMTP-DATA-Phase von Stalwart über das Milter-Protokoll (Port `7357`)
* **mtaconf** – MTA-Konfigurations-Daemon (API: `8080`)
* **dashboard** – Webbasierte Admin-UI für Onboarding, Domainverwaltung und Überwachung (Port `443`)
* **policy-sync** – Synchronisiert OPA/Rego-Richtlinien aus dem Git-Repository mit der Datenbank (läuft kontinuierlich)

## Infrastruktur

* **PostgreSQL** – Datenbank (Port `5432`)
* **Vault** – Secrets-Verwaltung (interner Port `8200`, nicht an den Host veröffentlicht)
* **MinIO** – S3-kompatibler Speicher (API auf Host-Port `9000`; Konsole nicht an den Host veröffentlicht)
* **Keycloak** – Identitätsanbieter und OIDC-Authentifizierung (Port `8180`)
* **APISIX** – API-Gateway mit OIDC-Bearer-Authentifizierung (Port `9080`)
* **NATS** – Inter-Service-Messaging (löst Stalwart-Neuladungen vom Dashboard aus)

## Init-Container

* **vault-init** – Initialisiert und entsiegelt Vault beim ersten Start
* **seaweedfs-init** – Erstellt den S3-Bucket
* **apisix-init** – Generiert die APISIX-Konfiguration aus der Vorlage
* **keycloak-init** – Setzt das anfängliche Admin-Passwort

## Überwachung

* **node-exporter** – Host-Metriken für Prometheus (Port `9100`)
* **version-collector** – Sammelt App-Versionen von `/liveness`-Endpunkten für node-exporter
* **Alloy** – Log-Sammler für Loki (sendet App-Logs)
* **Dozzle** – Echtzeit-Container-Log-Viewer (Port `8190`, HTTPS, hinter Keycloak-SSO via oauth2-proxy; optional, aktiviert mit `DOZZLE_ENABLED`)
* **oauth2-proxy** – OIDC-Relying-Party, die den Dozzle-Zugriff gegen Keycloak authentifiziert (startet zusammen mit Dozzle)

Siehe [Überwachung und Logs](Monitoring.md) für detaillierte Konfiguration und Nutzung.

## Architekturübersicht

![Architektur](assets/arch-gateway.png)

## VM-Architekturübersicht

![VM-Übersicht](assets/vm-arch-gateway.png)
