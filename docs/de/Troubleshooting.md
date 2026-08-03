# Troubleshooting und Diagnose

Eine strukturierte Anleitung zur Diagnose einer Stargate-Appliance über die Befehlszeile: Was überprüft werden muss, wo sich die Logs befinden und welche Massnahmen zur sicheren Wiederherstellung ergriffen werden können.

!!! info "Wo diese Befehle ausgeführt werden sollen"
    Führen Sie alle folgenden Befehle aus dem **Bereitstellungsverzeichnis** aus - dem Ordner, der `docker-compose.yml` und `scripts/` enthält (bei VM-Images ist dies in der Regel `/root/stargate-deployment/docker-compose`, oder das Verzeichnis, in dem Sie die Installation vorgenommen haben). Alle `docker compose`- und `./scripts/*`-Befehle gehen von diesem Arbeitsverzeichnis aus.

    ```bash
    cd /root/stargate-deployment/docker-compose   # adjust to your install path
    ```

---

## 1. Erster Schritt: der Health Check

Ein Befehl fasst die gesamte Appliance zusammen:

=== "Quick"

    ```bash
    ./scripts/health-check.sh
    ```

=== "Verbose"

    ```bash
    ./scripts/health-check.sh -v
    ```

Dieser meldet den Status «bestanden»/«nicht bestanden» (pass/fail) für: **Container** (running/healthy), **Liveness**-Endpunkte (smimekeys, policy, irisagent, mxengine), den **Vault**-Siegelstatus, die **PostgreSQL**-Konnektivität und -Datenbanken, **SeaweedFS**, den **WireGuard**-Tunnel und Peer-Handshakes, **Stalwart**-MTA (Ports 25 / 10026), **Prometheus**-Metrik-Endpunkte sowie **Festplatte/Arbeitsspeicher**.

!!! tip
    Führen Sie dies zuerst aus. Eine einzelne `FAIL`-Zeile führt Sie in der Regel direkt zum folgenden Abschnitt.

---

## 2. Wo sich die Logs befinden

| Ebene | Befehl | Was es anzeigt |
|-------|---------|---------------|
| Start / Erstinstallation / Autostart | `sudo journalctl -u stargate -n 200 --no-pager` | Den systemd-Dienst, der `start.sh` beim Start und bei der Erstinstallation ausführt |
| Updates | `cat ../update.log` (Bereitstellungsstammverzeichnis, eine Ebene über `docker-compose/`) | Ausgabe des letzten Dashboard-/Host-ausgelösten `update.sh` |
| Ein einzelner Dienst | `docker logs stargate-<service> --tail 100` | z. B. `stargate-dashboard`, `stargate-mxengine`, `stargate-keycloak` |
| Einen Dienst live verfolgen | `docker logs -f stargate-mxengine` | Echtzeit |
| Alle Container live | `docker ps -a --format '{{.Names}}' \| xargs -I{} sh -c 'docker logs --timestamps -f {} 2>&1 \| sed "s/^/[{}] /"'` | Zusammengeführt, mit Container als Präfix |
| Weblog-Viewer | Dozzle unter `https://<SERVER_IP>:8190` (Keycloak-Anmeldung) | Alle Container-Logs in einer Benutzeroberfläche anzeigen |

