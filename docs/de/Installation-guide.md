# HIN Mail Gateway - Technischer Installationsprozess

!!! tip
    Technischer Installationsprozess für Single-Domain-Mailarchitekturen mit Microsoft 365

## Einführung

Dieses Dokument bietet eine umfassende Anleitung für den technischen Installations- und Migrationsprozess zum neuen [HIN Gateway](https://www.hin.ch/de/services/hin-mail/hin-gateway.cfm) („Stargate-Appliance“). Es gilt für Microsoft-365-Mailarchitekturen, die eine einzige vertrauenswürdige Domain verwenden.

Der Leitfaden richtet sich an HIN-Kunden, IT-Administratoren und Systemingenieure, die für die Bereitstellung und Konfiguration des neuen HIN Gateways sowie für die Migration vom bestehenden Mail Gateway (MGW) verantwortlich sind.

Das HIN Gateway ist eine sichere E-Mail-Gateway-Lösung, die vertrauenswürdige, verschlüsselte und richtliniengesteuerte Kommunikation innerhalb des HIN-Vertrauenskreises ermöglicht. Es fungiert als zentrale Schnittstelle zwischen internen E-Mail-Infrastrukturen und externen Kommunikationspartnern und stellt sicher, dass der gesamte E-Mail-Verkehr sicher übertragen wird, den Richtlinien der Organisation entspricht und die Sicherheitsstandards von HIN erfüllt.

## Übersicht des Mail-Flows

- **Eingehende E-Mails** werden über das HIN Gateway geleitet, wo sie validiert, entschlüsselt (falls erforderlich) und gegen Vertrauens- und Sicherheitsrichtlinien geprüft werden, bevor sie an den internen Mailserver weitergeleitet werden.
- **Ausgehende E-Mails** werden von internen Systemen an das HIN Gateway gesendet, wo Verschlüsselung, Routing und Richtliniendurchsetzung angewendet werden, bevor sie an externe Empfänger übertragen werden.
- **Die Kommunikation zwischen HIN Gateways** wird durch Peer-Zertifikate und WireGuard-Tunnel gesichert, um eine vertrauenswürdige Kommunikation zwischen Domänen zu gewährleisten.

## Installations- und Migrationsprozess

Das in diesem Dokument beschriebene strukturierte, schrittweise Verfahren umfasst folgende Punkte:

1. Vorbereitung und Fallback-Planung
2. Installation und Konfiguration des HIN Gateways
3. Domain Aktivierung und Zertifikatsvalidierung
4. Integration des Mailservers und Routing Konfiguration
5. Testen, Übergang in den Produktivbetrieb und Validierung nach der Migration
6. Ausserbetriebnahme des bestehenden MGW

Das Ziel von HIN in diesem Prozess ist es, eine sichere, reibungslose und vollständig validierte Migration zu gewährleisten, die minimale Betriebsunterbrechungen verursacht und die unterbrechungsfreie Kontinuität der E-Mail-Dienste garantiert.

## Häufig gestellte Fragen

!!! question "Kann ich die Installation und Migration selbst durchführen?"
    Ja, die Installation und Migration können vollständig vom Kunden durchgeführt werden, mit Ausnahme von „[Schritt 1.3 - Export privater Schlüssel(s)](#schritt-13-export-privater-schlussels)“.

    Aus Sicherheitsgründen und um Ihren privaten Schlüssel zu schützen, müssen Sie den HIN Support kontaktieren oder an der geplanten Migrationssitzung teilnehmen, um den Code zu erhalten, der für den Export des privaten Schlüssels vom derzeit betriebenen Mail Gateway erforderlich ist.

    Falls die Installation und Migration nicht erfolgreich abgeschlossen werden können, nehmen Sie bitte an der geplanten Support-Sitzung mit unseren Ingenieuren teil.


!!! question "Kommt es während der Migration zu einer Unterbrechung der E-Mail-Zustellung?"
    Zwischen „[Schritt 1.5 - Herunterfahren der bestehenden MGW-VM](#schritt-15-herunterfahren-der-bestehenden-mgw-vm)“ und „Schritt 18 - Konfiguration des Mailservers“ werden alle E-Mails auf dem Mailserver in die Warteschlange gestellt. Sobald „Schritt 18 - Konfiguration des Mailservers“ abgeschlossen ist, werden die in der Warteschlange befindlichen E-Mails versendet oder zugestellt.

!!! question "Gehen während der Installation und Migration E-Mails verloren?"
    Nein, es gehen keine E-Mails während der Installation und Migration verloren.

## Übersicht der Installationsschritte

| Schritt | Thema | Verantwortlichkeit |
| :--: | :---- | :------------: |
| 0 | Voraussetzungen prüfen | Kunde |
| 1.1 | Smoke-Test | Kunde |
| 1.2 | Backup des bestehenden MGW | Kunde |
| 1.3 | Export privater Schlüssel(s) | Kunde / HIN |
| 1.4 | Notfallplan / Fallback-Szenario | Kunde |
| 1.5 | Herunterfahren der bestehenden MGW-VM | Kunde |
| 2 | WireGuard | Kunde |
| 3 | Ziel-VM auswählen | Kunde |
| 4 | VM-Image laden | Kunde |
| 5 | Netzwerkverbindung zur VM | Kunde |
| 6 | Zugriff über den Browser | Kunde |
| 7 | Aktivierungscode eingeben | Kunde |
| 8 | Mesh-Netzwerk einrichten | Kunde |
| 9 | Sicheres Mesh-Netzwerk aufbauen | Kunde |
| 10 | Anmeldung bei Keycloak | Kunde |
| 11 | Passwort aktualisieren | Kunde |
| 12 | Kontoinformationen aktualisieren | Kunde |
| 13 | Initiale Konfiguration und Domain-Einrichtung   | Kunde |
| 14 | Mail-Transport konfigurieren | Kunde |
| 15 | Whitelist-Header konfigurieren | Kunde |
| 16 | Peer-Zertifikate | HIN |
| 17 | Peer-Zertifikate validieren | Kunde |
| 18 | Mailserver konfigurieren | Kunde |
| 19 | Test vor der Umstellung | Kunde |
| 20 | Validierung nach der Umstellung | Kunde |
| 21 | Bestehendes MGW ausser Betrieb nehmen | Kunde |
| 22 | Passwort der VM ändern | Kunde |
| Anhang 1| Backup und Wiederherstellung der Appliance-Einstellungen | Kunde |

## Detaillierte Schritte

### Schritt 0 - Voraussetzungen prüfen

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Bitte lesen Sie die „Stargate Deployment Instructions“ durch und stellen Sie sicher, dass alle notwendigen Vorbereitungsschritte vor Beginn der HIN-Gateway-Migrationsaktivitäten abgeschlossen sind.

Folgende Punkte müssen vor der Migration verfügbar oder bestätigt sein:

- **Zugangsdaten werden Ihnen von HIN zugestellt**:
    - VM-Zugangsdaten
    - Keycloak-Zugangsdaten
    - Aktivierungscode
- **Export des privaten Schlüssels**
    - Falls Sie an einem Windows-Rechner arbeiten, der über Port 22 Zugriff auf die Mail Gateway-VM hat, können wir Sie während des Anrufs unterstützen, um den Export des privaten Schlüssels vom MGW zu aktivieren.
    - Falls Sie keinen Zugriff auf einen solchen Rechner haben, wenden Sie sich bitte an den HIN Support per E-Mail oder Telefon (support@hin.ch / 0848 830 740), um eine Support-Verbindung über Systemverwaltung --> Support-Verbindung --> Verbinden herzustellen.
- **Laden Sie die neueste Version** des [VM-Images](vm/VM-Catalog.md) herunter.
- **Firewall-Anforderungen** für WireGuard. Konfigurieren Sie den WireGuard-Port 19818 (TCP/UDP) in Ihrer Firewall:
    - Eingehender und ausgehender Verkehr
    - Verkehr zulassen: any-to-HIN Gateway und HIN Gateway-to-any
- **DHCP-Zugriff** sollte für „[Schritt 5 - Netzwerkverbindung zur VM](#schritt-5-netzwerkverbindung-zur-vm)“ verfügbar sein (empfohlen).
- **Backup-Anforderungen** - siehe „[Anhang 1 - Backup und Wiederherstellung der Appliance-Einstellungen](#anhang-1-backup-und-wiederherstellung-der-appliance-einstellungen)“.
- Bestätigung, dass das bestehende MGW **nicht gelöscht wird**, bis die Abnahme abgeschlossen ist.
- Zugriff auf DNS, Mailserver-Connectors, Transportregeln und Relay-Einstellungen.

!!! info "Warum WireGuard?"
    Der WireGuard-Port erfüllt zwei wichtige Funktionen:
    1. Das HIN Gateway nutzt diesen Port, um Peer-Zertifikate von der HIN-CA zu beziehen.
    2. Es nutzt diesen Port, um einen sicheren Tunnel zu anderen HIN Gateways aufzubauen, über den der sichere Datenaustausch (z. B. E-Mail-Verkehr) erfolgt.

!!! tip "Export des privaten Schlüssels"
    Falls Sie an einem Windows-Rechner arbeiten, der über Port 22 Zugriff auf die Mail Gateway-VM hat, können wir Sie während des Anrufs unterstützen, um den Export des privaten Schlüssels vom MGW zu aktivieren.

    Falls Sie keinen Zugriff auf einen solchen Rechner haben, wenden Sie sich bitte an den HIN Support per E-Mail oder Telefon (support@hin.ch / 0848 830 740), um eine Support-Verbindung über Systemverwaltung --> Support-Verbindung --> Verbinden herzustellen.

### Schritt 1.1 - Smoke-Test

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Senden Sie eine Test-E-Mail an folgende Empfänger, bei denen Sie Zugriff auf das Postfach haben, um den korrekten Empfang zu überprüfen:

- Eine HIN-E-Mail-Adresse oder HIN-Community-Domain von Ihnen, z. B.: `user@hin.ch`
- Eine E-Mail-Adresse ausserhalb der HIN-Community, z. B.: `user@bluewin.ch`

Überprüfen Sie, ob beide E-Mails inklusive Betreff, Inhalt und Anhang (falls gesendet) erfolgreich zugestellt wurden.

### Schritt 1.2 - Backup des bestehenden MGW

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Erstellen Sie ein Backup der bestehenden MGW-Appliance und stellen Sie sicher, dass die VM bis zur erfolgreichen Fertigstellung und formalen Abnahme der Migration aufbewahrt wird. Weitere Informationen finden Sie in „[Anhang 1 - Backup und Wiederherstellung der Appliance-Einstellungen](#anhang-1-backup-und-wiederherstellung-der-appliance-einstellungen)“.

### Schritt 1.3 - Export privater Schlüssel(s)

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)
:heavy_plus_sign:
![Verantwortlichkeit HIN](https://img.shields.io/badge/Verantwortlichkeit-HIN-orange)

!!! warning "Unterstützung durch HIN erforderlich"
    Dieser Schritt erfordert einen Freischaltcode, der von einem HIN-Support-Ingenieur während des geplanten Anrufs bereitgestellt wird. Kontaktieren Sie den HIN Support oder nehmen Sie an der geplanten Migrationssitzung teil, bevor Sie beginnen.

<!-- !!! info
    Bitte laden Sie das Tool `HIN_Migration-Tool_v*.exe` unter folgendem Link herunter: [link](https://link) -->

1. Melden Sie sich in der bestehenden MGW-WebGUI an.
2. Öffnen Sie „**Mail System**“.
3. Führen Sie die Anwendung **`HIN_Migration-Tool_v*.exe`** aus, die Ihnen der Support-Ingenieur während des Anrufs zur Verfügung stellt.
4. Geben Sie den Freischaltcode ein, den Ihnen der Support-Ingenieur mitteilt.
5. Wählen Sie „**Enable export**“.
6. Geben Sie die MGW-IP-Adresse ein.
7. Warten Sie auf die Bestätigung.
8. Wählen Sie die vertrauenswürdige Domain(e) in der MGW-WebGUI aus.
9. Scrollen Sie nach unten und wählen Sie den verwalteten Fingerabdruck aus.
10. Scrollen Sie nach unten zur Kategorie „**PKCS12-Download**“ (Sie können optional ein Passwort zur Verschlüsselung des Schlüssels eingeben). Drücken Sie „PKCS12 herunterladen“ und speichern Sie die `*.p12`-Datei auf Ihrem Rechner.
11. Kehren Sie zur Anwendung `HIN_Migration-Tool_v*.exe` zurück und deaktivieren Sie die Schaltfläche **„Export“**.

### Schritt 1.4 - Notfallplan / Fallback-Szenario

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

**Rollback-Szenario** - falls ein Rollback erforderlich ist:

1. Stoppen Sie das neue HIN Gateway.
2. Schalten Sie das bestehende MGW ein.
3. Überprüfen Sie, ob der eingehende und ausgehende E-Mail-Verkehr über das bestehende MGW korrekt funktioniert.

### Schritt 1.5 - Herunterfahren der bestehenden MGW-VM

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Fahren Sie die bestehende MGW-VM herunter.

!!! warning
    Dieser Schritt unterbricht den Mail-Flow. Während der Unterbrechung werden E-Mails auf dem Mailserver in die Warteschlange gestellt und nach Abschluss der Installation zugestellt (siehe „[Schritt 18 - Mailserver konfigurieren](#schritt-18-mailserver-konfigurieren)“).

### Schritt 2 - WireGuard

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Stellen Sie sicher, dass Sie den WireGuard-Port 19818 (TCP/UDP) in Ihrer Firewall konfiguriert haben:

- Eingehender und ausgehender Verkehr
- Verkehr zulassen: any-to-HIN Gateway und HIN Gateway-to-any

### Schritt 3 - Ziel-VM auswählen

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Wählen Sie eines der verfügbaren virtuellen Images aus und stellen Sie es gemäss der Installationsanleitung auf der HIN-Gateway-Service-Seite bereit:

!!! info
    Aus Sicherheits- und Supportgründen stellen Sie sicher, dass Ihr Hypervisor nicht in einer End-of-Life-Version betrieben wird. Die HIN-Gateway-Appliance wird auf der neuesten Hypervisor-Version und der unmittelbar vorhergehenden Hauptversion unterstützt.

- VM-Image-Installation:
    - [Azure-VM-Image](vm/Azure-image-install.md)
    - [Windows 11 Pro (Hyper-V)-Image](vm/Windows11pro-image-install.md)
    - [VMware-Image](vm/VMware-image-install.md)
    - [Proxmox-Image](vm/Proxmox-image-install.md)
    - [Cloudscale](vm/Cloudscale-image-install.md)
- [Konfiguration von Microsoft Exchange](Exchange-integration.md)

### Schritt 4 - VM-Image laden

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Laden Sie das ausgewählte VM-Image in Ihren Hypervisor hoch.

### Schritt 5 - Netzwerkverbindung zur VM

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Stellen Sie sicher, dass die VM über eine Netzwerkverbindung verfügt und ihr eine statische IP-Adresse zugewiesen wurde.

**Option A:** Konfigurieren Sie die IP-Adresse der virtuellen Maschine direkt im verwendeten Hypervisor.

**Option B:** Sie können den DHCP-Server Ihres Routers so konfigurieren, dass er der VM immer dieselbe IP-Adresse basierend auf der MAC-Adresse der VM zuweist.

**Option C:** Melden Sie sich lokal über die VM-Konsole an und konfigurieren Sie manuell eine statische IP-Adresse.

**HINWEIS:** Das VM-Image führt beim ersten Start eine automatische Installation durch. Wenn das Netzwerk zu diesem Zeitpunkt nicht konfiguriert ist, schlägt die Installation fehl, weil die IP-Adresse des Servers nicht ermittelt werden kann.

**IP-Adresse unter Linux hinzufügen:**

1. Führen Sie den Befehl `nmtui` in der Konsole aus.
    ```bash
    nmtui
    ```
2. Navigieren Sie mit den Pfeiltasten und drücken Sie „Enter“, um die „Ethernet-Verbindung“ auszuwählen, für die Sie die IP-Adresse ändern möchten. <br> ![IP-Adresse hinzufügen](assets/ip_addr_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
3. Navigieren Sie zu „IPv4-Konfiguration“ und ändern Sie die Einstellung von „Automatisch“ auf „Manuell“. <br> ![IP-Adresse hinzufügen](assets/ip_addr_2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
4. Navigieren Sie mit den Pfeiltasten zu den Feldern, in denen Sie die IP-Adresse, das Gateway und den DNS-Server eingeben können. Wählen Sie dann „OK“. <br> ![IP-Adresse hinzufügen](assets/ip_addr_3.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
5. Führen Sie nach dem Speichern der IP-Adresskonfiguration folgenden Befehl in der Konsole aus:
    ```bash
    sudo systemctl restart NetworkManager
    ```

??? warning "Netzwerk muss vor dem ersten Start konfiguriert sein"
    Das VM-Image führt beim ersten Start eine automatische Installation durch. Wenn das Netzwerk noch nicht konfiguriert ist (keine IP-Adresse per DHCP oder statische Konfiguration zugewiesen), schlägt die Installation fehl, weil die Server-IP nicht erkannt werden kann.

    Falls dies passiert, konfigurieren Sie das Netzwerk manuell und führen Sie dann aus:

    ```bash
    cd /root/stargate-deployment/docker-compose
    ./scripts/purge.sh
    ./scripts/install.sh
    ```

    Das Installationsskript erkennt die Server-IP automatisch aus der Standardroute. Jede erreichbare IP (öffentlich oder privat) reicht aus - der eigentliche öffentliche Endpunkt wird später über das Dashboard konfiguriert.

!!! tip
    Falls Sie Option C verwendet und das Netzwerk manuell konfiguriert haben, müssen Sie folgende Befehle ausführen:

    ```bash
    cd /root/stargate-deployment/docker-compose
    ./scripts/purge.sh
    ./scripts/install.sh
    ```

    Das Installationsskript erkennt die Server-IP automatisch aus der Standardroute. Jede erreichbare IP-Adresse (öffentlich oder privat) reicht aus. Der eigentliche öffentliche Endpunkt wird später über das Dashboard konfiguriert.

    Nach erfolgreicher Ausführung der Skripte fahren Sie mit „[Schritt 6 - Zugriff über den Browser](#schritt-6-zugriff-uber-den-browser)“ fort.

    !!! question
        Falls Sie nicht über die HIN-Admin-Zugangsdaten verfügen, wenden Sie sich bitte an den HIN Support per E-Mail oder Telefon (support@hin.ch / 0848 830 740). Siehe [Support-Bereich](./Support.md).

        [Klicken Sie hier, um eine E-Mail zu senden](mailto:support@hin.ch?subject=Passwort%20für%20VM-Installation%20erforderlich.&body=Sehr%20geehrter%20Support,%0A%0Aich%20benötige%20das%20Passwort%20für%20eine%20VM-Installation.%0A%0ABITTE%20GEBEN%20SIE%20HIER%20IHRE%20KUNDENINFORMATIONEN%20AN){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Schritt 6 - Zugriff über den Browser

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Öffnen Sie einen Browser und geben Sie die für die VM konfigurierte IP-Adresse ein. Sie sollten den initialen Setup-Bildschirm sehen.

```plain
https://<VM-IP-Adresse>
```

### Schritt 7 - Aktivierungscode eingeben

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Wählen Sie Ihre bevorzugte Sprache aus und geben Sie den Aktivierungscode ein, den Sie per E-Mail von HIN erhalten haben. Klicken Sie auf „Weiter“.

![Bildschirm zur Eingabe des Aktivierungscodes](assets/installation-guide/step7-activation-code.png)

!!! question
    Falls Sie nicht über den Aktivierungscode verfügen, wenden Sie sich bitte an den HIN Support per E-Mail oder Telefon (support@hin.ch / 0848 830 740). Siehe [Support-Bereich](Support.md).

    [Klicken Sie hier, um eine E-Mail zu senden](mailto:support@hin.ch?subject=Aktivierungscode%20erforderlich.&body=Sehr%20geehrter%20Support,%0A%0Aich%20benötige%20den%20Aktivierungscode%20für%20meine%20HIN-Gateway-Installation.%0A%0ABITTE%20GEBEN%20SIE%20HIER%20IHRE%20KUNDENINFORMATIONEN%20AN){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Schritt 8 - Mesh-Netzwerk einrichten

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Überprüfen Sie die Mesh-Netzwerk-Konfiguration:

- **IP-Adresse** - Die öffentliche IP des ausgehenden Verkehrs (automatisch erkannt).
- **Transport** - Das Transportprotokoll (Standard: `tcp`).
- **Port** - Der WireGuard-Port (Standard: `19818`).

Bestätigen Sie, dass die Werte korrekt sind, und klicken Sie auf „Weiter“.


![Bildschirm für das Mesh-Netzwerk-Setup](assets/installation-guide/step8-mesh-network.png)

### Schritt 9 - Sicheres Mesh-Netzwerk aufbauen

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Das System baut nun die sichere Mesh-Netzwerkverbindung auf. Dieser Schritt verbindet das HIN Gateway mit dem Iris-Agent und synchronisiert Zertifikate.

Warten Sie, bis der Prozess abgeschlossen ist. Die Statusanzeigen zeigen „Up“ an, wenn die Verbindung erfolgreich hergestellt wurde. Klicken Sie auf „Fertigstellen“.

![Sicheres Mesh-Netzwerk einrichten](assets/installation-guide/step9-mesh-connecting.png)

!!! failure "Falls die Verbindung fehlschlägt"
    Falls der Iris-Agent oder der Zertifikat-Synchronisationsstatus „Down“ bleibt:

    - Überprüfen Sie, ob Port `19818` (TCP/UDP) in Ihrer Firewall geöffnet ist (siehe „Schritt 2 - WireGuard“).
    - Überprüfen Sie, ob die IP-Adresse in „Schritt 8 - Mesh-Netzwerk einrichten“ korrekt und aus dem Internet erreichbar ist.
    - Starten Sie den Prozess neu oder wenden Sie sich an den HIN Support per E-Mail oder Telefon (support@hin.ch / 0848 830 740).

### Schritt 10 - Anmeldung bei Keycloak

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Nach dem Aufbau des Mesh-Netzwerks werden Sie zur Keycloak-Anmeldeseite weitergeleitet. Geben Sie den Benutzernamen und das Passwort ein, die Sie von HIN erhalten haben.

![Keycloak-Anmeldeseite](assets/installation-guide/step10-keycloak-login.png)

!!! question
    Falls Sie nicht über diese Anmeldedaten verfügen, wenden Sie sich bitte an den HIN Support per E-Mail oder Telefon (support@hin.ch / 0848 830 740). Siehe [Support-Bereich](Support.md).

    [Klicken Sie hier, um eine E-Mail zu senden](mailto:support@hin.ch?subject=Keycloak-Anmeldedaten%20erforderlich.&body=Sehr%20geehrter%20Support,%0A%0Aich%20benötige%20die%20Keycloak-Anmeldedaten%20für%20mein%20HIN-Gateway.%0A%0ABITTE%20GEBEN%20SIE%20HIER%20IHRE%20KUNDENINFORMATIONEN%20AN){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Schritt 11 - Passwort aktualisieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Beim ersten Login werden Sie aufgefordert, Ihr Passwort zu ändern. Geben Sie ein neues sicheres Passwort ein und bestätigen Sie es.

![Bildschirm zum Aktualisieren des Passworts](assets/installation-guide/step11-update-password.png)

### Schritt 12 - Kontoinformationen aktualisieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Vervollständigen Sie Ihr Benutzerprofil, indem Sie Ihren Vornamen und Nachnamen eingeben. Die E-Mail-Adresse ist bereits vorausgefüllt. Klicken Sie auf „Absenden“, um fortzufahren.

![Bildschirm zum Aktualisieren der Kontoinformationen](assets/installation-guide/step12-account-info.png)

### Schritt 13 - Initiale Konfiguration und Domain-Einrichtung

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Auf diesem Bildschirm konfigurieren Sie Ihre initialen Einstellungen:

- Überprüfen Sie, ob alle Ihre aktuellen vertrauenswürdigen Domänen innerhalb der HIN-Community korrekt angezeigt werden.
- Wählen Sie aus, welche vertrauenswürdigen Domänen **„Aktiviert“** sein sollen, um Peer-Zertifikate von der HIN-Zertifizierungsstelle (HIN CA) zu erhalten.
- Geben Sie an, für welche Domänen das Präfix `sec.<domain>` bereits konfiguriert ist („sec.-Präfix verwenden“).
- Überprüfen Sie, ob der Organisationsname und die Domain-Besitzer korrekt sind. <br> ![Screenshot](assets/step_13_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" } <br> ![Screenshot](assets/step_13_2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
- Importieren Sie die bestehende S/MIME-Zertifikatsdatei (`.p12`/`.pfx`) vom bestehenden MGW:
    1. Erweitern Sie die Domain und wählen Sie die Option „**P12/PFX-Datei**“.
    2. Falls für die Zertifikatsdatei kein Passwort gesetzt wurde, lassen Sie das Passwortfeld leer.
    3. Klicken Sie auf „**Zertifikat importieren**“.
    4. Nach dem Import des Zertifikats wird die Meldung *Zertifikat erfolgreich importiert* angezeigt.
- Klicken Sie am Ende der Seite auf „**Konfiguration speichern**“, um die Änderungen zu sichern.

![Bildschirm für die Ersteinrichtung](assets/installation-guide/step13-initial-setup.png)

!!! warning
    - Mindestens eine Domain muss **„Aktiviert“** sein, um mit dem Onboarding-Prozess fortzufahren. Die Schaltfläche „Konfiguration speichern“ wird erst aktiv, wenn diese Voraussetzung erfüllt ist.
    - Falls Ihnen auffällt, dass nicht alle vertrauenswürdigen Domänen angezeigt werden oder die Organisationsinformationen nicht korrekt sind, wenden Sie sich bitte an den HIN Support per E-Mail oder Telefon (support@hin.ch / 0848 830 740).

!!! danger "Importieren Sie Ihren bestehenden privaten Schlüssel"
    Falls Sie **keinen** privaten Schlüssel vom bestehenden MGW importieren, wird ein neuer Schlüssel ausgestellt. Dies kann dazu führen, dass Nachrichten bis zu **6 Stunden** lang nicht entschlüsselbar sind, was zu **Datenverlust** führen kann.

### Schritt 14 - Mail-Transport konfigurieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Auf diesem Bildschirm konfigurieren Sie die Mail-Transport-Einstellungen für das sichere Mail-Relay-Setup.

![Bildschirm für die E-Mail-Transport-Konfiguration](assets/installation-guide/step14-mail-transport.png)

Folgende Einstellungen stehen zur Verfügung:

| Einstellung | Beschreibung |
|---------|-------------|
| **Hostname des Mail-Servers** | Der Hostname des internen Mailservers (z.B. `mail.example.com`). |
| **IP-Adressen des Mail-Servers** | Die öffentlichen IP-Adresse(n) dieses Servers. Fügen Sie zusätzliche IPs hinzu, falls der Server über mehrere Adressen erreichbar ist. |
| **Domänen** | Jede Domain, die dieses Gateway verarbeitet, zusammen mit ihrem Relay-Host (dem internen Mailserver, an den eingehende E-Mails zugestellt werden). |
| **Standard-Relay-Host** | Der Standard-SMTP-Relay für den ausgehenden Versand. |

Unter dem „Erweitert“-Bereich können Sie optional Folgendes konfigurieren (`mxengine:1587`):

| Einstellung | Beschreibung |
|---------|-------------|
| **Konfigurieren der TLS** | TLS-Zertifikateinstellungen für SMTP-Verbindungen. |
| **Inhaltsfilter** | Der interne Endpunkt des Inhaltsfilters (Standard: `mxengine:1587`). |
| **Vertrauenswürdige Netzwerke** | Zusätzliche Netzwerke, denen die Weiterleitung über dieses Gateway gestattet ist. |

Zusätzliche Aktionen:

- Fügen Sie bei Bedarf zusätzliche Domänen hinzu, indem Sie auf „Domain hinzufügen“ klicken.
- Erweitern Sie den „Erweitert“-Bereich, um Mail-Transportparameter feinabzustimmen.

!!! note
    Stellen Sie sicher, dass alle Relay-Host- und Domain-Konfigurationen korrekt sind, bevor Sie fortfahren.

Sobald die Konfiguration überprüft und abgeschlossen ist, klicken Sie auf „Konfiguration anwenden“, um fortzufahren.

### Schritt 15 - Whitelist-Header konfigurieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Klicken Sie auf **„Domänen“**, dann wählen Sie **„Whitelist-Header“**.

Geben Sie den Schlüssel genau so ein, wie er im Mailserver konfiguriert ist.

![Screenshot](assets/step_15_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Schritt 16 - Peer-Zertifikate

![Verantwortlichkeit HIN](https://img.shields.io/badge/Verantwortlichkeit-HIN-orange)

Peer-Zertifikate werden von der HIN-Zertifizierungsstelle (HIN CA) für aktivierte Domänen ausgestellt.

Nach Abschluss des Onboardings navigieren Sie zum Bereich **„Peer-Zertifikate“** im Dashboard und klicken Sie auf die Schaltfläche **„Zertifikate synchronisieren“**, um Ihre Peer-Zertifikate von der HIN CA zu synchronisieren.

![Bildschirm für Peer-Zertifikate](assets/installation-guide/step15-peer-certificates.png)

### Schritt 17 - Peer-Zertifikate validieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Stellen Sie sicher, dass Ihre Domain ihr richtlinienbasiertes Peer-Zertifikat unter **„Domänen“** erhalten hat. Der Status jeder Domain muss **„Gut“** sein.

![Screenshot](assets/step_17_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

!!! question
    Falls Probleme auftreten, wenden Sie sich bitte an den HIN Support per E-Mail oder Telefon (support@hin.ch / 0848 830 740).

### Schritt 18 - Mailserver konfigurieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Falls Sie der empfohlenen Vorgehensweise gefolgt sind, indem Sie den privaten Schlüssel exportiert, in das HIN Gateway importiert haben und **dieselbe IP-Adresse** wie beim bestehenden MGW verwenden, sind keine Änderungen am E-Mail-Server erforderlich.

Falls nicht, konfigurieren Sie Ihren Mailserver oder die zugehörigen Komponenten so, dass der Verkehr über das neue HIN Gateway geleitet wird. Überprüfen und aktualisieren Sie bei Bedarf folgende Einstellungen:

- SMTP-Relay / Smart-Host
- Connectors
- Transportregeln
- Routing-Domänen

Siehe [Exchange-Integration](Exchange-integration.md) für detaillierte Anweisungen.

### Schritt 19 - Test vor der Umstellung

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Wiederholen Sie „[Schritt 1.1 - Smoke-Test](#schritt-11-smoke-test)“. Zusätzlich zum Smoke-Test testen und bestätigen Sie bitte Folgendes:

**Ausgehend:**

- Überprüfen Sie, ob der Mailserver so konfiguriert ist, dass E-Mails über einen SMTP-Relay oder Exchange-Connector an das HIN Gateway gesendet werden.
- Überprüfen Sie, ob das HIN Gateway E-Mails an Empfänger ausserhalb der HIN-Community senden kann.
- Überprüfen Sie, ob das HIN Gateway E-Mails über WireGuard an Empfänger innerhalb der HIN-Community senden kann.


**Eingehend:**

- Überprüfen Sie, ob verschlüsselte E-Mails über WireGuard von der HIN-Community empfangen werden können. Ein Absender aus der Domain `hin.ch` ist der einfachste Testpfad.
- Überprüfen Sie, ob verschlüsselte E-Mails über SMTP mit S/MIME von der HIN-Community empfangen werden können.
- Überprüfen Sie, ob Antworten von Absendern ausserhalb der HIN-Community auf eine initiale sichere E-Mail (HIN Mail-SEAL) das HIN Gateway erreichen.
- Überprüfen Sie, ob unverschlüsselte E-Mails von externen Absendern ausserhalb der HIN-Community empfangen werden können.

### Schritt 20 - Validierung nach der Umstellung

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Bestätigen Sie:

- E-Mails wurden zugestellt
- Verschlüsselung wurde angewendet
- Keine Verzögerungen oder Bounces
- Erfolgreiche Protokollierung

Füllen Sie den [„Abnahmebericht“](https://www.hin.ch/files/pdf1/gateway-abnahme-de.pdf) aus und senden Sie ihn an Ihren HIN-Ansprechpartner zurück.

### Schritt 21 - Bestehendes MGW ausser Betrieb nehmen

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

!!! warning
    Löschen Sie die bestehende MGW-VM nicht sofort - bewahren Sie sie auf, bis alles läuft.

1. **Stellen Sie sicher, dass kein aktiver Verkehr mehr besteht** - prüfen Sie:
    - Keine Domänen verweisen mehr auf das MGW (DNS, SMTP, Connectors).
    - Es werden keine E-Mails mehr über das alte Gerät weitergeleitet.
2. **Archivieren Sie Protokolle** - exportieren und sichern Sie:
    - E-Mail-Protokolle
    - Sicherheits-/Audit-Protokolle (erforderlich für Compliance und Fehlerbehebung)
3. **Bereinigung (optional)** - entfernen Sie:
    - Firewall-Regeln
    - DNS-Einträge
    - Routing-Konfigurationen, die auf das bestehende MGW verweisen

### Schritt 22 - Passwort der VM ändern

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Stellen Sie sicher, dass die VM-Zugangsdaten, die Ihnen anfänglich zur Verfügung gestellt wurden, in ein eigenes, sicheres Passwort geändert werden und bewahren Sie diese an einem sicheren Ort auf.

## Anhang 1 - Backup und Wiederherstellung der Appliance-Einstellungen

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Um die Einstellungen Ihrer HIN-Appliance zu sichern oder wiederherzustellen, klicken Sie im Web-Verwaltungsportal auf das Menü **„Administration“**.

![Screenshot](assets/annex_1_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Einstellungen sichern

Bevor Sie ein Backup der aktuellen HIN-Appliance-Einstellungen erstellen, müssen Sie ein Backup-Passwort festlegen. Dieses Passwort wird benötigt, falls Sie das Backup später wiederherstellen müssen.

- Um das Backup-Passwort zu setzen oder zu ändern, klicken Sie auf „**Passwort ändern**“.
- Um eine Backup-Datei zu erstellen und herunterzuladen, klicken Sie auf **„Herunterladen“**.

### Backup-Passwort ändern

Um das Passwort für zukünftige Backups zu ändern, klicken Sie auf „**Change Password**“.

!!! note
    Das neue Passwort gilt nur für Backups, die **nach** der Passwortänderung erstellt werden. Bestehende Backup-Dateien bleiben mit dem Passwort geschützt, das zum Zeitpunkt ihrer Erstellung festgelegt wurde.

### Einstellungen wiederherstellen
Um Appliance-Einstellungen aus einer Backup-Datei wiederherzustellen, klicken Sie auf „**Backup-Datei importieren...**“.

Wählen Sie im Dialogfenster die gewünschte Backup-Datei aus und geben Sie das zugehörige Passwort ein. Die Appliance-Einstellungen werden dann aus der ausgewählten Backup-Datei wiederhergestellt.

### Backup per SCP

Das MGW unterstützt das Sichern der Appliance per SCP.

Um diese Option zu nutzen, muss der öffentliche Schlüssel des Systems, das auf das MGW zugreifen wird, unter „Backup per SCP“ hinterlegt werden. Das Backup wird automatisch jeden Tag um Mitternacht erstellt und auf dem MGW als `backup.tgz` gespeichert.


Mit dem konfigurierten öffentlichen Schlüssel kann die Backup-Datei per SCP mit dem Betriebssystembenutzer `backup` abgerufen werden. Ein typischer SCP-Befehl zum Abrufen der Backup-Datei lautet:

```bash
scp backup@192.168.1.60:/backup.tgz .
```

Dieser Befehl lädt die Datei `backup.tgz` vom MGW in das aktuelle lokale Verzeichnis herunter.

!!! note
    Wenn Sie einen neuen öffentlichen Schlüssel eingeben, wird der bestehende Schlüssel ersetzt.
