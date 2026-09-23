# Troubleshooting und Diagnose

Eine strukturierte Anleitung zur Diagnose einer Stargate-Appliance über die Befehlszeile: was Sie prüfen sollten, wo sich die Logs befinden und welche Wiederherstellungsmassnahmen sicher sind.

!!! info "Wo sich die Skripte befinden"
    Die Hilfsskripte liegen im Bereitstellungsverzeichnis unter `scripts/`. Die folgenden Befehle verwenden den **vollständigen Pfad für VM-Images**: `/usr/share/stargate-deployment/docker-compose/scripts/`. Wenn Sie an einem anderen Ort installiert haben, ersetzen Sie ihn durch Ihr eigenes Installationsverzeichnis (den Ordner, der `docker-compose.yml` und `scripts/` enthält).

    `docker compose ...`-Befehle müssen **aus dem Bereitstellungsverzeichnis** ausgeführt werden:

    ```bash
    cd /usr/share/stargate-deployment/docker-compose   # adjust to your install path
    ```

!!! info "Wo sich die beschreibbaren Daten befinden"
    Der obige `docker-compose/`-Verzeichnisbaum (Skripte, `docker-compose.yml`, Konfigurationsvorlagen) ist **zur Laufzeit schreibgeschützt**. Alle beschreibbaren Daten liegen stattdessen unter **`/var/data`**: `.env`, `customer-config.sh`, `secrets/`, die generierte TLS-, Keycloak- und APISIX-Konfiguration, Backups sowie die eigenen Daten jedes Dienstes (`STARGATE_DATA_DIR` überschreibt dieses Stammverzeichnis für Tests). Im Einzelnen: Konfiguration und Secrets liegen unter `/var/data/vereign/`, Backups unter `/var/data/backups/` und das Update-Log unter `/var/data/vereign/update.log`. Die vollständige Übersicht finden Sie unter [Docker erweiterte Konfiguration](Docker-advanced.md). Verwenden Sie bevorzugt die Wrapper-Skripte (`./scripts/start.sh`, `./scripts/update.sh`, ...) statt eines blossen `docker compose up -d`, das `/var/data/vereign/.env` nicht von selbst einliest.

---

## 1. Erster Schritt: der Health Check

Ein einziger Befehl gibt einen Überblick über die gesamte Appliance:

=== "Quick"

    ```bash
    /usr/share/stargate-deployment/docker-compose/scripts/health-check.sh
    ```

=== "Verbose"

    ```bash
    /usr/share/stargate-deployment/docker-compose/scripts/health-check.sh -v
    ```

Er meldet «bestanden» oder «fehlgeschlagen» für: **Container** (running/healthy), **Liveness**-Endpunkte (smimekeys, policy, irisagent, mxengine), den **Vault**-Siegelstatus, die **PostgreSQL**-Verbindung und -Datenbanken, **SeaweedFS**, den **WireGuard**-Tunnel und die Peer-Handshakes, den **Stalwart**-MTA (Ports 25 / 10026), die **Prometheus**-Metrik-Endpunkte sowie **Festplatte und Arbeitsspeicher**.

!!! tip
    Führen Sie diesen Befehl zuerst aus. Eine einzelne `FAIL`-Zeile führt Sie in der Regel direkt zum passenden Abschnitt weiter unten.

---

## 2. Wo sich die Logs befinden

| Ebene | Befehl | Was angezeigt wird |
| ------- | --------- | --------------- |
| Systemstart / Erstinstallation / Autostart | `sudo journalctl -u stargate -n 200 --no-pager` | Der systemd-Dienst, der `start.sh` beim Systemstart ausführt, sowie die Installation beim ersten Start |
| Update-Läufe | `cat /var/data/vereign/update.log` | Ausgabe des letzten über das Dashboard oder den Host ausgelösten `update.sh` |
| Ein einzelner Dienst | `docker logs stargate-<service> --tail 100` | z. B. `stargate-dashboard`, `stargate-mxengine`, `stargate-keycloak` |
| Einen Dienst live verfolgen | `docker logs -f stargate-mxengine` | Echtzeit |
| Alle Container live | `docker ps -a --format '{{.Names}}' \| xargs -I{} sh -c 'docker logs --timestamps -f {} 2>&1 \| sed "s/^/[{}] /"'` | Zusammengeführt, mit dem Containernamen als Präfix |
| Web-Log-Viewer | Dozzle unter `https://<SERVER_IP>:8190` (Keycloak-Anmeldung) | Alle Container-Logs in einer Weboberfläche durchsuchen |

