# HIN Gateway Docker-Bereitstellung

## Voraussetzungen

**Server-Anforderungen:**

Bitte beachten Sie die [Empfohlenen Anforderungen](./index.md#server-anforderungen)

* Docker wird bei Bedarf automatisch installiert
* Stellen Sie sicher, dass auf dem System, auf dem Sie Stargate-Dienste installieren, eine Internetverbindung besteht
* Stellen Sie sicher, dass der Datenverkehr ordnungsgemäß konfiguriert ist, um die Stargate-Instanz zu erreichen

## Schritt 1: Kundeneinstellungen konfigurieren

!!! tip
    Sie können unser Repository mit allen Daten und Beispielkonfigurationen mit folgendem Befehl klonen:

    ```bash
    git clone https://github.com/Health-Info-Net-AG/Stargate-deployment.git
    ```

    Wenn Sie `git` nicht installiert haben, können Sie jederzeit ein Archiv mit allen Dateien herunterladen. Laden Sie es über den folgenden Link herunter.
    
    [Als ZIP herunterladen](https://github.com/Health-Info-Net-AG/Stargate-deployment/archive/refs/heads/main.zip){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

Das Installationsskript erstellt `customer-config.sh` beim ersten Start automatisch aus der mitgelieferten Vorlage, sodass eine Neuinstallation **keine manuelle Konfiguration** benötigt. Wenn Sie sie lieber selbst erstellen möchten, kopieren Sie die Vorlage:

```bash
cp customer-config-prod.example.sh customer-config.sh
```

Sie müssen darin **nichts** bearbeiten - jeder Wert wird entweder automatisch erkannt oder später über das Dashboard konfiguriert:

| Einstellung | Wie sie gesetzt wird |
| --------- | --------------- |
| `SERVER_STATIC_IP` | Automatisch von der primären Netzwerkschnittstelle des Servers erkannt. |
| `CUSTOMER_NAME` | Standardmäßig der System-Hostname. |
| `DEPLOYMENT_NAME` | Von `CUSTOMER_NAME` abgeleitet (wird in Log-Labels und im Alloy-Hostname verwendet). |
| Passwörter & Schlüssel (`POSTGRES_PASSWORD`, `S3_SECRET_KEY`, `VAULT_TOKEN`, `WG_PRIVATE_KEY`) | Werden beim ersten Start sicher generiert und in `customer-config.sh` zurückgeschrieben. |

Mail-Domains, der Mail-Hostname, S/MIME-Zertifikate und WireGuard-Peers werden alle zur Laufzeit über das Dashboard konfiguriert, nachdem der Stack läuft - sie sind nicht Teil von `customer-config.sh`.

!!! note "Hinter NAT oder einer Floating IP?"
    Die automatische Erkennung verwendet die IP der primären Schnittstelle des Servers. Wenn Ihr Server über eine *andere* öffentliche oder Floating IP erreicht wird (üblich bei NAT), setzen Sie `SERVER_STATIC_IP` vor der Installation auf diese öffentliche IP in `customer-config.sh`, damit die Dashboard- und Keycloak-Login-URLs auf die erreichbare Adresse zeigen. Lassen Sie es andernfalls leer.

Mail-Domains und der Stalwart-Hostname werden zur Laufzeit über die `/mail`-Seite des Dashboards konfiguriert; sie sind nicht Teil von `customer-config.sh`.

**Automatisch abgeleitete Einstellungen – leer lassen, es sei denn, Sie müssen sie überschreiben:**

| Einstellung | Abgeleitet von | Standard |
|---------|-------------|---------|
| `MXENGINE_PUBLIC_ADDRESS` | `SERVER_STATIC_IP` | `http://<SERVER_STATIC_IP>:8084` |

**S/MIME-Zertifikatseinstellungen:**

| Einstellung | Beschreibung | Standard |
|---------|-------------|---------|
| `CERT_CA_IRISAGENT_DOMAIN` | CA-Domain für die Zertifikatsausstellung über den WireGuard-Tunnel | `hintest.ch` |

!!! note
    **Die WireGuard-Peer-Einrichtung** wird zur Laufzeit über das Dashboard (`/installation`-Seite) durchgeführt. Peer-Details werden pro Bereitstellung nach dem Start des Stacks konfiguriert – sie sind nicht Teil von `customer-config.sh`.

**WireGuard lokale Einstellungen (normalerweise bei Standardwerten belassen):**

| Einstellung | Standard | Beschreibung |
| --------- | ------------- | --------- |
| `WG_PRIVATE_KEY` | *(automatisch generiert)* | Wird von IRISAgent beim ersten Start generiert und dann in `customer-config.sh` gespeichert |
| `WG_LOCAL_IP` | `SERVER_STATIC_IP` | Automatisch abgeleitet. Nur überschreiben, wenn Sie eine andere Tunneladresse benötigen. |
| `WG_INTERFACE_PORT` | `19818` | WireGuard-Tunnelport (sowohl TCP als auch UDP werden freigegeben) |
| `WG_TRANSPORT_MODE` | `tcp` | Transportprotokoll: `tcp` (Standard, funktioniert durch die meisten Firewalls) oder `udp` |

**Optionale Einstellungen (haben sinnvolle Standardwerte):**

| Einstellung | Standard | Beschreibung |
| --------- | ------------- | --------- |
| `POSTGRES_PASSWORD` | *(automatisch generiert)* | Automatisch generiertes 24-stelliges Zufallspasswort, falls leer |
| `S3_SECRET_KEY` | *(automatisch generiert)* | S3-Secret-Key für den Objektspeicher |
| `OUTBOUND_SEALER_MX_DOMAIN` | `hintest.ch` | Sealer-MX-Domain für die Zustellung ausgehender Siegel |
| `POLICY_SYNC_REPO_URL` | GitHub HIN Stargate-Richtlinien | Git-Repository-URL für die OPA/Rego-Richtlinien-Synchronisierung |
| `LOKI_URL` | *(nicht gesetzt)* | Loki-Endpunkt für den zentralisierten Logversand (z.B. `https://loki.example.com`) |

**Automatisch generiert (nicht manuell setzen):**

* `VAULT_TOKEN` — Wird von Vault während der ersten Initialisierung generiert und in `customer-config.sh` gespeichert
* `WG_PRIVATE_KEY` — Wird von IRISAgent beim ersten Start generiert und in `customer-config.sh` gespeichert

## Schritt 2: Auf einem Server bereitstellen

!!! tip
    Sie können unser Repository mit allen Daten und Beispielkonfigurationen mit folgendem Befehl klonen:

    ```bash
    git clone https://github.com/Health-Info-Net-AG/Stargate-deployment.git && \
      cd Stargate-deployment-main
    ```

    Wenn Sie `git` nicht installiert haben, können Sie jederzeit ein Archiv mit allen Dateien herunterladen und es extrahieren:

    ```bash 
    wget https://github.com/Health-Info-Net-AG/Stargate-deployment/archive/refs/heads/main.zip && \
      unzip main.zip && \
      rm main.zip && \
      cd Stargate-deployment-main
    ```

Kopieren Sie die Dateien manuell auf den Server

```bash
scp -r docker-compose/* your-server:/path/to/stargate/
```

SSH zum Server

```bash
ssh your-server
cd /path/to/stargate
```

Erstellen Sie die Kundenkonfiguration aus der Vorlage und füllen Sie die erforderlichen Einstellungen aus ([siehe Schritt 1](#schritt-1-kundeneinstellungen-konfigurieren))

```bash
cp customer-config-prod.example.sh customer-config.sh
nano customer-config.sh   # Erforderliche Einstellungen ausfüllen (siehe Schritt 1)
```

Installation ausführen

```bash
chmod +x scripts/*.sh
./scripts/install.sh
```

## Schritt 3: Was die Installation bewirkt

Das Installationsskript (`install.sh`) führt die folgenden Schritte durch:

1. **Abhängigkeiten prüfen** — Erkennt Docker, Docker Compose und `jq`. Wenn diese fehlen, werden sie automatisch installiert (unterstützt Ubuntu/Debian, RHEL/AlmaLinux/Rocky).
2. **`customer-config.sh` laden und validieren** — Prüft erforderliche Felder (`SERVER_STATIC_IP`, `CUSTOMER_NAME`, `DEPLOYMENT_NAME`). Leitet optionale Felder automatisch ab (MXEngine-URL usw.).
3. **`.env` aus der Kundenkonfiguration generieren** — Generiert automatisch Passwörter, falls nicht gesetzt.
4. **Alle Dienste über Docker Compose starten** (Infrastruktur + Anwendungen).
5. **Vault initialisieren** — Der `vault-init`-Container initialisiert, entsiegelt und erstellt KV-v2-Secret-Mounts. Schreib den WireGuard-Private-Key optional in Vault.
6. **Vault-Schlüssel in `secrets/vault-keys.json` speichern und `.env` mit dem Root-Token aktualisieren.** Das Token wird auch in `customer-config.sh` gespeichert, um es über VM-Neuerstellungen hinweg zu erhalten.
7. **Anwendungsdienste neu starten**, um das Vault-Token zu übernehmen.
8. **WireGuard-Private-Key in `customer-config.sh` speichern** — wird nach der Generierung durch IRISAgent aus Vault extrahiert.
9. **Täglichen Backup-Cron-Job einrichten** (wird um 2:00 Uhr ausgeführt).

Nach Abschluss der Installation läuft der Stack, aber es sind noch keine Mail-Domains, S/MIME-Zertifikate oder WireGuard-Peers eingerichtet. Fahren Sie mit [Schritt 4: Onboarding über das Dashboard](#schritt-4-onboarding-uber-das-dashboard) fort.

## Schritt 4: Onboarding über das Dashboard

Nach der Installation schließen Sie das Onboarding über das Dashboard unter `https://<SERVER_STATIC_IP>` ab. Das Dashboard führt Sie der Reihe nach durch drei Seiten:

### `/installation` — WireGuard-Peer-Einrichtung

Führt den Nonce/HIN-Handshake durch, um eine WireGuard-Peer-Verbindung herzustellen, und speichert die resultierende WireGuard-Konfiguration im IRISAgent-Dienst.

### `/onboarding` — S/MIME-Zertifikat

Generiert den S/MIME-Signaturschlüssel und den CSR über den smimekeys-Dienst und übermittelt den CSR über den nun eingerichteten WireGuard-Tunnel an die CA. (Dies ersetzt den früheren skriptbasierten Zertifikatsfluss.)

### `/mail` — Mail-Domains und Relay-Konfiguration

Übermittelt Hostname und die Liste der Relay-Domains über die REST-API an den `mtaconf`-Dienst. Der Daemon wendet die Konfiguration auf Stalwart an, ohne den Container neu starten zu müssen.

!!! tip "Domains später hinzufügen oder ändern"
    Öffnen Sie die `/mail`-Seite im Dashboard erneut, bearbeiten Sie die Domain-Liste und übermitteln Sie sie. Der Daemon wendet die Änderung zur Laufzeit an – kein Skriptaufruf, keine `.env`-Bearbeitung, kein Dienstneustart erforderlich.

## Schritt 5: WireGuard-Peer-Registrierung

Die CSR-Übermittlung auf `/onboarding` schlägt fehl, wenn Ihre Stargate-Instanz auf der HIN-CA-Seite noch nicht als WireGuard-Peer registriert ist. Dies ist das häufigste Problem während der Erstinstallation.

Die `/installation`-Seite des Dashboards übernimmt die WireGuard-Peer-Registrierung automatisch über den Nonce/HIN-Handshake. Wenn die automatische Registrierung fehlschlägt, kann eine manuelle Registrierung durchgeführt werden, indem Sie die folgenden Werte an HIN übermitteln:

1. **WireGuard-öffentlicher Schlüssel** — aus den Irisagent-Logs extrahieren:

   ```bash
   docker compose logs irisagent | grep "public key"
   ```

2. **`DEPLOYMENT_NAME`** — aus Ihrer `customer-config.sh`
3. **`SERVER_STATIC_IP`** — die öffentliche IP Ihres Stargate-Servers
4. **`WG_INTERFACE_PORT`** — nur wenn Sie ihn vom Standard `19818` geändert haben

**Nach Bestätigung der Peer-Registrierung:**

Führen Sie die `/onboarding`-Seite im Dashboard erneut aus, um den CSR neu zu generieren und über den nun aktiven Tunnel zu übermitteln.

**Um den Tunnel vor der Zertifikatsanforderung zu überprüfen:**

Starten Sie nur irisagent neu

```bash
docker compose restart irisagent
```

Prüfen Sie auf erfolgreichen WireGuard-Handshake

```bash
docker compose logs irisagent 2>&1 | grep -i "handshake\|peer"
```

!!! tip
    Überprüfen Sie Ihre Firewall: Port `19818/TCP` muss **sowohl eingehend als auch ausgehend** auf dem Stargate-Server geöffnet sein.

## Schritt 6: Empfehlungen nach dem Onboarding

Sobald das Zertifikat ausgestellt ist und E-Mails fließen, werden zwei Konfigurationspunkte für jede Produktionsbereitstellung dringend empfohlen. Wenn Sie diese überspringen, wird die Verschlüsselung nicht beeinträchtigt, aber Ihr Absender-Ruf leidet, Outlook/Gmail zeigen "Wir können den Absender nicht überprüfen"-Warnungen an und dies kann letztendlich dazu führen, dass ausgehende E-Mails auf Blocklisten gesetzt werden.

### Schritt 6.1 SPF / DKIM / DMARC für Absender-Domains

HIN Gateway sendet E-Mails von seiner eigenen öffentlichen IP im Namen Ihrer Benutzer. Ohne korrekte DNS-Authentifizierungsdatensätze sehen Empfänger Warnungen wie "wir können diesen Absender nicht überprüfen" und können die E-Mail ablehnen.

Vollständige Anweisungen zur Konfiguration von SPF, DKIM, DMARC und PTR-Einträgen finden Sie im [DNS-Einrichtungsleitfaden](DNS-setup.md#empfohlene-eintrage).

Mindestens für jede Domain, die Sie über HIN Gateway routen:

* **SPF**: Fügen Sie `ip4:<HIN_GATEWAY_IP>` zum TXT-Eintrag der Domain hinzu
* **DMARC**: Veröffentlichen Sie `v=DMARC1; p=none` unter `_dmarc.<IHRER_DOMAIN>`
* **PTR**: Setzen Sie das reverse DNS für die Stargate-IP so, dass es mit `MAIL_HOSTNAME` übereinstimmt

### Schritt 6.2 Ausgehende E-Mails zurück über Ihre Mail-Plattform leiten (empfohlen für M365 / Exchange Online)

Standardmäßig liefert HIN Gateway nach dem Signieren/Verschlüsseln einer ausgehenden E-Mail direkt an den MX des Empfängers. Das funktioniert, aber die verbindende IP ist die Ihres HIN Gateway – und es sei denn, diese IP hat jahrelang einen guten Ruf aufgebaut, kann sie auf Blocklisten von Drittanbietern (z.B. Barracuda, Abusix) landen, was zu gelegentlichen Zustellfehlern führt.

Das empfohlene Muster ist, die **signierte E-Mail zurück über Ihren M365-/Exchange-Mandanten zu senden**, sodass der letzte Hop ins Internet die gut beleumundete Infrastruktur von Microsoft ist. HIN Gateway signiert und prüft weiterhin jede Nachricht policy-gemäß; nur der letzte Hop ändert sich. Dies spiegelt das ursprüngliche "An MX senden"-Connector-Muster des HIN-MGW wider.

#### Stargate-Seite – pro-Domain-Relay

Konfigurieren Sie das pro-Domain-Relay über die `/mail`-Seite des Dashboards. Jede Domain kann ihrem eigenen M365-/Exchange-Eingangs-Endpunkt zugeordnet werden; das Dashboard sendet die Zuordnung an die REST-API von mtaconf und Stalwart wird zur Laufzeit neu konfiguriert.

Nachdem mxengine die E-Mail signiert hat, übergibt Stalwart sie an Ihren Mandanten auf Port 25 mit TLS, anstatt sie direkt an den MX des Empfängers zuzustellen. Siehe `Exchange-integration.md` für die vollständige pro-Domain-Syntax.

#### M365 / Exchange Online-Seite

Sie erstellen im Wesentlichen denselben Connector + Transportregeln-Satz wie beim alten HIN-MGW (das ursprüngliche HIN-MGW-O365-Handbuch ist die Referenz – die gleichen fünf Regeln gelten). Das Minimum ist:

1. **Eingehender Connector** – akzeptiert E-Mails von HIN Gateway, identifiziert durch das TLS-Zertifikat (der Zertifikatsgegenstand muss mit einer in Ihrem Mandanten akzeptierten Domain übereinstimmen). Ein selbstsigniertes Zertifikat auf HIN Gateway wird von diesem Connector abgelehnt – verwenden Sie ein gültiges, von einer CA ausgestelltes Zertifikat (Let's Encrypt ist in Ordnung).
2. **Ausgehender Connector "An MX senden"** – stellt an den MX des Empfängers zu, wird nur durch eine Transportregel aktiviert.
3. **Transportregel `set_header`** – kennzeichnet ausgehende E-Mails mit einem Header wie `outgoing: outgoing_<domain>`, bevor sie das erste Mal O365 verlassen, damit der Rückweg sie erkennen kann.
4. **Transportregel `outgoing_to_mx`** – erkennt den `outgoing_<domain>`-Header auf E-Mails, die von HIN Gateway zurückkommen, und leitet sie über den "An MX senden"-Connector.
5. **Transportregel `mgw_bypass_antispam`** – umgeht die Spam-Filterung bei E-Mails, die von HIN Gateway zurückkommen.

mxengine entfernt keine beliebigen Header, daher überlebt das von `set_header` gesetzte `outgoing_<domain>`-Tag den Rundlauf und löst `outgoing_to_mx` korrekt aus.

!!! info "Warum dieses Muster wichtig ist"
    Bei der Relay-back-Konfiguration ist der öffentliche Absender für das Internet Microsoft. Kombiniert mit korrektem SPF/DKIM/DMARC (Abschnitt 6.1) sehen Empfänger eine Microsoft-IP mit `spf=pass` und `dkim=pass`, die auf Ihre Domain ausgerichtet sind – das beste Rufprofil, das Sie ihnen bieten können.

Vollständige Schritt-für-Schritt-Anleitung inklusive Screenshots finden Sie in `Exchange-integration.md`.

## Nachfolgende Starts (nach Neustart)

Der Installer aktiviert eine `stargate`-Systemd-Einheit, sodass der Stack beim Booten automatisch startet. Um ihn manuell zu starten:

```bash
sudo systemctl start stargate
```

Dies führt `start.sh` aus, das:

1. Infrastrukturdienste startet
2. Vault mit den gespeicherten Schlüsseln entsiegelt
3. Anwendungsdienste startet

(`./scripts/start.sh` funktioniert weiterhin direkt, wenn Sie das bevorzugen.)

## Dienste anhalten

```bash
sudo systemctl stop stargate
```

(oder direkt `./scripts/stop.sh`)

Dies hält Container an, bewahrt aber alle Daten.

## Datenpersistenz

Alle Daten werden in Docker-Volumes gespeichert und **bleiben über Neustarts hinweg erhalten**.

| Dienst | Volume | Daten |
| --------- | -------- | ------ |
| PostgreSQL | `postgres_data` | Alle Datenbanken (smimekeys, policy, irisagent, mxengine) |
| Vault | `vault_data` | Verschlüsselungsschlüssel, Secrets, S/MIME-Schlüssel |
| SeaweedFS | `seaweedfs_data` | Objektspeicher (Nachrichten, Anhänge) |
| Stalwart | `stalwart_data` | Mail-Server-Zustand |

### Sichere Operationen (Daten bleiben erhalten)

Anhalten und starten:

```bash
sudo systemctl stop stargate
sudo systemctl start stargate
```

Oder direkt mit den Skripten:

```bash
./scripts/stop.sh
./scripts/start.sh
```

!!! warning "Verwenden Sie keine `docker compose`-Befehle direkt"
    Verwenden Sie immer `systemctl` oder die bereitgestellten Skripte (`start.sh` / `stop.sh`), um die Bereitstellung zu verwalten. Die direkte Ausführung von `docker compose up`, `docker compose down` oder `docker compose restart` **entsiegelt Vault nicht**, sodass abhängige Dienste nicht starten können. Das `start.sh`-Skript übernimmt die Vault-Entsiegelung automatisch.

### Vault-Siegelverhalten

**Vault wird versiegelt**, wenn sein Container neu startet. Dies ist ein Sicherheitsmerkmal.

Das `start.sh`-Skript (und der Systemd-Dienst) entsiegeln Vault automatisch mit den in `secrets/vault-keys.json` gespeicherten Schlüsseln. Deshalb müssen Sie immer die bereitgestellten Skripte oder den Systemd-Dienst zur Verwaltung des Stacks verwenden.

## :warning: Zerstörerische Operationen (Daten gelöscht)

!!! warning
    Diese Befehle **LÖSCHEN ALLE DATEN** – mit Vorsicht verwenden!

    Sie können Daten nur wiederherstellen, wenn Sie vorher [Backup-Operationen](./Docker-advanced.md#manuelles-backup) durchführen und das Backup an einem sicheren Ort aufbewahren.

!!! danger
    Alles löschen (Volumes, Secrets, Konfiguration)

    ```bash
    ./scripts/purge.sh
    ```

## Skriptübersicht

| Skript | Zweck |
| -------- | -------- |
| `install.sh` | Erstinstallation (Docker, Vault). Domain-/Zertifikats-/Peer-Setup erfolgt anschließend im Dashboard. |
| `update.sh` | Service-Images aktualisieren (Vault-Token bleibt erhalten, Container werden neu erstellt) |
| `start.sh` | Dienste starten und Vault entsiegeln |
| `stop.sh` | Container anhalten (Daten bleiben erhalten) |
| `backup.sh` | Vollständiges Backup (Datenbank, Vault-Schlüssel, Konfiguration, Zertifikate) |
| `restore.sh` | Aus einem Backup-Archiv wiederherstellen (funktioniert auf neuem System) |
| `purge.sh` | :warning: ALLE Daten löschen (erfordert Bestätigung) |
| `health-check.sh` | Umfassende Gesundheitsprüfung aller Dienste (Exit 0 = gesund, 1 = Fehler) |
| `init-vault.sh` | Vault-Initialisierung (wird vom `vault-init`-Container verwendet, nicht direkt aufrufen) |
| `init-keycloak.sh` | Keycloak-Admin-Passwort-Setup (wird vom `keycloak-init`-Container verwendet, nicht direkt aufrufen) |
| `gather-app-versions.sh` | Sammelt App-Versionen von `/liveness`-Endpunkten für node-exporter (läuft im `version-collector`-Container) |

## Konfigurationsdateien

| Datei | Zweck |
| ------ | --------- |
| `customer-config-prod.example.sh` | Vorlage für Kundeneinstellungen (kopieren nach `customer-config.sh`) |
| `customer-config.sh` | Kundenspezifische Einstellungen (aus Vorlage erstellt, vor der Installation ausfüllen) |
| `.env` | Generierte Umgebungsdatei (wird von `install.sh` erstellt) |
| `secrets/vault-keys.json` | Vault-Entsiegelungsschlüssel und Root-Token (sicher sichern!) |
| `secrets/signing-key.csr` | Generierter CSR für das S/MIME-Zertifikat |

## Support

!!! tip "Support"

    Bei Fragen oder Problemen im Zusammenhang mit der Bereitstellung und dem Betrieb der Stargate-Appliance wenden Sie sich bitte an den HIN-Support.

    Bitte fügen Sie relevante Informationen wie den Kundennamen, die Appliance-Version und Screenshots/[Logs](./Docker-advanced.md#logs-an-den-support-senden) hinzu, um die Bearbeitung Ihres Anliegens zu beschleunigen.