Um Logs an den HIN-Support zu übermitteln, verwenden Sie das Upload-Skript und leiten Sie den zurückgegebenen Link weiter - siehe **[Logs an den Support senden](Docker-advanced.md#provide-logs-to-support)**:

```bash
./scripts/send-logs-to-support.sh --all          # or --since 1h  / --tail 500
```

---

## 3. Container werden nicht ausgeführt oder starten neu

```bash
docker compose ps -a --format 'table {{.Service}}\t{{.Status}}'
```

Lesen Sie die Spalte `Status`:

| Status | Bedeutung | Massnahme |
|--------|---------|--------|
| `Up ... (healthy)` | Läuft einwandfrei | - |
| `Up ...` (no health) | Läuft; kein Health Check definiert | Überprüfen Sie die `docker logs`, wenn Sie Probleme vermuten |
| `Restarting` | Crash-Looping | `docker logs stargate-<svc>` - beheben Sie den Root-Fehler (config, secret, dependency) |
| `Exited (0)` | Die einmalige Initialisierung wurde erfolgreich abgeschlossen (z. B. `*-init`, `vault-data-fixer`) | Normal |
| `Exited (1+)` | Fehlgeschlagen | `docker logs stargate-<svc>` - die letzten Zeilen zeigen, warum |
| `Created` | Wurde nie gestartet - eine Abhängigkeit ist nicht hochgekommen | Überprüfen Sie, wovon es abhängt (`depends_on`, in der Regel Postgres/Vault); das zuerst beheben |

Einen einzelnen Dienst neu starten (sicher, ohne Datenverlust):

```bash
docker compose up -d <service>          # recreate one service
docker compose restart <service>        # just restart it
```

!!! note "Startreihenfolge"
    Dienste warten auf ihre Abhängigkeiten (`depends_on` + Health Checks). Bei einem vollständigen Neustart sind kurze Zeilen wie `connection refused` / `database system is starting up` während des Hochfahrens von Postgres/Vault **normal** und verschwinden innerhalb einer Minute.

---

## 4. Diagnose anhand der Symptome

### Dashboard oder Keycloak wird nicht geladen / Anmeldung nicht möglich

- Beide laufen über Caddy: **Dashboard** auf `:443`, **Keycloak** auf `:8180`.
- Überprüfen Sie die Kette: `docker logs stargate-caddy`, `stargate-dashboard`, `stargate-keycloak`, `stargate-apisix`.
- Keycloak muss **betriebsbereit** (healthy) sein, bevor das Dashboard funktioniert: `docker compose ps keycloak`.
- Eine TLS-Warnung im Browser ist zu erwarten (selbstsigniertes Zertifikat) - akzeptieren Sie diese und fahren Sie fort.
- Fehlgeschlagene Weiterleitungen bei der Anmeldung deuten in der Regel darauf hin, dass die öffentliche URL nicht mit der Adresse übereinstimmt, über die Sie auf den Host zugreifen - überprüfen Sie, dass `KEYCLOAK_PUBLIC_URL` / `DASHBOARD_PUBLIC_URL` in `.env` auf die IP-Adresse bzw. den Host verweisen, die bzw. den Sie tatsächlich verwenden.

### WireGuard-Tunnel ausgefallen / Zertifikatsausstellung fehlgeschlagen

Das ist das häufigste Problem - **Zertifikate schlagen fehl, wenn der Tunnel nicht verfügbar ist**, daher sollten Sie immer zuerst das Problem mit dem Tunnel beheben.

```bash
./scripts/health-check.sh -v      # shows WireGuard peer + handshake status
docker logs stargate-irisagent | grep -iE "handshake|peer|cert|wireguard"
```

- Stellen Sie sicher, dass die Firewall **`19818` (UDP *und* TCP)** eingehend/ausgehend zulässt.
- Überprüfen Sie, dass der Peer auf HIN-Seite registriert ist (Support-Schritt) - Sie stellen den öffentlichen WG-Schlüssel, `DEPLOYMENT_NAME`, `SERVER_STATIC_IP`, `WG_INTERFACE_PORT` bereit.
- Sobald der Tunnel einen aktuellen Handshake anzeigt, versuchen Sie die Zertifikatsausstellung erneut über das Dashboard.

### Vault versiegelt oder Initialisierung fehlgeschlagen

```bash
docker compose exec vault vault status        # look for "Sealed: false"
docker logs stargate-vault-init
```

- Der Vault muss **entsiegelt** sein, damit smimekeys/mxengine/policy funktionieren. Die Schlüssel befinden sich in `secrets/vault-keys.json`.
- Falls `vault-init` mit einem Ergebnis ungleich Null beendet wurde, fehlt die Schlüsseldatei möglicherweise oder ist beschädigt - überprüfen Sie deren Logs; ein erneuter Aufruf von `./scripts/init-vault.sh` versucht die Entsiegelung erneut.

!!! danger "`secrets/vault-keys.json` nicht löschen"
    Dieses zu verlieren, bedeutet, den Zugriff auf alle gespeicherten Secrets zu verlieren. Erstellen Sie ein Backup.

### PostgreSQL / Datenbankanbindung

```bash
docker compose exec postgres pg_isready -U postgres
docker logs stargate-postgres --tail 50
```

- Eine vorübergehende Meldung `the database system is starting up (57P03)` unmittelbar nach einem Neustart ist normal - die Dienste stellen die Verbindung automatisch wieder her.
- Anhaltende Authentifizierungsfehler deuten in der Regel darauf hin, dass `POSTGRES_PASSWORD` in `.env` vom Datenvolumen abgewichen ist - siehe die Hinweise zu Update/Secrets, und vermeiden Sie es, diese Datei manuell zu bearbeiten.

### E-Mails werden nicht zugestellt

- **Eingehende** E-Mails treffen auf **`:25`** (Stalwart) ein. Viele Cloud-Anbieter **blockieren Port 25** standardmässig:

    ```bash
    nc -zv <this-server-ip> 25          # from an external host
    docker logs stargate-stalwart --tail 100
    ```

    Falls `25` blockiert ist, beantragen Sie eine Ausnahmegenehmigung bei Ihrem Anbieter.
- **Ausgehend/Sealing** läuft über Stalwart → **mxengine** (`:8084` Seal-Callback, SMTP `:1587`): `docker logs stargate-mxengine`.
- **Mail-Schleifen** zeigen sich als dieselbe, immer wiederkehrende Nachricht - stellen Sie sicher, dass der MX-Eintrag Ihrer Domain nicht auf die eigene IP-Adresse dieser Appliance verweist.
- Siehe **[Mail-Relay-Einrichtung](Mail-relay-setup.md)** und **[DNS-Einrichtung](DNS-setup.md)** für das vorgesehene Routing.

### Ein Update ist fehlgeschlagen

```bash
docker logs stargate-ops-agent --tail 40      # the update orchestrator
cat ../update.log                             # the update script output
```

- Der Ops-Agent ruft das Release-Manifest ab, schreibt die Versionen in `customer-config.sh` und führt anschliessend `update.sh` auf dem Host aus.
- Bestätigen Sie nach Abschluss die angewendeten Versionen: `./scripts/gather-app-versions.sh` (oder überprüfen Sie die Image-Tags mit `docker compose ps`).
- Wenn ein Dienst nach einem Update hängen bleibt: `docker compose up -d <service>`, um ihn neu zu erstellen.

**Das Update startet, aber es passiert nichts (Update von einer älteren Version).** Wenn das Ops-Agent-Log bei `pulling deployment repo ...` stehen bleibt und das Update nicht fortgesetzt wird, enthält das Repository auf der VM höchstwahrscheinlich **lokale Änderungen an einer versionierten Datei** (meist eine manuell bearbeitete `docker-compose.yml`). Dadurch verweigert der `git checkout` des Ops-Agent die Ausführung, sodass das Update stehen bleibt. Setzen Sie das Repository zwangsweise auf den neuesten Stand zurück und führen Sie das Update anschliessend erneut aus. Git ist die einzige verbindliche Quelle; dabei gehen ausschliesslich lokale Änderungen an **versionierten** Dateien verloren - `customer-config.sh`, `.env` und `secrets/` stehen in der `.gitignore` und bleiben erhalten:

```bash
cd /root/stargate-deployment
git fetch origin
git checkout -f main
git reset --hard origin/main
sed -i 's/^OPS_AGENT_VERSION=.*/OPS_AGENT_VERSION="v0.0.3"/' docker-compose/customer-config.sh   # v0.0.3 or newer
cd docker-compose
./scripts/update.sh
```

`update.sh` erzeugt die `.env` neu, lädt die Images und erstellt die betroffenen Dienste neu - Sie müssen Stargate **nicht** manuell neu starten. Sobald der Vorgang abgeschlossen ist, starten Sie das Update erneut über das Dashboard; es wird nun fortgesetzt.

!!! warning
    Verwenden Sie hier nicht `git pull`. Bei einem Arbeitsverzeichnis mit lokalen Änderungen bricht dieser Befehl mit der Meldung "local changes would be overwritten" ab, was einen Umweg über `git stash`, Merge-Konflikte oder eine manuelle Wiederherstellung erzwingt. Die obige Abfolge aus `git checkout -f` und `git reset --hard` vermeidet das vollständig und ist die sichere, wiederholbare Methode, um das Repository auf den aktuellen Stand zu bringen.

### Dozzle (Log-Viewer) nicht erreichbar

- Die URL lautet `https://<SERVER_IP>:8190`; erforderlich ist eine **Keycloak-Anmeldung** (derselbe Realm wie das Dashboard) über oauth2-proxy.
- Läuft nur, wenn `DOZZLE_ENABLED="true"`. Überprüfen: `docker compose ps dozzle oauth2-proxy`.
- Stellen Sie sicher, dass die Firewall **`:8190`** eingehend zulässt. Siehe **[Überwachung und Logs](Monitoring.md)**.

---

## 5. Speicher und Festplatte

```bash
df -h /                              # is the disk full?
docker system df                     # space used by images / containers / volumes
du -sh /var/lib/docker/volumes/*     # per-volume usage (Postgres, SeaweedFS, Loki, ...)
```

- Container-Logs sind begrenzt (json-file, 100 MB × 5 pro Container) und sollten die Festplatte daher nicht füllen, Images und Volumes hingegen können das.
- Speicherplatz sicher zurückgewinnen: `docker image prune -af` (entfernt nur nicht verwendete Images). Vermeiden Sie `docker system prune --volumes` - dadurch werden Daten-Volumes gelöscht.
- Objektspeicher ist **SeaweedFS** (`stargate-seaweedfs`): `docker logs stargate-seaweedfs --tail 50`.

---

## 6. VM-Ressourcen

```bash
free -h                              # memory (min 8 GB)
nproc                                # CPUs (min 4)
docker stats --no-stream             # per-container CPU/RAM
uptime                               # load average
```

Host-Metriken werden zudem für Prometheus unter **`:9100/metrics`** exportiert (siehe [Überwachung](Monitoring.md#prometheus-metriken)). Wenn der Host swappt oder ausgelastet ist, ist damit zu rechnen, dass Health Checks instabil werden und Updates sich verlangsamen.

---

## 7. Netzwerk und Ports

Schnelle Erreichbarkeitsprüfung für die wichtigsten eingehenden Ports:

```bash
for p in 25 443 8180 8190 8084 19818; do nc -zv <this-server-ip> $p; done
```

| Port | Dienst | Richtung |
|------|---------|-----------|
| `25` | Stalwart SMTP (eingehende E-Mails) | eingehend |
| `443` | Dashboard (HTTPS) | eingehend |
| `8180` | Keycloak | eingehend |
| `8190` | Dozzle (optional) | eingehend |
| `8084` | mxengine Seal-Callback | eingehend |
| `19818` | WireGuard (UDP **und** TCP) | ein-/ausgehend |

Ausgehender Zugriff wird benötigt auf die Container-Registry, die S/MIME-Zertifizierungsstelle (über den WireGuard-Tunnel) und jedes konfigurierte Remote-Loki. Die vollständige Port-Tabelle finden Sie auf der **[Startseite](index.md)** und in der **[Anwendungsübersicht](Applications.md)**.

---

## 8. Wiederherstellungsmassnahmen

Geordnet vom am wenigsten bis zum stärksten störenden Eingriff:

```bash
docker compose up -d <service>       # recreate one stuck service
sudo systemctl restart stargate      # restart the whole stack (via start.sh)
./scripts/stop.sh  &&  ./scripts/start.sh
```

!!! warning "Backups & destruktive Wiederherstellung"
    `./scripts/backup.sh` und `./scripts/restore.sh` übernehmen Datensicherung/-wiederherstellung. `./scripts/purge.sh` **löscht alle Daten** (Datenbanken, Vault, Storage) für eine saubere Neuinstallation - nur als letztes Mittel und nur mit einem aktuellen Backup verwenden. Details: [Docker erweiterte Konfiguration](Docker-advanced.md).

---

## 9. Wann Sie sich an den Support wenden sollten

Zeigt der Health Check nach den obigen Schritten weiterhin Fehler an, eröffnen Sie ein Ticket über **[Support / Kontakt](Support.md)** und geben Sie Folgendes an:

- Die **Appliance-Version** (`./scripts/gather-app-versions.sh`) und den **Kundennamen**.
- Die **Health-Check-Ausgabe** (`./scripts/health-check.sh -v`).
- Einen **Log-Bundle-Link** von `./scripts/send-logs-to-support.sh` (siehe [Logs an den Support senden](Docker-advanced.md#provide-logs-to-support)).
- Was Sie taten, als das Problem auftrat, sowie etwaige Screenshots.

## Verimesh-Instanz aktualisieren

Die folgenden Anweisungen beschreiben, wie Sie eine Verimesh-Instanz von v0.5.1 auf v0.5.3 aktualisieren.

*Hinweis:* Sie müssen sich mit dem Linux-Administratorkonto auf der VM anmelden.

### Update-Schritte
1. Bearbeiten Sie die .env-Datei und aktualisieren Sie die Ops-Agent-Version auf v0.0.3.
2. Bearbeiten Sie die Kundenkonfiguration und aktualisieren Sie dort ebenfalls die Ops-Agent-Version auf v0.0.3.
3. Wechseln Sie zum Main-Branch: `git checkout main`
4. Rufen Sie die neuesten Änderungen ab: `git pull`
5. Aktualisieren Sie den Ops-Agent-Container: `docker compose up -d ops-agent`
6. Melden Sie sich im Dashboard an.
6. Navigieren Sie zu Settings.
7. Geben Sie im Abschnitt Update am Seitenende die Zielversion (v0.5.3) ein und starten Sie den Update-Vorgang.


## Aktualisierte Keycloak einrichten

Hinweis: Diese Anleitung gilt, wenn Sie auf VM-Image v0.5.1 laufen und dann auf eine neuere Version aktualisiert haben.

Nach dem letzten Keycloak-Update führt eine breaking change dazu, dass authentifizierte Benutzer beim Aufrufen bestimmter Anwendungsrouten (z. B. Peers, Peer Certificates) unerwartet auf die Anmeldeseite umgeleitet werden.

Zur Behebung muss die folgende manuelle Konfiguration in der *Keycloak-UI* vorgenommen werden.

### Lösungsschritte

1. Öffnen Sie Keycloak in der Umgebung und geben Sie die URL ein - `<VM IP address>/admin/master/console/`
    Benutzer: Admin
    Passwort: das Admin-Passwort aus der .env der Maschine entnehmen (dazu müssen Sie sich an der Linux-Konsole anmelden)

2. Admin-Konsole - Realm wechseln zu → Realm stargate:
3. Zu Clients → dashboard wechseln
4. Zur Registerkarte Client scopes wechseln → auf dashboard-dedicated klicken
5. Configure a new mapper wählen → Audience
6. Folgende Einstellungen vornehmen:
    * Name: apisix-audience
    * Included client audience: apisix (aus dem Dropdown auswählen)
    * Included custom audience: (leer lassen)
    * Add to access token: On
    * Add to token introspection: On
    * Add to ID token / lightweight token: Off

7. Auf Save klicken

 <br> ![keycloak-console](assets/troubleshooting/keycloak-update.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
