# Monitoraggio e Log

Stargate include servizi integrati di monitoraggio e raccolta log che vengono eseguiti insieme ai container delle applicazioni.

## Componenti

| Servizio | Porta | Scopo |
|---------|------|---------|
| node-exporter | `9100` | Metriche a livello host (CPU, memoria, disco, rete) per Prometheus |
| version-collector | - | Raccoglie le versioni delle app dagli endpoint `/liveness` |
| Alloy | `12345` | Collettore di log Docker - invia i log dei container a Loki |
| Loki | `3100` (interno) | Backend locale di aggregazione log |
| Dozzle | `8190` | Visualizzatore di log dei container basato sul web (HTTPS, SSO Keycloak; opzionale) |
| oauth2-proxy | `8190` | Parte affidabile OIDC che autentica l'accesso Dozzle (con Dozzle) |

---

## Dozzle - Visualizzatore di log locale

Dozzle fornisce un'interfaccia web per visualizzare i log in tempo reale di tutti i container Stargate. È opzionale e abilitato impostando `DOZZLE_ENABLED="true"` in `customer-config.sh`.

L'accesso è protetto da **Keycloak**: un `oauth2-proxy` si trova davanti a Dozzle e richiede lo stesso login del dashboard (il realm `stargate`). Dozzle stesso non è esposto direttamente.

**Accesso:** aprire `https://<IP_SERVER>:8190` in un browser e accedere con le credenziali HIN Gateway (Keycloak).

!!! note
    La porta `8190` (HTTPS) deve essere raggiungibile dalla tua rete. Se limiti l'accesso per IP o firewall, consenti `8190/tcp` come fai per il dashboard e Keycloak.

I log sono organizzati per servizio. Selezionando un servizio specifico, è possibile visualizzare le relative voci di log e i dettagli.

![Panoramica Dozzle](./assets/dozzle-overview.png)

---

## Grafana Alloy - Inoltro log

Grafana Alloy raccoglie i log da tutti i container delle applicazioni Stargate e li scrive nell'istanza Loki locale. Opzionalmente, i log possono anche essere inoltrati a un endpoint remoto compatibile con Loki per il monitoraggio centralizzato.

### Come funziona

1. Alloy scopre i container Stargate tramite il socket Docker
2. I log vengono sempre scritti nell'istanza **Loki locale** (utilizzata dal dashboard per l'esportazione dei log)
3. Se un URL Loki remoto è configurato, i log vengono **inoltrati anche** a quell'endpoint

### Configurazione dell'inoltro log remoto

Dal dashboard HIN Gateway, navigare alla pagina **Impostazioni**. Nella sezione **Grafana Alloy**, inserire l'URL di push Loki del server di raccolta log remoto:

![Impostazioni Alloy](./assets/alloy-settings.png)

L'URL deve seguire il formato standard dell'API di push Loki:

```plain
https://logs.example.com/loki/api/v1/push
```

Lasciare il campo vuoto per disabilitare l'inoltro log remoto.

!!! note
    Le modifiche hanno effetto entro 1 minuto (Alloy interroga la configurazione del dashboard a quell'intervallo). Non è necessario riavviare il container.

### Requisiti lato remoto

Il tuo endpoint Loki remoto deve essere raggiungibile dal server Stargate via HTTPS (porta 443). Se utilizzi l'inserimento in whitelist basato su IP sul tuo ingress, aggiungi l'IP pubblico del server Stargate.

---

## Metriche Prometheus

Stargate espone endpoint di metriche compatibili con Prometheus dai suoi container applicativi. Questi possono essere raccolti da qualsiasi server compatibile con Prometheus per la raccolta centralizzata delle metriche.

### Endpoint disponibili

| Servizio | Porta | Percorso |
|---------|------|------|
| smimekeys-client | `2113` | `/metrics` |
| irisagent | `2114` | `/metrics` |
| policy | `2115` | `/metrics` |
| mxengine | `2116` | `/metrics` |
| node-exporter | `9100` | `/metrics` |
| APISIX | `9091` | `/apisix/prometheus/metrics` |

### Configurazione di raccolta

Aggiungi il server Stargate come target nella configurazione di Prometheus. Esempio per una singola istanza:

```yaml
scrape_configs:
  - job_name: 'stargate-<nome>-smimekeys'
    static_configs:
      - targets: ['<IP_STARGATE>:2113']
        labels:
          environment: 'stargate-<nome>'
          service: 'smimekeys-client'
    metrics_path: /metrics

  - job_name: 'stargate-<nome>-irisagent'
    static_configs:
      - targets: ['<IP_STARGATE>:2114']
        labels:
          environment: 'stargate-<nome>'
          service: 'irisagent'
    metrics_path: /metrics

  - job_name: 'stargate-<nome>-policy'
    static_configs:
      - targets: ['<IP_STARGATE>:2115']
        labels:
          environment: 'stargate-<nome>'
          service: 'policy'
    metrics_path: /metrics

  - job_name: 'stargate-<nome>-mxengine'
    static_configs:
      - targets: ['<IP_STARGATE>:2116']
        labels:
          environment: 'stargate-<nome>'
          service: 'mxengine'
    metrics_path: /metrics

  - job_name: 'stargate-<nome>-node'
    static_configs:
      - targets: ['<IP_STARGATE>:9100']
        labels:
          environment: 'stargate-<nome>'
          service: 'node-exporter'
    metrics_path: /metrics
```

Sostituisci `<IP_STARGATE>` con l'IP pubblico o privato del server e `<nome>` con un identificatore di deployment (es., `prod`, `nome-cliente`).

!!! tip
    Le etichette `environment` e `service` consentono il filtraggio nei dashboard Grafana su più istanze Stargate.

### Requisiti firewall

Le porte delle metriche (2113-2116, 9100) devono essere raggiungibili dal server Prometheus. Se limiti l'accesso per IP, aggiungi l'IP del server di monitoraggio alle regole del firewall.

---

## Node Exporter

Il servizio node-exporter espone metriche standard a livello host (CPU, memoria, I/O del disco, rete) sulla porta **9100**. Include anche un raccoglitore di file di testo che espone metriche personalizzate dal sidecar version-collector (informazioni sulla versione delle applicazioni).

---

## Riepilogo delle porte esposte

| Porta | Servizio | Protocollo | Scopo |
|------|---------|----------|---------|
| `8190` | Dozzle (via oauth2-proxy) | HTTPS | Interfaccia di visualizzazione log autenticata (SSO Keycloak) |
| `9100` | node-exporter | HTTP | Metriche dell'host (Prometheus) |
| `2113` | smimekeys-client | HTTP | Metriche dell'app (Prometheus) |
| `2114` | irisagent | HTTP | Metriche dell'app (Prometheus) |
| `2115` | policy | HTTP | Metriche dell'app (Prometheus) |
| `2116` | mxengine | HTTP | Metriche dell'app (Prometheus) |
| `9091` | APISIX | HTTP | Metriche del gateway (Prometheus) |
