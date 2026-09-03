# HIN Gateway: Technischer Leitfaden für Neuinstallation und Migration

## Einleitung

Dieses Dokument bietet einen umfassenden Leitfaden für die technische Installation und Migration auf das neue HIN Gateway ("HIN Gateway Appliance").

Die Anleitung richtet sich an HIN Kunden, IT-Administratoren und Systemingenieure, die für die Bereitstellung und Konfiguration des neuen HIN Gateways sowie, sofern zutreffend, für die Migration vom bestehenden Mail-Gateway (MGW) zur neuen Lösung verantwortlich sind.

Das HIN Gateway ist eine sichere E-Mail-Gateway-Lösung, die eine vertrauenswürdige, verschlüsselte und richtliniengesteuerte Kommunikation innerhalb des HIN Trust Circle ermöglicht. Es fungiert als zentraler Vermittler zwischen internen E-Mail-Infrastrukturen und externen Kommunikationspartnern und stellt sicher, dass der gesamte E-Mail-Verkehr sicher übertragen wird, den Richtlinien der Organisation entspricht und die Sicherheitsstandards von HIN erfüllt.

## Übersicht über den E-Mail-Fluss

- **Eingehende E-Mails** werden über das HIN Gateway geleitet, wo sie validiert, (falls erforderlich) entschlüsselt und anhand von Vertrauens- und Sicherheitsrichtlinien überprüft werden, bevor sie an den internen Mailserver weitergeleitet werden.
- **Ausgehende E-Mails** werden von internen Systemen an das HIN Gateway gesendet, wo Verschlüsselung, Weiterleitung und die Durchsetzung der Richtlinien erfolgen, bevor sie an externe Empfänger übermittelt werden.
- **Die Kommunikation zwischen den HIN Gateways** wird durch Peer-Zertifikate und WireGuard-Tunnel gesichert, wodurch eine vertrauenswürdige Kommunikation zwischen den Domänen gewährleistet wird.

## Installations- und Migrationsablauf

Die in diesem Dokument beschriebene strukturierte Schritt-für-Schritt-Anleitung deckt sowohl Neuinstallationen des HIN Gateways als auch Migrationen von einem bestehenden HIN Mail Gateway (MGW) ab. Je nach Bereitstellungsszenario gelten einzelne Schritte möglicherweise nur für Migrationen.

1. Vorbereitung und Bereitstellungsplanung, einschliesslich Ausweichplanung, sofern zutreffend
2. Installation und Konfiguration des HIN Gateways
3. Domänenaktivierung und Zertifikatsvalidierung
4. Integration in die bestehende Mail-Umgebung und Konfiguration des Routings
5. Testen, Übergang in den Produktivbetrieb und Validierung nach der Bereitstellung
6. Bei Migrationen: Ausserbetriebnahme des bestehenden MGW nach erfolgreicher Validierung

!!! info "Migration"
    Das Ziel von HIN ist es, eine sichere, reibungslose und vollständig validierte Bereitstellung mit minimaler Beeinträchtigung des Betriebs und unterbrechungsfreier Kontinuität der E-Mail-Dienste zu gewährleisten.
     In Migrationsszenarien sollte das bestehende MGW als Ausweichoption verfügbar bleiben, bis das HIN Gateway im Produktivbetrieb erfolgreich validiert wurde. Es sollte erst ausser Betrieb genommen werden, nachdem die Migration abgeschlossen und der stabile Betrieb bestätigt wurde.

## Häufig gestellte Fragen

!!! question "Kann ich die Installation oder Migration selbst durchführen?"
    Ja, die Installation oder Migration kann vollständig vom Kunden durchgeführt werden.

    Für das Migrationsszenario besteht die einzige Ausnahme bei **"Schritt 1.3 - Exportieren der/des privaten Schlüssel(s)"**. Aus Sicherheitsgründen und um Ihren privaten Schlüssel zu schützen, müssen Sie sich an den HIN Support wenden oder an der geplanten Migrationsbesprechung teilnehmen, um den Code zu erhalten, der für den Export des privaten Schlüssels aus dem derzeit in Betrieb befindlichen Mail-Gateway erforderlich ist.


    Sollten die Installation oder die Migration nicht erfolgreich abgeschlossen werden können, nehmen Sie bitte am geplanten Support-Gespräch mit unseren Technikern teil.

!!! question "Kommt es während des Einrichtungsprozesses zu einer Unterbrechung der E-Mail-Zustellung?"
    **Migration:** Zwischen "Schritt 1.5 - Bestehende MGW-VM abschalten" und "Schritt 18 - Mailserver konfigurieren" werden alle E-Mails auf dem Mailserver in die Warteschlange gestellt. Sobald "Schritt 18 - Mailserver konfigurieren" abgeschlossen ist, werden die in der Warteschlange befindlichen E-Mails versendet oder in das Postfach zugestellt.

    **Neuinstallation:** Während Sie die E-Mail-Flussregeln konfigurieren, werden alle E-Mails auf dem Mailserver in die Warteschlange gestellt. Sobald "Schritt 18 - Mailserver konfigurieren" abgeschlossen ist, werden die in der Warteschlange befindlichen E-Mails versendet oder in das Postfach zugestellt.

!!! question "Gehen während der Installation und Migration E-Mails verloren?"
    Nein, während der Installation und Migration gehen keine E-Mails verloren. Einige E-Mails können sich verzögern.

## Übersicht über die Installationsschritte

| Schritt | Thema | Verantwortung | Migration | Neuinstallation |
| :--: | :---- | :------------: | :--: | :---- |
| 0 | Voraussetzungen prüfen | Kunde | Ja | Ja |
| 1.1 | Smoke-Test | Kunde | Ja | N/A |
| 1.2 | Sichern des bestehenden MGWs | Kunde | Ja | N/A |
| 1.3 | Exportieren der/des privaten Schlüssel(s) | Kunde / HIN | Ja | N/A |
| 1.4 | Notfallplan / Ausweichszenario | Kunde | Ja | N/A |
| 1.5 | Bestehende MGW-VM abschalten | Kunde | Ja | N/A |
| 2 | WireGuard | Kunde | Ja | Ja |
| 3 | Ziel-VM auswählen | Kunde | Ja | Ja |
| 4 | VM-Image laden | Kunde | Ja | Ja |
| 5 | Netzwerkverbindung zur VM | Kunde | Ja | Ja |
| 6 | Zugriff über den Browser | Kunde | Ja | Ja |
| 7 | Aktivierungscode eingeben | Kunde | Ja | Ja |
| 8 | Setup des Mesh-Netzwerks | Kunde | Ja | Ja |
| 9 | Sicheres Mesh-Netzwerk einrichten | Kunde | Ja | Ja |
| 10 | Login bei Keycloak | Kunde | Ja | Ja |
| 11 | Passwort aktualisieren | Kunde | Ja | Ja |
| 12 | Kontoinformationen aktualisieren | Kunde | Ja | Ja |
| 13 | Erstkonfiguration und Einrichten der Domäne | Kunde | Ja | Ja |
| 14 | E-Mail-Transport konfigurieren | Kunde | Ja | Ja |
| 15 | Whitelist-Header konfigurieren | Kunde | Ja | Ja |
| 16 | Peer-Zertifikate | HIN | Ja | Ja |
| 17 | Peer-Zertifikate validieren | Kunde | Ja | Ja |
| 18 | Mailserver konfigurieren | Kunde | Ja | Ja |
| 19 | Test und Validierung | Kunde | Ja | Ja |
| 20 | Passwort der VM ändern | Kunde | Ja | Ja |
| 21 | Bestehendes MGW ausser Betrieb nehmen | Kunde | Ja | N/A |
| Anhang 1 | Sichern und Wiederherstellen der Appliance-Einstellungen | Kunde | Ja | N/A |

