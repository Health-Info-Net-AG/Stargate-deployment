# Überwachung und Logs

HIN Gateway enthält integrierte Überwachungs- und Log-Sammeldienste, die neben den Anwendungscontainern laufen.

## Komponenten

| Dienst | Port | Zweck |
| --------- | ------ | --------- |
| node-exporter | `9100` | Host-Metriken (CPU, Speicher, Festplatte, Netzwerk) für Prometheus |
| version-collector | - | Sammelt App-Versionen von `/liveness`-Endpunkten |
| Alloy | `12345` | Docker-Log-Sammler – sendet Container-Logs an Loki |
| Loki | `3100` (intern) | Lokales Log-Aggregations-Backend |
| Dozzle | `8190` | Webbasierter Container-Log-Viewer (HTTPS, Keycloak-SSO; optional) |
| oauth2-proxy | `8190` | OIDC-Relying-Party, die den Dozzle-Zugriff authentifiziert (mit Dozzle) |

---

## Dozzle – Lokaler Log-Viewer

Dozzle bietet eine webbasierte Benutzeroberfläche zum Anzeigen von Echtzeit-Logs aller Stargate-Container. Es ist optional und wird durch Setzen von `DOZZLE_ENABLED="true"` in `customer-config.sh` aktiviert.

Der Zugriff wird durch **Keycloak** geschützt: Ein `oauth2-proxy` sitzt vor Dozzle und erfordert dieselbe Anmeldung wie das Dashboard (die `stargate`-Realm). Dozzle selbst wird nicht direkt exponiert.

**Zugriff:** Öffnen Sie `https://<SERVER_IP>:8190` in einem Browser und melden Sie sich mit Ihren HIN-Gateway (Keycloak)-Anmeldeinformationen an.

!!! note
    Port `8190` (HTTPS) muss von Ihrem Netzwerk aus erreichbar sein. Wenn Sie den Zugriff nach IP oder Firewall einschränken, erlauben Sie `8190/tcp` wie für das Dashboard und Keycloak.

Logs sind nach Dienst organisiert. Durch Auswahl eines bestimmten Dienstes können Sie die entsprechenden Logeinträge und Details anzeigen.

![Dozzle-Übersicht](./assets/dozzle-overview.png)

---

## Grafana Alloy – Log-Weiterleitung

Grafana Alloy sammelt Logs von allen Stargate-Anwendungscontainern und schreibt sie in die lokale Loki-Instanz. Optional können Logs auch an einen entfernten Loki-kompatiblen Endpunkt für die zentralisierte Überwachung weitergeleitet werden.

### Wie es funktioniert

1. Alloy entdeckt Stargate-Container über den Docker-Socket
2. Logs werden immer in die **lokale Loki**-Instanz geschrieben (vom Dashboard für den Log-Export verwendet)
3. Wenn eine entfernte Loki-URL konfiguriert ist, werden Logs **zusätzlich** an diesen Endpunkt weitergeleitet

### Konfiguration der entfernten Log-Weiterleitung

Navigieren Sie im HIN-Gateway-Dashboard zur Seite **Einstellungen**. Geben Sie im Abschnitt **Grafana Alloy** die Loki-Push-URL Ihres entfernten Log-Sammlerservers ein:

![Alloy-Einstellungen](./assets/alloy-settings.png)

Die URL sollte dem Standard-Loki-Push-API-Format folgen:

```plain
https://logs.example.com/loki/api/v1/push
```

Lassen Sie das Feld leer, um die entfernte Log-Weiterleitung zu deaktivieren.

!!! note
    Änderungen werden innerhalb von 1 Minute wirksam (Alloy fragt die Dashboard-Konfiguration in diesem Intervall ab). Kein Container-Neustart ist erforderlich.

### Anforderungen auf der entfernten Seite

Ihr entfernter Loki-Endpunkt muss vom Stargate-Server über HTTPS (Port 443) erreichbar sein. Wenn Sie IP-basierte Allowlists auf Ihrem Ingress verwenden, fügen Sie die öffentliche IP des Stargate-Servers hinzu.