Um Logs an den HIN-Support zu übermitteln, verwenden Sie das Upload-Skript: Es sammelt die letzten N Log-Zeilen **aller** Dienste (zusammen mit Host- und Versionsinformationen), lädt sie hoch und gibt einen Link aus, den Sie weitergeben können. Siehe **[Logs an den Support senden](Docker-advanced.md#logs-an-den-support-senden)**:

```bash
/usr/share/stargate-deployment/docker-compose/scripts/send-logs-to-support.sh --tail 5000     # last 5000 lines from each service
# other options:  --since 1h   |   --until 5m   |   --all   (no argument = --tail 500)
```

Der Upload ist auf 20 MB begrenzt. Verwenden Sie auf einer stark ausgelasteten Appliance daher besser `--tail`/`--since` statt `--all`.

---

## 3. Container laufen nicht oder starten ständig neu

```bash
docker compose ps -a --format 'table {{.Service}}\t{{.Status}}'
```

Prüfen Sie die Spalte `Status`:

| Status | Bedeutung | Massnahme |
| -------- | --------- | -------- |
| `Up ... (healthy)` | Läuft einwandfrei | - |
| `Up ...` (ohne Health-Status) | Läuft; kein Health Check definiert | Prüfen Sie die `docker logs`, wenn Sie ein Problem vermuten |
| `Restarting` | Absturzschleife | `docker logs stargate-<svc>`: Beheben Sie die eigentliche Fehlerursache (Konfiguration, Secret, Abhängigkeit) |
| `Exited (0)` | Einmalige Initialisierung erfolgreich abgeschlossen (z. B. `*-init`, `vault-data-fixer`) | Normal |
| `Exited (1+)` | Fehlgeschlagen | `docker logs stargate-<svc>`: Die letzten Zeilen zeigen den Grund |
| `Created` | Nie gestartet, da eine Abhängigkeit nicht hochgefahren ist | Prüfen Sie, wovon der Dienst abhängt (`depends_on`, in der Regel Postgres/Vault), und beheben Sie zuerst dieses Problem |

Einen einzelnen Dienst neu starten (sicher, ohne Datenverlust):

```bash
docker compose up -d <service>          # recreate one service
docker compose restart <service>        # just restart it
```

!!! note "Startreihenfolge"
    Dienste warten auf ihre Abhängigkeiten (`depends_on` + Health Checks). Bei einem vollständigen Neustart sind kurze Meldungen wie `connection refused` / `database system is starting up`, während Postgres und Vault hochfahren, **normal** und verschwinden innerhalb einer Minute.

---

## 4. Diagnose anhand der Symptome

### Dashboard oder Keycloak lädt nicht / Anmeldung nicht möglich

- Beide laufen hinter Caddy: das **Dashboard** auf `:443`, **Keycloak** auf `:8180`.
- Prüfen Sie die gesamte Kette: `docker logs stargate-caddy`, `stargate-dashboard`, `stargate-keycloak`, `stargate-apisix`.
- Keycloak muss **healthy** sein, bevor das Dashboard funktioniert: `docker compose ps keycloak`.
- Eine TLS-Warnung im Browser ist zu erwarten (selbstsigniertes Zertifikat): Akzeptieren Sie sie und fahren Sie fort.
- Fehlgeschlagene Weiterleitungen bei der Anmeldung bedeuten in der Regel, dass die öffentliche URL nicht mit der Adresse übereinstimmt, über die Sie die Appliance erreichen. Prüfen Sie, ob `KEYCLOAK_PUBLIC_URL` / `DASHBOARD_PUBLIC_URL` in `.env` auf die IP-Adresse bzw. den Host verweisen, den Sie tatsächlich verwenden.

### WireGuard-Tunnel ausgefallen / Zertifikatsausstellung schlägt fehl

Dies ist das häufigste Problem: **Zertifikate lassen sich nicht ausstellen, wenn der Tunnel ausgefallen ist**. Beheben Sie deshalb immer zuerst das Tunnelproblem.

```bash
/usr/share/stargate-deployment/docker-compose/scripts/health-check.sh -v      # shows WireGuard peer + handshake status
docker logs stargate-irisagent | grep -iE "handshake|peer|cert|wireguard"
```

- Stellen Sie sicher, dass die Firewall **`19818` (UDP *und* TCP)** eingehend und ausgehend zulässt.
- Prüfen Sie, ob der Peer auf HIN-Seite registriert ist (Schritt durch den Support). Sie liefern dafür den öffentlichen WG-Schlüssel, `DEPLOYMENT_NAME`, `SERVER_STATIC_IP` und `WG_INTERFACE_PORT`.
- Sobald der Tunnel einen aktuellen Handshake anzeigt, starten Sie die Zertifikatsausstellung erneut über das Dashboard.

### Vault versiegelt oder Initialisierung fehlgeschlagen

```bash
docker compose exec vault vault status        # look for "Sealed: false"
docker logs stargate-vault-init
```

- Vault muss **entsiegelt** sein, damit smimekeys, mxengine und policy funktionieren. Die Schlüssel liegen in `/var/data/vereign/secrets/vault-keys.json`.
- Wenn `vault-init` mit einem Exit-Code ungleich null beendet wurde, fehlt die Schlüsseldatei möglicherweise oder ist beschädigt. Prüfen Sie die Logs dieses Containers; ein erneuter Aufruf von `/usr/share/stargate-deployment/docker-compose/scripts/init-vault.sh` versucht die Entsiegelung erneut.

!!! danger "`/var/data/vereign/secrets/vault-keys.json` nicht löschen"
    Geht diese Datei verloren, verlieren Sie den Zugriff auf alle gespeicherten Secrets. Bewahren Sie ein Backup auf.

### PostgreSQL / Datenbankverbindung

```bash
docker compose exec postgres pg_isready -U postgres
docker logs stargate-postgres --tail 50
```

- Eine vorübergehende Meldung `the database system is starting up (57P03)` unmittelbar nach einem Neustart ist normal: Die Dienste verbinden sich automatisch neu.
- Anhaltende Authentifizierungsfehler bedeuten in der Regel, dass `POSTGRES_PASSWORD` in `.env` nicht mehr mit dem Datenvolume übereinstimmt. Beachten Sie die Hinweise zu Updates und Secrets und bearbeiten Sie diesen Wert nicht von Hand.

### E-Mails werden nicht zugestellt

- **Eingehende** E-Mails kommen auf **`:25`** (Stalwart) an. Viele Cloud-Anbieter **sperren Port 25** standardmässig:

    ```bash
    nc -zv <this-server-ip> 25          # from an external host
    docker logs stargate-stalwart --tail 100
    ```

    Wenn `25` gesperrt ist, beantragen Sie bei Ihrem Anbieter eine Freigabe.
- **Ausgehende E-Mails und Sealing** laufen über Stalwart → **mxengine** (`:8084` Seal-Callback, SMTP `:1587`): `docker logs stargate-mxengine`.
- **Mail-Schleifen** erkennen Sie daran, dass dieselbe Nachricht immer wieder zirkuliert. Prüfen Sie, ob der MX-Eintrag Ihrer Domain nicht auf die IP-Adresse dieser Appliance selbst zurückverweist.
- Das vorgesehene Routing ist unter **[Mail-Relay-Einrichtung](Mail-relay-setup.md)** und **[DNS-Einrichtung](DNS-setup.md)** beschrieben.

### Ein Update ist fehlgeschlagen

```bash
docker logs stargate-ops-agent --tail 40      # the update orchestrator
cat /var/data/vereign/update.log              # the update script output
```

- Der Ops-Agent checkt den Tag des Ziel-Releases aus (dessen `docker-compose.yml` die Image-Versionen festlegt) und führt anschliessend `update.sh` auf dem Host aus.
- Prüfen Sie nach Abschluss, ob die Versionen übernommen wurden: `/usr/share/stargate-deployment/docker-compose/scripts/gather-app-versions.sh` (oder die Image-Tags in `docker compose ps`).
- Hängt ein Dienst nach einem Update, erstellen Sie ihn mit `docker compose up -d <service>` neu.

**Das Update startet, aber nichts passiert (Update von einer älteren Version).** Bleibt das Ops-Agent-Log bei `pulling deployment repo ...` stehen und geht das Update nicht weiter, enthält das Repository auf der VM höchstwahrscheinlich **lokale Änderungen an einer versionierten Datei** (meist eine von Hand angepasste `docker-compose.yml`). Dadurch verweigert der `git checkout` des Ops-Agents die Ausführung, und das Update bleibt stehen. Setzen Sie das Repository zwangsweise auf den neuesten Stand zurück und führen Sie das Update anschliessend erneut aus. Git ist die einzige verbindliche Quelle; dabei gehen ausschliesslich lokale Änderungen an **versionierten** Dateien verloren. `customer-config.sh`, `.env` und `secrets/` liegen unter `/var/data/vereign/`, also ausserhalb des Repository-Checkouts, und bleiben immer erhalten:

```bash
cd /usr/share/stargate-deployment
git fetch origin
git checkout -f main
git reset --hard origin/main
cd docker-compose
/usr/share/stargate-deployment/docker-compose/scripts/update.sh
```

`update.sh` erzeugt `.env` neu, lädt die Images herunter und erstellt die betroffenen Dienste neu. Sie müssen Stargate **nicht** manuell neu starten. Starten Sie nach Abschluss das Update erneut über das Dashboard; es läuft nun durch.

!!! warning
    Verwenden Sie hier nicht `git pull`. In einem Arbeitsverzeichnis mit lokalen Änderungen bricht der Befehl mit der Meldung «local changes would be overwritten» ab und zwingt Sie zu einem Umweg über `git stash`, Merge-Konflikte oder eine manuelle Wiederherstellung. Die obige Abfolge aus `git checkout -f` und `git reset --hard` vermeidet das vollständig und ist der sichere, wiederholbare Weg, das Repository auf den aktuellen Stand zu bringen.

### Dozzle (Log-Viewer) nicht erreichbar

- Die URL lautet `https://<SERVER_IP>:8190`; erforderlich ist eine **Keycloak-Anmeldung** (derselbe Realm wie beim Dashboard) über oauth2-proxy.
- Dozzle läuft nur, wenn `DOZZLE_ENABLED="true"` gesetzt ist. Prüfen: `docker compose ps dozzle oauth2-proxy`.
- Stellen Sie sicher, dass die Firewall **`:8190`** eingehend zulässt. Siehe **[Überwachung und Logs](Monitoring.md)**.

### Onboarding: Die Eingabe des Aktivierungscodes führt zu einem Fehler

Wird der Aktivierungscode abgelehnt, prüfen Sie der Reihe nach:

- **Falscher Code**: Der Code wurde nicht vollständig kopiert (abgeschnitten beim Kopieren, ein zusätzliches Leerzeichen oder ein fehlendes Zeichen). Kopieren Sie den vollständigen Code erneut und geben Sie ihn nochmals ein.
- **Code bereits verwendet**: Der Code wurde bereits bei einem früheren Onboarding eingelöst. Fordern Sie einen neuen Code an.
- **WireGuard / Verbindung zu HIN**: Der `irisagent`-Tunnel steht nicht, deshalb kann der Code nicht bei HIN validiert werden. Siehe oben *WireGuard-Tunnel ausgefallen* (`/usr/share/stargate-deployment/docker-compose/scripts/health-check.sh -v`, `docker logs stargate-irisagent`).
- **Keine Domain mit der Registrierung verknüpft**: Mit der HIN-Registrierung des Kunden ist keine Domain verknüpft, es gibt also nichts zu aktivieren. Dies wird auf HIN-Seite behoben.

### Onboarding: Aktivierungscode akzeptiert, aber es werden keine Domains angezeigt

**Wahrscheinlichste Ursache: Der WireGuard-Tunnel ist nicht aufgebaut**, meist wegen einer **falschen öffentlichen IP-Adresse** oder eines **nicht geöffneten Firewall-Ports**. Ohne Tunnel kann die Appliance die Domainliste nicht von HIN abrufen.

- Prüfen Sie, ob `SERVER_STATIC_IP` in `customer-config.sh` mit der tatsächlichen öffentlichen IP-Adresse übereinstimmt.
- Stellen Sie sicher, dass **`19818` (UDP *und* TCP)** eingehend und ausgehend offen ist.
- Stellen Sie sicher, dass der Peer auf HIN-Seite für diese IP-Adresse registriert ist (Schritt durch den Support).
- `docker logs stargate-irisagent` sollte einen aktuellen Handshake zeigen. Falls nicht, beheben Sie zuerst das Tunnelproblem (siehe oben *WireGuard-Tunnel ausgefallen*).

### Server-IP-Adresse ändern (nur bei der Ersteinrichtung)

War die Server-IP-Adresse beim ersten Start falsch oder nicht gesetzt, setzen Sie das System sauber zurück und installieren Sie es neu:

```bash
/usr/share/stargate-deployment/docker-compose/scripts/purge.sh                 # destroys ALL data - see warning below
nano /var/data/vereign/customer-config.sh    # set SERVER_STATIC_IP=<NEW IP>
/usr/share/stargate-deployment/docker-compose/scripts/install.sh
```

Das TLS-Zertifikat und mehrere Dienst-URLs werden beim ersten Start aus der IP-Adresse abgeleitet. Purge und Neuinstallation erzeugen sie daher für die neue Adresse neu.

!!! danger "Nur vor dem Onboarding"
    `purge.sh` **löscht alle Daten unwiderruflich**: Datenbanken, Vault und die S/MIME-Schlüssel. Dies ist **nur auf einer neuen, noch nicht onboardeten Appliance** sicher. **Führen Sie `purge.sh` niemals aus, um die IP-Adresse eines produktiven oder bereits onboardeten Gateways zu ändern**: Das führt zu Datenverlust und zu E-Mails, die sich nicht mehr entschlüsseln lassen. Für eine IP-Änderung im Produktivbetrieb wenden Sie sich an den Support.

---

## 5. Speicher und Festplatte

```bash
df -h /                              # is the disk full?
docker system df                     # space used by images / containers / volumes
du -sh /var/lib/docker/volumes/*     # per-volume usage (Postgres, SeaweedFS, Loki, ...)
```

- Container-Logs sind begrenzt (json-file, 100 MB × 5 pro Container) und sollten die Festplatte daher nicht füllen; Images und Volumes hingegen können das.
- Speicherplatz sicher freigeben: `docker image prune -af` (entfernt nur nicht verwendete Images). Vermeiden Sie `docker system prune --volumes`, denn dieser Befehl löscht Daten-Volumes.
- Als Objektspeicher dient **SeaweedFS** (`stargate-seaweedfs`): `docker logs stargate-seaweedfs --tail 50`.

---

## 6. VM-Ressourcen

```bash
free -h                              # memory (min 8 GB)
nproc                                # CPUs (min 4)
docker stats --no-stream             # per-container CPU/RAM
uptime                               # load average
```

Host-Metriken werden zudem für Prometheus unter **`:9100/metrics`** exportiert (siehe [Überwachung](Monitoring.md#prometheus-metriken)). Wenn der Host swappt oder voll ausgelastet ist, müssen Sie mit schwankenden Health Checks und langsamen Updates rechnen.

---

## 7. Netzwerk und Ports

Schnelle Erreichbarkeitsprüfung der wichtigsten eingehenden Ports:

```bash
for p in 25 443 8180 8190 19818; do nc -zv <this-server-ip> $p; done
```

| Port | Dienst | Richtung |
| ------ | --------- | ----------- |
| `25` | Stalwart SMTP (eingehende E-Mails) | eingehend |
| `443` | Dashboard (HTTPS) | eingehend |
| `8180` | Keycloak | eingehend |
| `8190` | Dozzle (optional) | eingehend |
| `19818` | WireGuard (UDP **und** TCP) | ein- und ausgehend |

Ausgehender Zugriff ist erforderlich auf die Container-Registry, die S/MIME-Zertifizierungsstelle (über den WireGuard-Tunnel) und jede von Ihnen konfigurierte Remote-Loki-Instanz. Die vollständige Port-Tabelle finden Sie auf der **[Startseite](index.md)** und in der **[Anwendungsübersicht](Applications.md)**.

---

## 8. Wiederherstellungsmassnahmen

Geordnet vom geringsten bis zum stärksten Eingriff:

```bash
docker compose up -d <service>       # recreate one stuck service
sudo systemctl restart stargate      # restart the whole stack (via start.sh)
/usr/share/stargate-deployment/docker-compose/scripts/stop.sh  &&  /usr/share/stargate-deployment/docker-compose/scripts/start.sh
```

!!! warning "Backups und destruktive Wiederherstellung"
    `/usr/share/stargate-deployment/docker-compose/scripts/backup.sh` und `/usr/share/stargate-deployment/docker-compose/scripts/restore.sh` übernehmen die Datensicherung und -wiederherstellung. `/usr/share/stargate-deployment/docker-compose/scripts/purge.sh` **löscht alle Daten** (Datenbanken, Vault, Speicher) für eine saubere Neuinstallation. Verwenden Sie das Skript nur als letztes Mittel und nur mit einem aktuellen Backup. Details: [Docker erweiterte Konfiguration](Docker-advanced.md).

---

## 9. Wann Sie sich an den Support wenden sollten

Zeigt der Health Check nach den obigen Schritten weiterhin Fehler an, eröffnen Sie ein Ticket über **[Support / Kontakt](Support.md)** und fügen Sie Folgendes bei:

- Die **Appliance-Version** (`/usr/share/stargate-deployment/docker-compose/scripts/gather-app-versions.sh`) und den **Kundennamen**.
- Die **Ausgabe des Health Checks** (`/usr/share/stargate-deployment/docker-compose/scripts/health-check.sh -v`).
- Einen Link zum **Log-Paket** aus `/usr/share/stargate-deployment/docker-compose/scripts/send-logs-to-support.sh` (siehe [Logs an den Support senden](Docker-advanced.md#logs-an-den-support-senden)).
- Was Sie gerade getan haben, als das Problem auftrat, sowie allfällige Screenshots.

## Verimesh-Instanz aktualisieren

Die folgende Anleitung beschreibt, wie Sie eine Verimesh-Instanz von v0.5.1 auf v0.5.3 aktualisieren.

*Hinweis:* Sie müssen sich mit dem Linux-Administratorkonto an der VM anmelden.

### Update-Schritte

1. Bearbeiten Sie die `.env`-Datei und setzen Sie die Ops-Agent-Version auf v0.0.3.
2. Bearbeiten Sie die Kundenkonfiguration und setzen Sie auch dort die Ops-Agent-Version auf v0.0.3.
3. Wechseln Sie auf den Branch main: `git checkout main`
4. Laden Sie die neuesten Änderungen herunter: `git pull`
5. Aktualisieren Sie den Ops-Agent-Container: `docker compose up -d ops-agent`
6. Melden Sie sich im Dashboard an.
7. Öffnen Sie Settings.
8. Geben Sie im Abschnitt Update am Seitenende die Zielversion (v0.5.3) ein und starten Sie den Update-Vorgang.

## Keycloak nach dem Update einrichten

Hinweis: Diese Anleitung gilt, wenn Sie das VM-Image v0.5.1 verwendet und anschliessend auf eine neuere Version aktualisiert haben.

Nach dem letzten Keycloak-Update führt eine inkompatible Änderung (Breaking Change) dazu, dass authentifizierte Benutzerinnen und Benutzer beim Aufrufen bestimmter Anwendungsrouten (z. B. Peers, Peer Certificates) unerwartet auf die Anmeldeseite umgeleitet werden.

Zur Behebung muss die folgende manuelle Konfiguration in der *Keycloak-Oberfläche* vorgenommen werden.

### Lösungsschritte

1. Öffnen Sie Keycloak im Browser unter `https://<VM IP address>:8180/admin/master/console/`
    - Der **Port `:8180` ist zwingend**: Keycloak wird auf Port 8180 bereitgestellt. Wenn Sie die IP-Adresse ohne Port öffnen, landen Sie stattdessen beim Dashboard (`:443`), das Sie zur Anmeldung im Realm **stargate** weiterleitet, in dem der Admin-Benutzer nicht existiert (die übliche Ursache für «invalid username or password» bzw. «falscher Realm» an dieser Stelle).
    - Melden Sie sich im Realm **master** an (der Pfad `/admin/master/console/` wählt ihn aus), mit dem Benutzernamen `admin` (dem Wert von `KEYCLOAK_ADMIN_USER`, in Kleinbuchstaben) und dem Wert von `KEYCLOAK_ADMIN_PASSWORD` aus der Datei `/var/data/vereign/.env` der Maschine (auslesbar über die Linux-Konsole).

2. Wechseln Sie in der Admin-Konsole über die Realm-Auswahl (oben links) von **master** zu **stargate**.
3. Öffnen Sie Clients → dashboard.
4. Wechseln Sie zur Registerkarte Client scopes → klicken Sie auf dashboard-dedicated.
5. Wählen Sie Configure a new mapper → Audience.
6. Nehmen Sie folgende Einstellungen vor:
    - Name: apisix-audience
    - Included client audience: apisix (aus der Dropdown-Liste auswählen)
    - Included custom audience: (leer lassen)
    - Add to access token: On
    - Add to token introspection: On
    - Add to ID token / lightweight token: Off

7. Klicken Sie auf Save.

 <br> ![keycloak-console](assets/troubleshooting/keycloak-update.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }


# Passwort eines Stargate-Benutzers in Keycloak zurücksetzen

Mit den folgenden Schritten setzen Sie das Passwort eines Stargate-Benutzers über die Keycloak-Administrationskonsole zurück.

1. **Mit der HIN Gateway-VM verbinden**
    - Öffnen Sie die VM-Konsole oder verbinden Sie sich per SSH mit der HIN Gateway-VM.

2. **Zugangsdaten des Keycloak-Administrators abrufen**
    - Öffnen Sie die Datei `/var/data/vereign/.env`.
    - Suchen Sie die folgenden Variablen:
        - `KEYCLOAK_ADMIN_USER`
        - `KEYCLOAK_ADMIN_PASSWORD`

3. **Keycloak-Administrationskonsole öffnen**
    - Rufen Sie im Browser folgende Adresse auf: `http://<VM-IP>:8180/admin/master/console`
    - Ersetzen Sie `<VM-IP>` durch die IP-Adresse der HIN Gateway-VM.

4. **Bei Keycloak anmelden**
    - Geben Sie den Benutzernamen und das Passwort des Administrators aus der `.env`-Datei ein.
    - Behalten Sie das Administratorpasswort unverändert bei. Wenn Sie es dennoch ändern, müssen Sie das neue Passwort sicher aufbewahren.

5. **Realm Stargate auswählen**
    - Wählen Sie in der Realm-Auswahl der Keycloak-Administrationskonsole **Stargate** aus.

6. **Benutzer suchen**
    - Öffnen Sie **Users**.
    - Suchen Sie den Stargate-Benutzer, dessen Passwort zurückgesetzt werden soll, und wählen Sie ihn aus.

7. **Passwort des Benutzers zurücksetzen**
    - Wählen Sie die Option zum Zurücksetzen des Passworts.
    - Geben Sie das neue Passwort ein und bestätigen Sie die Änderung.

**Ändern oder setzen Sie im Rahmen dieses Vorgangs nicht das Passwort des Keycloak-Administrators zurück.**
Jede Änderung des Admin-Passworts kann dazu führen, dass Keycloak gesperrt wird und niemand mehr darauf zugreifen kann.


# Aktivierungscode anfordern

Wenn Sie eine HIN Gateway-Instanz installieren oder neu installieren möchten, benötigen Sie einen Aktivierungscode, den Sie beim HIN Support erhalten.


!!! warning "Das Zurücksetzen des Aktivierungscodes trennt die Peer-Verbindung"
    Wird der Aktivierungscode einer aktiven Instanz zurückgesetzt, wird die WireGuard-Peer-Verbindung des Kunden gelöscht.

    Beantragen Sie das Zurücksetzen für die falsche Kundeninstanz, wird die Verbindung dieser aktiven Instanz gelöscht und unterbrochen. Prüfen Sie deshalb vor der Anfrage genau, um welche Instanz es sich handelt, und bestätigen Sie alle darauf gehosteten Domains.