## Detaillierte Schritte

### Schritt 0 - Voraussetzungen prüfen

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Bitte stellen Sie sicher, dass alle notwendigen Vorbereitungsschritte abgeschlossen sind, bevor die Migrationsarbeiten für das HIN Gateway beginnen.

Die folgenden Punkte müssen vor der Installation verfügbar sein oder bestätigt werden:

- **Die Zugangsdaten werden Ihnen von HIN zugestellt**
  - VM-Zugangsdaten
  - Keycloak-Zugangsdaten
  - Aktivierungscode

- **Export des privaten Schlüssels**
    **Hinweis:** Gilt nur für Migrationsfälle
  - Wenn Sie an einem Windows-Rechner arbeiten, der über Port 22 Zugriff auf die Mail-Gateway-VM hat, können wir Sie während des Gesprächs dabei unterstützen, den Export des privaten Schlüssels aus dem MGW zu aktivieren.
  - Falls Sie keinen Zugriff auf einen solchen Rechner haben, wenden Sie sich bitte per E-Mail oder Telefon (<support@hin.ch> / 0848 830 740) an den HIN Support, damit wir Ihnen helfen können, eine Supportverbindung über "Systemadministration" -> "Supportverbindung" -> "Verbinden" herzustellen.
- **Laden Sie die neueste Version** des [VM-Images](vm/VM-Catalog.md) herunter.
- **Firewall**:
  - Erlauben Sie den Datenverkehr: beliebig → HIN Gateway und HIN Gateway → beliebig
    - WireGuard: Siehe [Serveranforderungen: Eingehender Netzwerkzugriff](./index.md#eingehender-netzwerkzugriff-firewall-muss-erlauben):
      - Konfigurieren Sie den WireGuard-Port `19818` (TCP/UDP) in Ihrer Firewall.
        - Eingehender und ausgehender Datenverkehr
  - Erlauben Sie den Datenverkehr: Administrationsrechner → HIN Gateway-VM
    - Anforderungen für die Installation:
      - HTTPS-Port `443`
        - Eingehender und ausgehender Datenverkehr
      - Keycloak-Port `8180`
        - Eingehender und ausgehender Datenverkehr
    - Anforderungen für die Fehlerbehebung (optional, um Protokolle einzusehen und alle Parameter zu ändern):
      - SSH-Port `22`
        - Eingehender und ausgehender Datenverkehr
      - Dozzle-Port `8190`
        - Eingehender und ausgehender Datenverkehr
- Für "[Schritt 5 - Netzwerkverbindung zur VM](#schritt-5-netzwerkverbindung-zur-vm)" sollte ein **DHCP-Zugang** verfügbar sein (empfohlen).
- Anforderungen an die **Datensicherung**, siehe "[Anhang 1 - Sichern und Wiederherstellen der Appliance-Einstellungen](#anhang-1-sichern-und-wiederherstellen-der-appliance-einstellungen)". **Hinweis:** Gilt nur für Migrationsfälle
- Hinweis: gilt nur für Migrationsfälle. Bestätigung, dass das bestehende MGW erst nach Abschluss der Abnahme gelöscht wird.
- Zugriff auf DNS, Mailserver-Konnektoren, Transportregeln und Relay-Einstellungen.

!!! info "Warum WireGuard?"
    Der WireGuard-Port erfüllt zwei wichtige Funktionen:

    1. Das HIN Gateway nutzt diesen Port, um Peer-Zertifikate von der HIN CA zu beziehen.
    2. Es nutzt diesen Port, um einen sicheren Tunnel zu anderen HIN Gateways aufzubauen, über den der sichere Datenaustausch (z.B. E-Mail-Verkehr) stattfindet.

!!! tip "Export des privaten Schlüssels" - Gilt nur für Migrationsfälle
    Falls Sie an einem Windows-Rechner arbeiten, der über Port 22 Zugriff auf die Mail Gateway-VM hat, können wir Sie während des Anrufs unterstützen, um den Export des privaten Schlüssels vom MGW zu aktivieren.

    Falls Sie keinen Zugriff auf einen solchen Rechner haben, wenden Sie sich bitte an den HIN Support per E-Mail oder Telefon (**support@hin.ch** / **0848 830 740**), um eine Support-Verbindung über **Systemverwaltung → Support-Verbindung → Verbinden** herzustellen.

### Schritt 1.1 - Smoke-Test

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

!!! info Gilt nur für Migrationsfälle
    Dieser Schritt gilt nur für Einzel- und Multi-Domain-Migrationen

Senden Sie Test-E-Mails an die folgenden Empfänger und verwenden Sie dabei Postfächer, auf die Sie Zugriff haben, damit die erfolgreiche Zustellung überprüft werden kann:

- eine HIN E-Mail-Adresse oder eine E-Mail-Adresse innerhalb Ihrer HIN Community-Domain, zum Beispiel: `user@hin.ch`
- eine externe E-Mail-Adresse ausserhalb der HIN Community, zum Beispiel: Bluewin, Gmail, Yahoo oder GMX

Senden Sie für den externen Empfänger eine E-Mail aus der HIN Community mit **dem Vermerk (vertraulich) in der Betreffzeile**.

Testen Sie den E-Mail-Fluss in beide Richtungen:

- von der vertrauenswürdigen HIN-Domain zur externen E-Mail-Adresse
- von der externen E-Mail-Adresse zur HIN Community

Überprüfen Sie, ob alle Test-E-Mails erfolgreich zugestellt wurden und Betreff, Inhalt und allfällige Anhänge korrekt empfangen wurden.

### Schritt 1.2 - Sichern des bestehenden MGWs

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

!!! info Gilt nur für Migrationsfälle
    Dieser Schritt gilt nur für Einzel- und Multi-Domain-Migrationen

Erstellen Sie ein Backup der bestehenden MGW-Appliance und stellen Sie sicher, dass die VM so lange bestehen bleibt, bis die Migration erfolgreich abgeschlossen und formell abgenommen wurde. Weitere Informationen finden Sie unter "Anhang 1 - Sichern und Wiederherstellen der Appliance-Einstellungen".

!!! info "Aktuelle MGW-Routing-Konfiguration prüfen"
    Bevor Sie das bestehende MGW abschalten, überprüfen Sie die folgenden Konfigurationswerte und notieren Sie sie. Sie werden diese wahrscheinlich später bei der Konfiguration des HIN Gateways benötigen:

    1. Melden Sie sich beim MGW an und gehen Sie zu **"Mail System → Outgoing server"** und prüfen Sie, ob dort etwas konfiguriert ist.
    2. Gehen Sie für jede auf dem MGW gehostete Domäne zu `Mail System → <Domäne> → Forwarding server` und `Mail System → <Domäne> → Send ALL outgoing mails from this domain to the following SMTP server` und notieren Sie die aktuellen Werte.
    <br> ![domain-relay-host](assets/installation-guide/step1.2-domain-relay-host.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

!!! tip "MGW-Header-Prüfung"
    Wenn Sie im MGW die Option `Header check` verwenden, notieren Sie sich auch den konfigurierten Wert. Sie können dieselbe Header-Prüfung später im HIN Gateway einrichten.

### Schritt 1.3 - Exportieren der/des privaten Schlüssel(s)

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)
:heavy_plus_sign:
![Verantwortlichkeit HIN](https://img.shields.io/badge/Verantwortlichkeit-HIN-orange)

!!! info Gilt nur für Migrationsfälle
    Dieser Schritt gilt nur für Einzel- und Multi-Domain-Migrationen

    Führen Sie den Vorgang bei einer Multi-Domain-Migration für jede Domäne durch

!!! warning "Unterstützung durch HIN erforderlich"
    Für diesen Schritt ist ein Freischaltcode erforderlich. Der Code wird von einem HIN Support Engineer bereitgestellt.

Wenn Sie die Installation selbstständig fortsetzen möchten, kontaktieren Sie bitte den HIN Support, um den Freischaltcode anzufordern. Andernfalls wird Ihnen der Freischaltcode während des geplanten Migrationstermins zur Verfügung gestellt.

<!-- !!! info
    Bitte laden Sie das Tool `HIN_Migration-Tool_v*.exe` unter folgendem Link herunter: [link](https://link) -->

1. Melden Sie sich bei der bestehenden MGW-Web-GUI an.
2. Öffnen Sie **„Mail System“**. <br> ![Mail System öffnen](assets/installation-guide/step1.3-2-open-mail-system.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
3. Starten Sie die Anwendung, indem Sie auf [**`HIN_Migration-Tool_v*.exe`**](https://images.hin.ch/mgw/HIN_MigrationTool-v3.0.exe) klicken, wenn Sie die Installation selbst durchführen möchten. Alternativ können Sie bis zum Migrationstermin warten, bei dem der Support Engineer Sie bei der Installation unterstützt. <br> ![HIN Migration Tool](assets/installation-guide/step1.3-3-migration-tool.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
4. Geben Sie den Freischaltcode ein, den Ihnen der Support-Mitarbeiter mitteilt. <br> ![Freischaltcode eingeben](assets/installation-guide/step1.3-4-unlock-code.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
5. Wählen Sie **„Export aktivieren“**. <br> ![Export aktivieren](assets/installation-guide/step1.3-5-enable-export.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
6. Geben Sie die MGW-IP-Adresse ein. <br> ![MGW-IP-Adresse eingeben](assets/installation-guide/step1.3-6-mgw-ip.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
7. Warten Sie auf die Bestätigung. <br> ![Auf Bestätigung warten](assets/installation-guide/step1.3-7-confirmation.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
8. Wählen Sie die vertrauenswürdige Domäne in der MGW-WebGUI aus. <br> ![Vertrauenswürdige Domäne auswählen](assets/installation-guide/step1.3-8-trusted-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
9. Scrollen Sie nach unten und wählen Sie den verwalteten Fingerabdruck aus. <br> ![Verwalteten Fingerabdruck auswählen](assets/installation-guide/step1.3-9-managed-fingerprint.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
10. Scrollen Sie nach unten zum Abschnitt **„PKCS12 download“** (optional können Sie ein Passwort zum Verschlüsseln des Schlüssels eingeben). Klicken Sie auf **„Download PKCS12“** und speichern Sie die Datei `*.p12` auf dem Computer. <br> ![PKCS12-Download](assets/installation-guide/step1.3-10-pkcs12-download.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
11. Kehren Sie zur Anwendung `HIN_Migration-Tool_v*.exe` zurück und deaktivieren Sie die Schaltfläche **Export**. <br> ![Export deaktivieren](assets/installation-guide/step1.3-11-disable-export.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Schritt 1.4 - Notfallplan / Ausweichszenario

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

!!! info Gilt nur für Migrationsfälle
    Dieser Schritt gilt nur für Einzel- und Multi-Domain-Migrationen

**Rollback-Szenario** - Falls ein Rollback erforderlich ist:

1. Das neue HIN Gateway anhalten.
2. Schalten Sie das bestehende MGW ein.
3. Überprüfen Sie, ob der eingehende und ausgehende E-Mail-Verkehr über das bestehende MGW korrekt funktioniert.
    * Führen Sie die Überprüfung bei einer Multi-Domain-Migration für jede Domäne durch

### Schritt 1.5 - Bestehende MGW-VM abschalten

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

!!! info Gilt nur für Migrationsfälle
    Dieser Schritt gilt nur für Einzel- und Multi-Domain-Migrationen

Fahren Sie die bestehende MGW-VM herunter.

!!! warning
    Dieser Schritt unterbricht den E-Mail-Verkehr. Während der Unterbrechung werden E-Mails auf dem Mailserver in die Warteschlange gestellt und erst nach Abschluss der Installation zugestellt (siehe „[Schritt 18 - Mailserver und HIN Gateway konfigurieren](#schritt-18-mailserver-und-hin-gateway-konfigurieren)“).

### Schritt 2 - WireGuard

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Stellen Sie sicher, dass Sie den WireGuard-Port 19818 (TCP/UDP) in Ihrer Firewall konfiguriert haben:

- Eingehender und ausgehender Datenverkehr
- Verkehr zulassen: "any-to-HIN Gateway" und "HIN Gateway-to-any"

### Schritt 3 - Ziel-VM auswählen

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Wählen Sie eines der verfügbaren virtuellen Images aus und richten Sie es gemäss der Installationsanleitung auf der HIN Gateway Service-Seite ein.

!!! info
    Aus Security- und Kompatibilitätsgründen sollten Sie sicherstellen, dass Ihr Hypervisor nicht auf einer veralteten Version läuft. Die HIN Gateway Appliance wird auf der neuesten Hypervisor-Version sowie der unmittelbar vorhergehenden Major-Version unterstützt.

- Installation des VM-Images:
    - [Azure-VM-Image](vm/Azure-image-install.md)
    - [Windows 11 Pro (Hyper-V)-Image](vm/Windows11pro-image-install.md)
    - [VMware-Image](vm/VMware-image-install.md)
    - [Proxmox-Image](vm/Proxmox-image-install.md)
    - [Cloudscale](vm/Cloudscale-image-install.md)
- [Konfiguration von Microsoft Exchange](Exchange-integration.md)

### Schritt 4 - VM-Image laden

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Laden Sie die ausgewählte VM auf Ihren Hypervisor hoch.

!!! warning "Zweite Festplatte erforderlich: die Data Disk"
    Die Appliance nutzt zwei Festplatten: die OS-Festplatte aus dem Image und eine separate **Data Disk**, die die gesamte Konfiguration, Secrets, E-Mails und Datenbanken enthält. Diese Trennung erlaubt es, das OS bei einem Image-Update zu ersetzen, ohne Ihre Daten anzurühren.

    Die **VMware-OVA enthält** diese Festplatte bereits. Auf allen anderen Plattformen (Proxmox, Hyper-V, Azure, Cloudscale) ist das Image eine einzelne OS-Festplatte. Hängen Sie daher vor dem ersten Start eine zweite, leere Festplatte mit mindestens 30 GB an.

    Formatieren oder partitionieren Sie sie nicht selbst. Beim ersten Start formatiert die Appliance die leere Festplatte (Label `VEREIGN-DATA`) und mountet sie unter `/var/data`. Ohne sie schlägt der erste Start seine Health-Prüfung fehl und wird zurückgerollt.

### Schritt 5 - Netzwerkverbindung zur VM

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Stellen Sie sicher, dass die VM über eine Netzwerkverbindung verfügt und ihr eine statische IP-Adresse zugewiesen wurde.

**Option A:** Konfigurieren Sie die IP-Adresse der VM direkt im von Ihnen verwendeten Hypervisor.

**Option B:** Konfigurieren Sie den DHCP-Server Ihres Routers so, dass er anhand der MAC-Adresse der VM stets dieselbe IP-Adresse zuweist.

**Option C:** Melden Sie sich lokal über die VM-Konsole an und konfigurieren Sie manuell eine statische IP-Adresse.

**HINWEIS:** Das VM-Image führt beim ersten Start eine automatische Installation durch. Wenn das Netzwerk zu diesem Zeitpunkt nicht konfiguriert ist, schlägt die Installation fehl, da die IP-Adresse des Servers nicht ermittelt werden kann.

**Eine IP-Adresse unter Linux hinzufügen:**

1. Führen Sie den Befehl "nmtui" in der Konsole aus.

    ```bash
    nmtui
    ```

2. Navigieren Sie mit den Pfeiltasten und drücken Sie dann "Enter", um die "Ethernet-Verbindung" auszuwählen, deren IP-Adresse Sie ändern möchten. <br> ![IP-Adresse hinzufügen](assets/ip_addr_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
3. Navigieren Sie zu "IPv4-Konfiguration" und ändern Sie die Einstellung von "Automatisch" auf "Manuell". <br> ![IP-Adresse hinzufügen](assets/ip_addr_2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
4. Navigieren Sie mit den Pfeiltasten zu den Feldern, in denen Sie die IP-Adresse, das Gateway und den DNS-Server eingeben können. Wählen Sie anschliessend "OK". <br> ![IP-Adresse hinzufügen](assets/ip_addr_3.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
5. Führen Sie nach dem Speichern der IP-Adresskonfiguration den folgenden Befehl in der Konsole aus:

    ```bash
    sudo systemctl restart NetworkManager
    ```

??? tip "Cloud-init überschreibt VM-Netzwerkeinstellungen nach einem Neustart"
    **Dies betrifft nur das Legacy-Image.** Die bootc-Appliance, jetzt der Standard, verwendet kein cloud-init für die Netzwerkverwaltung, ist daher nicht betroffen und enthält die unten verwendeten `cloud-init-net-*`-Aliase nicht.

    Auf dem Legacy-Image (typischerweise auf VMware/ESXi) hat cloud-init keine Datenquelle, fällt auf „DHCP für die erste NIC" zurück und rendert die Netzwerkkonfiguration bei jedem Boot neu, weshalb eine mit `nmtui` gesetzte statische Adresse nach einem Neustart zurückgesetzt wird. Ein Alias behebt dies in einem Schritt, indem er nur das Netzwerk-Rendering von cloud-init deaktiviert, sodass eine anschliessend am bestehenden Profil gesetzte Adresse erhalten bleibt:

    1. Cloud-init daran hindern, das Netzwerk bei jedem Boot neu zu rendern:
    ```bash
    cloud-init-net-disable
    ```
    2. Führen Sie `nmtui` aus, bearbeiten Sie die bestehende Verbindung **`cloud-init <iface>`** und setzen Sie dort die statische IP, das Gateway und den DNS. Fügen Sie kein zweites Profil für dieselbe Schnittstelle hinzu. Das von cloud-init hat eine höhere Autoconnect-Priorität und würde gewinnen.
    ```bash
    nmtui
    ```
    3. Starten Sie neu und prüfen Sie, ob die Adresse erhalten bleibt:
    ```bash
    sudo reboot
    # nach dem Neustart:
    nmcli device status; ip -4 addr
    ```

    `cloud-init-net-enable` stellt das standardmässige, von cloud-init verwaltete Netzwerk wieder her. Ohne den Alias ist Schritt 1 dasselbe Drop-in von Hand:
    ```bash
    echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    ```

!!! tip
    Wenn Sie Option C verwendet und das Netzwerk manuell konfiguriert haben, müssen Sie die folgenden Befehle ausführen:

    ```bash
    cd /usr/share/stargate-deployment/docker-compose
    ./scripts/purge.sh
    ./scripts/install.sh
    ```

    Das Installationsskript ermittelt bei jedem Durchlauf automatisch die IP-Adresse des Servers anhand der Standardroute; eine manuelle Anpassung von `customer-config.sh` ist nicht erforderlich. Jede erreichbare IP-Adresse, ob öffentlich oder privat, ist ausreichend. Der eigentliche öffentliche Endpunkt wird später über das Dashboard konfiguriert.

    !!! note "Hinter NAT oder mit einer Floating IP?"
        Wenn Ihr Server über eine *andere* öffentliche oder Floating-IP erreichbar ist als über die IP seiner eigenen Netzwerkschnittstelle (häufig bei NAT), setzen Sie `SERVER_STATIC_IP` in `customer-config.sh` auf diese erreichbare IP, bevor Sie `install.sh` ausführen. Andernfalls lassen Sie das Feld leer, damit die IP-Adresse automatisch erkannt wird.

    Nachdem die Skripte erfolgreich ausgeführt wurden, fahren Sie mit "Schritt 6 - Zugriff über den Browser" fort.

    !!! question
        Falls Sie nicht über die HIN-Admin-Zugangsdaten verfügen, wenden Sie sich bitte an den HIN Support per E-Mail oder Telefon (**support@hin.ch** / **0848 830 740**). Siehe [Support-Bereich](./Support.md).

        [Klicken Sie hier, um eine E-Mail zu senden](mailto:support@hin.ch?subject=Passwort%20für%20VM-Installation%20erforderlich.&body=Sehr%20geehrter%20Support,%0A%0Aich%20benötige%20das%20Passwort%20für%20eine%20VM-Installation.%0A%0ABITTE%20GEBEN%20SIE%20HIER%20IHRE%20KUNDENINFORMATIONEN%20AN){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Schritt 6 - Zugriff über den Browser

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Öffnen Sie einen Browser und geben Sie die für die VM konfigurierte IP-Adresse ein. Es sollte der Bildschirm für die Ersteinrichtung angezeigt werden.

```plain
https://<IP-Adresse der VM>
```

### Schritt 7 - Aktivierungscode eingeben

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Wählen Sie Ihre bevorzugte Sprache aus und geben Sie den Aktivierungscode ein, den Sie per E-Mail von HIN erhalten haben. Klicken Sie auf "Next".

![Bildschirm zur Eingabe des Aktivierungscodes](assets/installation-guide/step7-activation-code.png)

!!! question "Ich habe keinen Aktivierungscode"
    Falls Sie den Aktivationscode nicht haben, wenden Sie sich bitte per E-Mail oder Telefon an den HIN Support (**<support@hin.ch>** / **0848 830 740**). Siehe [Support-Bereich](./Support.md).

    [Klicken Sie hier, um eine E-Mail zu senden](mailto:support@hin.ch?subject=Aktivierungscode%20erforderlich.&body=Sehr%20geehrter%20Support,%0A%0Aich%20benötige%20den%20Aktivierungscode%20für%20meine%20HIN-Gateway-Installation.%0A%0ABITTE%20GEBEN%20SIE%20HIER%20IHRE%20KUNDENINFORMATIONEN%20AN){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Schritt 8 - Setup des Mesh-Netzwerks

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Überprüfen Sie die Konfiguration des Mesh-Netzwerks:

- **IP-Adresse** - Die öffentliche IP-Adresse des ausgehenden Datenverkehrs (wird automatisch erkannt).
- **Transport** - Das Transportprotokoll (Standard: `tcp`).
- **Port** - Der WireGuard-Port (Standard: `19818`).

??? question "Was ist eine öffentliche IP?"
    Dies ist eine IP-Adresse, die der Rechner verwenden wird, um über das Internet erreichbar zu sein.
    Es handelt sich **nicht** um die interne IP-Adresse des Rechners hinter einer Firewall oder NAT, z. B. `10.0.0.0/8`, `172.16.0.0/12` oder `192.168.0.0/16`.

Überprüfen Sie, ob die Werte korrekt sind, und klicken Sie auf "Next".

![Bildschirm für das Mesh-Netzwerk-Setup](assets/installation-guide/step8-mesh-network.png)

### Schritt 9 - Sicheres Mesh-Netzwerk einrichten

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Das System baut nun die sichere Mesh-Netzwerk-Verbindung auf. Dieser Schritt verbindet das HIN Gateway mit dem Mesh-Netzwerk und synchronisiert die Zertifikate.

Warten Sie, bis der Vorgang abgeschlossen ist. Die Statusanzeigen zeigen "Up" an, sobald die Verbindung erfolgreich hergestellt wurde. Klicken Sie auf "Finish".

![Sicheres Mesh-Netzwerk einrichten](assets/installation-guide/step9-mesh-connecting.png)

!!! failure "Falls die Verbindung fehlschlägt"
    Wenn der Status von `Iris Agent` oder der Zertifikatssynchronisation weiterhin "Down" lautet:

    - Stellen Sie sicher, dass Port `19818` (TCP/UDP) in Ihrer Firewall offen ist (siehe "Schritt 2 - WireGuard").
    - Überprüfen Sie, ob die IP-Adresse unter "Schritt 8 - Setup des Mesh-Netzwerks" korrekt ist und über das Internet erreichbar ist.
    - Starten Sie den Vorgang neu oder wenden Sie sich per E-Mail oder Telefon an den HIN Support (**support@hin.ch** / **0848 830 740**).

### Schritt 10 - Login bei Keycloak

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

!!! warning
    Port `8180` muss für Keycloak geöffnet sein. Er muss nicht aus dem gesamten Internet erreichbar sein. Er sollte jedoch zwischen **Ihrem Administrationsrechner** und der VM, die Sie installieren, erreichbar sein. Andernfalls können Sie keine Verbindung zu Keycloak herstellen und die Installation nicht fortsetzen.

    ??? tip "Was tun, wenn ein Verbindungsfehler angezeigt wird?"
        Bitte prüfen Sie, ob Port `8180` von Ihrem Rechner zur VM erreichbar ist. Nachdem Sie die Konfiguration aktualisiert haben, kehren Sie zur Benutzeroberfläche unter `https://<VM IP address>` zurück und klicken Sie auf die Schaltfläche „Login“.

Sobald das Mesh-Netzwerk eingerichtet ist, werden Sie zur Keycloak-Anmeldeseite weitergeleitet. Geben Sie den Benutzernamen und das Passwort ein, die Sie von HIN erhalten haben.

![Keycloak-Anmeldeseite](assets/installation-guide/step10-keycloak-login.png)

!!! question
    Falls Sie diese Anmeldedaten nicht haben, wenden Sie sich bitte per E-Mail oder Telefon an den HIN Support (**<support@hin.ch>** / **0848 830 740**). Siehe [Support-Bereich](./Support.md).

    [Klicken Sie hier, um eine E-Mail zu senden](mailto:support@hin.ch?subject=Keycloak-Anmeldedaten%20erforderlich.&body=Sehr%20geehrter%20Support,%0A%0Aich%20benötige%20die%20Keycloak-Anmeldedaten%20für%20mein%20HIN-Gateway.%0A%0ABITTE%20GEBEN%20SIE%20HIER%20IHRE%20KUNDENINFORMATIONEN%20AN){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Schritt 11 - Passwort aktualisieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Bei der ersten Anmeldung werden Sie aufgefordert, Ihr Passwort zu ändern. Geben Sie ein neues sicheres Passwort ein und bestätigen Sie es.

Bitte stellen Sie sicher, dass Sie sich das Passwort merken!

![Bildschirm zum Aktualisieren des Passworts](assets/installation-guide/step11-update-password.png)

### Schritt 12 - Kontoinformationen aktualisieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Vervollständigen Sie Ihr Kontoprofil, indem Sie Ihren Vornamen und Nachnamen eingeben. Die E-Mail-Adresse ist bereits vorausgefüllt. Klicken Sie auf "Submit", um fortzufahren.

![Bildschirm zum Aktualisieren der Kontoinformationen](assets/installation-guide/step12-account-info.png)

### Schritt 13 - Erstkonfiguration und Einrichten der Domäne

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

!!! info Hinweis zu Multi-Domain-Migrationen
    Führen Sie den Vorgang bei einer Multi-Domain-Migration für jede Domäne durch, die Sie gerade aktivieren.

Konfigurieren Sie auf diesem Bildschirm Ihre Grundeinstellungen:

- Überprüfen Sie, ob alle Ihre aktuellen vertrauenswürdigen Domänen innerhalb der HIN Community korrekt angezeigt werden.
- Wählen Sie aus, welche vertrauenswürdigen Domänen "Enabled" sein sollen, um Peer-Zertifikate von der HIN Zertifizierungsstelle (HIN CA) zu erhalten.
- Geben Sie an, für welche Domäne(n) das Präfix "sec.\<domain\>" bereits konfiguriert ist ("Use sec-prefix").

??? tip "Wie kann ich prüfen, ob meine Domain mit einem Security Prefix eingerichtet ist?"
    Öffnen Sie unser Online-Tool im Browser: <https://trust.hin.ls-infra.me/>, geben Sie `sec.<domain>` ein und klicken Sie auf die Schaltfläche **Check**. Wenn folgende Meldung angezeigt wird:

    ✅ Diese Domain ist verschlüsselt.

    Dann ist Ihre Domain mit einem Security Prefix eingerichtet und Sie müssen die Option **Use sec-prefix** aktivieren.

- Überprüfen Sie, ob der Organisationsname und die Domain-Inhaber korrekt sind. <br> ![Screenshot](assets/installation-guide/step13-1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" } <br> ![Screenshot](assets/step_13_2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
- Importieren Sie die vorhandene S/MIME-Zertifikatsdatei (`.p12`/`.pfx`) vom bestehenden MGW:
    1. Erweitern Sie die Domäne und wählen Sie die Option **P12/PFX File**.
    2. Falls für die Zertifikatsdatei kein Passwort festgelegt wurde, lassen Sie das Passwortfeld leer.
    3. Klicken Sie auf **"Import Certificate"**.
    4. Nachdem das Zertifikat importiert wurde, wird die Meldung *Certificate imported successfully* angezeigt.
- Klicken Sie am Ende der Seite auf **"Save Configuration"**, um die Änderungen zu speichern.

![Bildschirm für die Ersteinrichtung](assets/installation-guide/step13-initial-setup.png)

!!! warning
    - Mindestens eine Domain muss **Enabled** sein, um mit dem Onboarding-Prozess fortzufahren. Die Schaltfläche "Save configuration" wird erst aktiv, wenn diese Voraussetzung erfüllt ist.
    - Sollten Sie feststellen, dass nicht alle vertrauenswürdigen Domains angezeigt werden oder die Organisationsangaben falsch sind, wenden Sie sich bitte per E-Mail oder Telefon an den HIN Support (**<support@hin.ch>** / **0848 830 740**).

!!! danger "Importieren Sie Ihren bestehenden privaten Schlüssel"
    Hinweis: gilt nur für das Migrationsszenario!

    Wenn Sie den privaten Schlüssel **nicht** von Ihrem bestehenden MGW importieren, wird ein neuer Schlüssel ausgestellt. Dies kann dazu führen, dass Nachrichten bis zu **6 Stunden** lang nicht entschlüsselt werden können, was zu **Datenverlust** führen könnte.

![Bildschirm für die Ersteinrichtung](assets/installation-guide/step13-initial-setup2.png)

| Einstellung | Beschreibung |
| --------- | ------------- |
| **Hostname des Mail-Servers** | Der FQDN dieser Mail-Gateway-Instanz (z. B. `mail.example.com`). |
| **IP-Adressen des Mail-Servers** | Die öffentliche(n) IP-Adresse(n) dieses Servers. Fügen Sie weitere IP-Adressen hinzu, falls der Server über mehrere Adressen erreichbar ist. |
| **DNS** | DNS des Hosts, der zur Auflösung von MX- und anderen DNS-Einträgen verwendet wird. |

### Schritt 14 - E-Mail-Transport konfigurieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Sie werden zum HIN-Gateway-Dashboard auf der Seite `Domains` angemeldet.

 <br> ![Screenshot](assets/installation-guide/step14-dashboard-domains.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

#### Seite "Domains"

!!! info Hinweis zu Multi-Domain-Migrationen
    Führen Sie den Vorgang bei einer Multi-Domain-Migration für jede aktive Domäne durch.

Im Menü **Domains** können Sie für jede verfügbare Domäne eine spezifische Transportroute konfigurieren:

![Bildschirm für die Domänen-Transportkonfiguration](assets/installation-guide/step14-domain-mail-transport.png)

| Einstellung | Beschreibung |
| --------- | ------------- |
| **Inbound relay** | Der SMTP-Relay für die eingehende Zustellung der ausgewählten Domäne. |
| **Outbound relay** | Der SMTP-Relay für die ausgehende Zustellung der ausgewählten Domäne. Diese Einstellung entspricht der Einstellung `Forwarding server` des alten MGW. |
| **Trusted networks** | Zusätzliche Netzwerke, denen die Weiterleitung über dieses Gateway gestattet ist. Weitere Informationen finden Sie unter "Schritt 18 - Mailserver konfigurieren". |
| **Configure TLS** | TLS-Zertifikateinstellungen für SMTP-Verbindungen; über die Schaltfläche `Generate TLS certificate` können Sie ein TLS-Zertifikat erzeugen. |
| **Email authentication** | Alle Einstellungen unter dem Abschnitt `Email authentication` sind im Abschnitt [Email authentication (DKIM ARC SPF DMARC)](Email-authentication-DKIM-ARC-SPF-DMARC.md) beschrieben. |

??? tip "Wie testet man eine TLS-Verbindung?"
    Sie können jederzeit testen, ob das konfigurierte TLS-Zertifikat auf Ihre Verbindung zum HIN Gateway angewendet wurde. Führen Sie den folgenden Befehl direkt im Terminal des HIN Gateways aus:

    ```bash
    openssl s_client -connect 127.0.0.1:25 -starttls smtp -servername mail.<YOUR_DOMAIN>
    ```

    Oder direkt auf Ihrem lokalen Rechner:

    ```bash
    openssl s_client -connect <HIN Gateway IP>:25 -starttls smtp -servername mail.<YOUR_DOMAIN>
    ```

    In der Ausgabe sehen Sie alle Daten zu Ihrer TLS-Verbindung und zum verwendeten Zertifikat.

??? question "Wie konvertiert man ein `pfx`- in ein `pem`-TLS-Zertifikat?"
    Verwenden Sie den folgenden openssl-Befehl:

    ```bash
    openssl pkcs12 -in <Certificate>.pfx -out <Certificate>.pem -nodes
    ```

    Z. B.:

    ```bash
    openssl pkcs12 -in certificate.pfx -out keyStore.pem -nodes
    # Manchmal müssen Sie bei Systemen mit älteren Zertifikatsgeneratoren das Argument -legacy hinzufügen
    openssl pkcs12 -in certificate.pfx -out keyStore.pem -nodes -legacy
    ```

Weitere Aktionen:

- Fügen Sie bei Bedarf weitere Domains hinzu, indem Sie auf "Add domain" klicken.
    - Ist eine Domäne nicht HIN-gesichert, erscheint sie in der Liste `Domains` mit dem Typ "Routed", das heisst, sie kann nur lokal verwaltet werden.

!!! note
    Stellen Sie sicher, dass alle Konfigurationen für Relay-Hosts und Domains korrekt sind, bevor Sie fortfahren.

Sobald die Konfiguration überprüft und abgeschlossen ist, klicken Sie auf "Save", um fortzufahren.

#### Seite "Settings"

Konfigurieren Sie auf dieser Seite im Menü `Settings` Ihre globalen E-Mail-Transporteinstellungen für die sichere Mail-Relay-Einrichtung, die für die gesamte Instanz gelten. Die detaillierte Konfiguration für jede Domäne erfolgt unter `Domains` → `$domain`.

![Bildschirm für die E-Mail-Transport-Konfiguration](assets/installation-guide/step14-mail-transport2.png)

Die folgenden Einstellungen stehen im Menü `Settings` zur Verfügung:

| Einstellung | Beschreibung |
| --------- | ------------- |
| **Mail server host name** | Der FQDN dieser Mail-Gateway-Instanz (z. B. `mail.example.com`). |
| **Mail server IP addresses** | Die öffentliche(n) IP-Adresse(n) dieses Servers. Fügen Sie weitere IP-Adressen hinzu, falls der Server über mehrere Adressen erreichbar ist. |
| **DNS** | DNS des Hosts, der zur Auflösung von MX- und anderen DNS-Einträgen verwendet wird. |
| **Default inbound relay** | Der Standard-SMTP-Relay für die eingehende Zustellung. |
| **Default outbound relay** | Der Standard-SMTP-Relay für die ausgehende Zustellung. |

### Schritt 15 - Whitelist-Header konfigurieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

!!! info Hinweis zu Multi-Domain
    Führen Sie den Vorgang bei Multi-Domain-Konfigurationen für jede aktive Domäne durch.

Klicken Sie auf "Domains" und wählen Sie anschliessend "Whitelist headers" aus.

Geben Sie den Schlüssel genau so ein, wie er auf dem Mailserver konfiguriert ist.

![Screenshot](assets/step_15_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Schritt 16 - Peer-Zertifikate

![Verantwortlichkeit HIN](https://img.shields.io/badge/Verantwortlichkeit-HIN-orange)

Peer-Zertifikate werden von der HIN Zertifizierungsstelle (HIN CA) für aktivierte Domains ausgestellt.

Sobald das Onboarding abgeschlossen ist, navigieren Sie im Dashboard zum Abschnitt "Peer certificates" und klicken Sie auf die Schaltfläche "Sync certificates", um Ihre Peer-Zertifikate von der HIN CA zu synchronisieren.

![Bildschirm für Peer-Zertifikate](assets/installation-guide/step15-peer-certificates.png)

### Schritt 17 - Peer-Zertifikate validieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Stellen Sie sicher, dass Ihre Domain ihr richtlinienbasiertes Peer-Zertifikat unter "Domains" erhalten hat. Der Status jeder Domäne muss "Good" lauten.

![Screenshot](assets/step_17_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

!!! question
    Wenden Sie sich bei Problemen per E-Mail oder Telefon an den HIN Support (**support@hin.ch** / **0848 830 740**).

### Schritt 18 - Mailserver und HIN Gateway konfigurieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Wenn Sie die empfohlene Vorgehensweise befolgt haben, d. h. den privaten Schlüssel exportiert, ihn in das HIN Gateway importiert und **dieselbe IP-Adresse** wie beim bestehenden MGW beibehalten haben, sind auf dem E-Mail-Server keine Änderungen erforderlich.

Andernfalls konfigurieren Sie Ihren Mailserver oder die zugehörigen Komponenten so, dass der Datenverkehr über das neue HIN Gateway geleitet wird. Überprüfen Sie die folgenden Einstellungen und passen Sie diese gegebenenfalls an:

#### E-Mail-Server

- SMTP-Relay / Smart Host
- Konnektoren
- Transportregeln
- Routing-Domänen

Siehe [Exchange-Integration](Exchange-integration.md) für detaillierte Anweisungen.

#### Konfiguration HIN Gateway

#### Seite "Domains"

!!! info Hinweis zu Multi-Domain-Migrationen
    Führen Sie den Vorgang bei einer Multi-Domain-Migration für jede aktive Domäne durch.

Im Menü **Domains** können Sie für jede verfügbare Domäne eine spezifische Transportroute konfigurieren:

| Einstellung | Beschreibung |
| --------- | ------------- |
| **Inbound relay** | Der SMTP-Relay für die eingehende Zustellung der ausgewählten Domäne. |
| **Outbound relay** | Der SMTP-Relay für die ausgehende Zustellung der ausgewählten Domäne. Diese Einstellung entspricht der Einstellung `Forwarding server` des alten MGW. |
| **Trusted networks** | Zusätzliche Netzwerke, denen die Weiterleitung über dieses Gateway gestattet ist. Weitere Informationen finden Sie unter "Schritt 18 - Mailserver konfigurieren". |
| **Configure TLS** | TLS-Zertifikateinstellungen für SMTP-Verbindungen; über die Schaltfläche `Generate TLS certificate` können Sie ein TLS-Zertifikat erzeugen. |
| **Email authentication** | Alle Einstellungen unter dem Abschnitt `Email authentication` sind im Abschnitt [Email authentication (DKIM ARC SPF DMARC)](Email-authentication-DKIM-ARC-SPF-DMARC.md) beschrieben. |

- **Hinweis für das Migrationsszenario:** Gehen Sie auf die Seite jeder Domäne und fügen Sie einen **Outbound host** hinzu, wobei Sie den Wert verwenden, den Sie vom MGW unter `Forwarding server` in "Schritt 1.2 - Sichern des bestehenden MGWs" notiert haben.

  <br> ![domain-relay-host](assets/installation-guide/step18-add-domain-relay.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

- Wenn Sie Microsoft 365 / Exchange Online verwenden, fügen Sie die veröffentlichten ausgehenden IP-Adressbereiche unter **`Trusted networks`** hinzu, damit das HIN Gateway E-Mails aus Exchange Online als vertrauenswürdig einstuft und weiterleitet:

    ```text
    40.92.0.0/15
    40.107.0.0/16
    51.4.72.0/24
    51.4.80.0/27
    51.5.72.0/24
    51.5.80.0/27
    52.100.0.0/14
    104.47.0.0/17
    2a01:111:f400::/48
    2a01:111:f403::/48
    2a01:4180:4050:400::/64
    2a01:4180:4050:800::/64
    2a01:4180:4051:400::/64
    2a01:4180:4051:800::/64
    ```

  <br> ![domain-relay-host](assets/installation-guide/step14-domain-mail-transport.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

#### Seite "Settings"

Konfigurieren Sie auf dieser Seite im Menü `Settings` Ihre globalen E-Mail-Transporteinstellungen für die sichere Mail-Relay-Einrichtung, die für die gesamte Instanz gelten. Die detaillierte Konfiguration für jede Domäne erfolgt unter `Domains` → `$domain`.

![Bildschirm für die E-Mail-Transport-Konfiguration](assets/installation-guide/step14-mail-transport2.png)

Die folgenden Einstellungen stehen im Menü `Settings` zur Verfügung:

| Einstellung | Beschreibung |
| --------- | ------------- |
| **Mail server host name** | Der FQDN dieser Mail-Gateway-Instanz (z. B. `mail.example.com`). |
| **Mail server IP addresses** | Die öffentliche(n) IP-Adresse(n) dieses Servers. Fügen Sie weitere IP-Adressen hinzu, falls der Server über mehrere Adressen erreichbar ist. |
| **DNS** | DNS des Hosts, der zur Auflösung von MX- und anderen DNS-Einträgen verwendet wird. |
| **Default inbound relay** | Der Standard-SMTP-Relay für die eingehende Zustellung. |
| **Default outbound relay** | Der Standard-SMTP-Relay für die ausgehende Zustellung. |

<br> ![domain-relay-host](assets/installation-guide/step14-mail-transport2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Schritt 19 - Test und Validierung

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

**Ausgehend:**

- Stellen Sie sicher, dass der Mailserver so konfiguriert ist, dass er E-Mails über ein SMTP-Relay oder einen Exchange-Konnektor an das HIN Gateway versendet.
- Stellen Sie sicher, dass das HIN Gateway E-Mails an Empfänger ausserhalb der HIN Community versenden kann.
- Stellen Sie sicher, dass das HIN Gateway E-Mails über WireGuard an Empfänger innerhalb der HIN Community senden kann.
- Senden Sie eine E-Mail aus der HIN Community an eine externe E-Mail-Adresse (zum Beispiel Bluewin, Gmail, Yahoo oder GMX) mit dem Vermerk (vertraulich) in der Betreffzeile und überprüfen Sie, ob sie erfolgreich zugestellt wird.

**Eingehender Verkehr:**

- Stellen Sie sicher, dass verschlüsselte E-Mails aus der HIN Community über WireGuard empfangen werden können. Ein Absender aus der Domäne `hin.ch` ist der einfachste Testweg.
- Stellen Sie sicher, dass verschlüsselte E-Mails aus der HIN Community über SMTP unter Verwendung von S/MIME empfangen werden können.
- Stellen Sie sicher, dass Antworten von Absendern ausserhalb der HIN Community auf eine erste sichere E-Mail (HIN Mail-SEAL) das HIN Gateway erreichen können.
- Stellen Sie sicher, dass unverschlüsselte E-Mails von externen Absendern ausserhalb der HIN Community empfangen werden können.
- Senden Sie eine E-Mail von einer externen E-Mail-Adresse an die HIN Community und überprüfen Sie, ob sie erfolgreich empfangen wird.

Bestätigen:

- E-Mails werden in beide Richtungen zwischen der vertrauenswürdigen HIN-Domain und externen E-Mail-Adressen erfolgreich zugestellt.
- Verschlüsselung wird angewendet, wo erforderlich.
- Es treten keine unerwarteten Verzögerungen oder Bounces auf.
- Die Protokollierung ist erfolgreich.

Füllen Sie das [**Abnahmeprotokoll**](https://www.hin.ch/files/pdf1/gateway-abnahme-de.pdf) aus und senden Sie es an Ihren HIN Ansprechpartner zurück.

### Schritt 20 - Passwort der VM ändern

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Bitte stellen Sie sicher, dass die Ihnen ursprünglich zur Verfügung gestellten Zugangsdaten für die VM in ein von Ihnen selbst festgelegtes Passwort geändert werden, und bewahren Sie dieses an einem sicheren und geschützten Ort auf.

### Schritt 21 - Bestehendes MGW ausser Betrieb nehmen

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

!!! info Gilt nur für Migrationsfälle
    Dieser Schritt gilt nur für Einzel- und Multi-Domain-Migrationen

!!! warning
    Löschen Sie die bestehende MGW-VM nicht sofort, sondern bewahren Sie sie sicher auf, bis alles betriebsbereit ist.

1. **Stellen Sie sicher, dass kein aktiver Datenverkehr vorhanden ist**: Überprüfen Sie:
    - Es verweisen keine Domains auf das MGW (DNS, SMTP, Konnektoren).
    - Es werden keine E-Mails über die alte Appliance weitergeleitet.
2. **Protokolle archivieren**: Exportieren und speichern Sie:
    - E-Mail-Protokolle
    - Sicherheits-/Audit-Protokolle
    - erforderlich für Compliance und Fehlerbehebung
3. **Bereinigung (optional)**: Entfernen Sie:
    - Firewall-Regeln
    - DNS-Einträge
    - Routing-Konfigurationen, die auf das bestehende MGW verweisen

## Anhang 1 - Sichern und Wiederherstellen der Appliance-Einstellungen

!!! info Gilt nur für Migrationsfälle
    Dieser Schritt gilt nur für Einzel- und Multi-Domain-Migrationen

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Um die Einstellungen Ihrer HIN Appliance zu sichern oder wiederherzustellen, klicken Sie im Web-Verwaltungsportal auf das Menü "Administration".

![Screenshot](assets/annex_1_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Einstellungen sichern

Bevor Sie ein Backup der aktuellen HIN Geräteeinstellungen erstellen, müssen Sie ein Backup-Passwort festlegen. Dieses Passwort wird benötigt, falls Sie das Backup später wiederherstellen müssen.

- Um das Sicherungskennwort festzulegen oder zu ändern, klicken Sie auf "Change Password".
- Um eine Sicherungsdatei zu erstellen und herunterzuladen, klicken Sie auf "Download".

### Sicherungspasswort ändern

Um das Passwort für zukünftige Sicherungen zu ändern, klicken Sie auf "Change Password".

!!! note
    Bitte beachten Sie, dass das neue Passwort nur für Sicherungen gilt, die nach der Passwortänderung erstellt werden. Bestehende Sicherungsdateien bleiben durch das Passwort geschützt, das bei ihrer Erstellung festgelegt wurde.

### Einstellungen wiederherstellen

Um die Geräteeinstellungen aus einer Sicherungsdatei wiederherzustellen, klicken Sie auf "Importieren Backup File...".

Wählen Sie im Dialogfenster die gewünschte Sicherungsdatei aus und geben Sie das zu dieser Sicherung gehörige Passwort ein. Die Geräteeinstellungen werden anschliessend aus der ausgewählten Sicherungsdatei wiederhergestellt.

### Sicherung über SCP

Das MGW unterstützt die Sicherung des Geräts über SCP.

Um diese Option zu nutzen, muss der öffentliche Schlüssel des Systems, das auf den MGW zugreifen soll, unter "Backup using SCP" hinterlegt sein. Die Sicherungsdatei wird täglich um Mitternacht automatisch erstellt und auf dem MGW als `backup.tgz` gespeichert.

Mit dem konfigurierten öffentlichen Schlüssel kann die Sicherungsdatei über SCP mit dem Betriebssystembenutzer `backup` abgerufen werden. Ein typischer SCP-Befehl zum Abrufen der Sicherungsdatei lautet:

```bash
scp backup@192.168.1.60:/backup.tgz .
```

Dieser Befehl lädt die Datei `backup.tgz` vom MGW in das aktuelle lokale Verzeichnis herunter.

!!! note
    Wenn Sie einen neuen öffentlichen Schlüssel eingeben, wird der bestehende Schlüssel ersetzt.