---

## Prometheus-Metriken

HIN Gateway stellt Prometheus-kompatible Metrik-Endpunkte von seinen Anwendungscontainern bereit. Diese können von jedem Prometheus-kompatiblen Server für die zentralisierte Metrik-Sammlung abgerufen werden.

### Verfügbare Endpunkte

| Dienst | Port | Pfad |
| --------- | ------ | ------ |
| smimekeys-client | `2113` | `/metrics` |
| irisagent | `2114` | `/metrics` |
| policy | `2115` | `/metrics` |
| mxengine | `2116` | `/metrics` |
| node-exporter | `9100` | `/metrics` |
| APISIX | `9091` | `/apisix/prometheus/metrics` |

### Scrape-Konfiguration

Fügen Sie den Stargate-Server als Ziel in Ihrer Prometheus-Konfiguration hinzu. Beispiel für eine einzelne Instanz:

```yaml
scrape_configs:
  - job_name: 'stargate-<name>-smimekeys'
    static_configs:
      - targets: ['<HIN_GATEWAY_IP>:2113']
        labels:
          environment: 'stargate-<name>'
          service: 'smimekeys-client'
    metrics_path: /metrics

  - job_name: 'stargate-<name>-irisagent'
    static_configs:
      - targets: ['<HIN_GATEWAY_IP>:2114']
        labels:
          environment: 'stargate-<name>'
          service: 'irisagent'
    metrics_path: /metrics

  - job_name: 'stargate-<name>-policy'
    static_configs:
      - targets: ['<HIN_GATEWAY_IP>:2115']
        labels:
          environment: 'stargate-<name>'
          service: 'policy'
    metrics_path: /metrics

  - job_name: 'stargate-<name>-mxengine'
    static_configs:
      - targets: ['<HIN_GATEWAY_IP>:2116']
        labels:
          environment: 'stargate-<name>'
          service: 'mxengine'
    metrics_path: /metrics

  - job_name: 'stargate-<name>-node'
    static_configs:
      - targets: ['<HIN_GATEWAY_IP>:9100']
        labels:
          environment: 'stargate-<name>'
          service: 'node-exporter'
    metrics_path: /metrics
```

Ersetzen Sie `<HIN_GATEWAY_IP>` durch die öffentliche oder private IP des Servers und `<name>` durch einen Bereitstellungsbezeichner (z.B. `prod`, `customer-name`).

!!! tip
    Die Labels `environment` und `service` ermöglichen das Filtern in Grafana-Dashboards über mehrere Stargate-Instanzen hinweg.

### Firewall-Anforderungen

Die Metrik-Ports (2113-2116, 9100) müssen von Ihrem Prometheus-Server aus erreichbar sein. Wenn Sie den Zugriff nach IP einschränken, fügen Sie die IP Ihres Überwachungsservers zu den Firewall-Regeln hinzu.

---

## Node Exporter

Der node-exporter-Dienst stellt standardmäßige Host-Metriken (CPU, Speicher, Festplatten-I/O, Netzwerk) auf Port **9100** bereit. Er enthält auch einen Textfile-Collector, der benutzerdefinierte Metriken vom version-collector-Sidecar (Anwendungsversionsinformationen) bereitstellt.

---

## Zusammenfassung der exponierten Ports

| Port | Dienst | Protokoll | Zweck |
| ------ | --------- | ---------- | --------- |
| `8190` | Dozzle (via oauth2-proxy) | HTTPS | Authentifizierter Log-Viewer-UI (Keycloak-SSO) |
| `9100` | node-exporter | HTTP | Host-Metriken (Prometheus) |
| `2113` | smimekeys-client | HTTP | App-Metriken (Prometheus) |
| `2114` | irisagent | HTTP | App-Metriken (Prometheus) |
| `2115` | policy | HTTP | App-Metriken (Prometheus) |
| `2116` | mxengine | HTTP | App-Metriken (Prometheus) |
| `9091` | APISIX | HTTP | Gateway-Metriken (Prometheus) |
