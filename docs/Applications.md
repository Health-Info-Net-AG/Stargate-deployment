# Applications overview

## Applications

* **smimekeys-client** - S/MIME keys client service (port 8081)
* **policy** - Policy service (port 8082)
* **irisagent** - IRIS Agent service (port 8083, WireGuard: 19818/udp, 19818/tcp)
* **mxengine** - MX Engine service (port 8084, SMTP: 1587)
* **stalwart** - Stalwart MTA mail server (port 25, 10026)
* **mtaconf** - MTA configuration daemon (API: 8080)
* **dashboard** - Web-based admin UI for onboarding, domain management, and monitoring (port 443)
* **policy-sync** - Syncs OPA/Rego policies from Git repository to database (runs continuously)

## Infrastructure

* **PostgreSQL** - Database (port 5432)
* **Vault** - Secrets management (port 8200)
* **MinIO** - S3-compatible storage (API: 9000, Console: 9001)
* **Keycloak** - Identity provider and OIDC authentication (port 8180)
* **APISIX** - API gateway with OIDC bearer auth (port 9080)
* **NATS** - Inter-service messaging (triggers Stalwart reloads from dashboard)

## Init Containers

* **vault-init** - Initializes and unseals Vault on first run
* **minio-init** - Creates the S3 bucket
* **apisix-init** - Generates APISIX config from template
* **keycloak-init** - Sets initial admin password

## Monitoring

* **node-exporter** - Host metrics for Prometheus (port 9100)
* **version-collector** - Collects app versions from `/liveness` endpoints for node-exporter
* **Alloy** - Log collector for Loki (ships app logs)
* **Dozzle** - Real-time container log viewer (port 8090)

See [Monitoring and Logs](Monitoring.md) for detailed configuration and usage.

## Architecture overview

![Architecture](https://www.hin.ch/files/png1/blog-full/graph3-v5.png)
