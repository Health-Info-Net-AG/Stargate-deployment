# HIN Gateway

!!! tip
    Technischer Installationsablauf für eine Single-Domain-Mail-Architektur mit Microsoft 365

## Einleitung

Dieses Dokument bietet eine umfassende Anleitung zum technischen Installations- und Migrationsprozess auf das neue HIN Gateway ("Stargate Appliance"). Es gilt für Microsoft 365-Mail-Architekturen, die eine einzige vertrauenswürdige Domäne verwenden.

Die Anleitung richtet sich an HIN Kunden, IT-Administratoren und Systemingenieure, die für die Bereitstellung und Konfiguration des neuen HIN Gateways sowie für die Migration vom bestehenden Mail-Gateway (MGW) zur neuen Lösung verantwortlich sind.

Das HIN Gateway ist eine sichere E-Mail-Gateway-Lösung, die eine vertrauenswürdige, verschlüsselte und richtliniengesteuerte Kommunikation innerhalb des HIN Trust Circle ermöglicht. Es fungiert als zentraler Vermittler zwischen internen E-Mail-Infrastrukturen und externen Kommunikationspartnern und stellt sicher, dass der gesamte E-Mail-Verkehr sicher übertragen wird, den Richtlinien der Organisation entspricht und die Sicherheitsstandards von HIN erfüllt.

## Übersicht über den E-Mail-Fluss mit dem HIN Gateway

- **Eingehende E-Mails** werden über das HIN Gateway geleitet, wo sie validiert, (falls erforderlich) entschlüsselt und anhand von Vertrauens- und Sicherheitsrichtlinien überprüft werden, bevor sie an den internen Mailserver weitergeleitet werden.
- **Ausgehende E-Mails** werden von internen Systemen an das HIN Gateway gesendet, wo Verschlüsselung, Weiterleitung und die Durchsetzung der Richtlinien erfolgen, bevor sie an externe Empfänger übermittelt werden.
- **Die Kommunikation zwischen den HIN Gateways** wird durch Peer-Zertifikate und WireGuard-Tunnel gesichert, wodurch eine vertrauenswürdige Kommunikation zwischen den Domänen gewährleistet wird.

## Installations- und Migrationsablauf

Die in diesem Dokument beschriebene strukturierte Schritt-für-Schritt-Anleitung umfasst folgende Punkte:

1. Vorbereitung und Ausweichplanung
2. Installation und Konfiguration des HIN Gateways
3. Domänenaktivierung und Zertifikatsvalidierung
4. Integration des Mail-Servers und Konfiguration des Routings
5. Testen, Übergang in den Produktivbetrieb und Validierung nach der Migration
6. Ausserbetriebnahme des bestehenden MGW

Das Ziel von HIN bei diesem Prozess ist es, eine sichere, reibungslose und vollständig validierte Migration zu gewährleisten, die den Betrieb nur minimal beeinträchtigt und die unterbrechungsfreie Kontinuität der E-Mail-Dienste garantiert.

## Häufig gestellte Fragen

!!! question "Kann ich die Installation und Migration selbst durchführen?"
    Ja, die Installation und Migration können vollständig vom Kunden durchgeführt werden, mit Ausnahme von "Schritt 1.3 - Exportieren der/des privaten Schlüssel(s)".

    Aus Sicherheitsgründen und um Ihren privaten Schlüssel zu schützen, müssen Sie sich an den HIN Support wenden oder an der geplanten Migrationsbesprechung teilnehmen, um den Code zu erhalten, der für den Export des privaten Schlüssels aus den derzeit in Betrieb befindlichen Mail-Gateways erforderlich ist.

    Sollten die Installation und die Migration nicht erfolgreich abgeschlossen werden können, nehmen Sie bitte am geplanten Support-Gespräch mit unseren Technikern teil.

!!! question "Wird es während der Migration zu Unterbrüchen bei der E-Mail-Zustellung kommen?"
    Zwischen "Schritt 1.5 - Bestehende MGW-VM abschalten" und "Schritt 18 - Mailserver konfigurieren" werden alle E-Mails auf dem Mailserver in die Warteschlange gestellt. Sobald "Schritt 18 - Mailserver konfigurieren" abgeschlossen ist, werden die in der Warteschlange befindlichen E-Mails versendet oder in das Postfach zugestellt.

!!! question "Gehen während der Installation und Migration E-Mails verloren?"
    Nein, während der Installation und Migration gehen keine E-Mails verloren.

## Übersicht über die Installationsschritte

| Schritt | Thema | Verantwortung |
| :--: | :---- | :------------: |
| 0 | Voraussetzungen prüfen | Kunde |
| 1.1 | Smoke-Test | Kunde |
| 1.2 | Sichern des bestehenden MGWs | Kunde |
| 1.3 | Exportieren der/des privaten Schlüssel(s) | Kunde / HIN |
| 1.4 | Notfallplan / Ausweichszenario | Kunde |
| 1.5 | Bestehende MGW-VM abschalten | Kunde |
| 2 | WireGuard | Kunde |
| 3 | Ziel-VM auswählen | Kunde |
| 4 | VM-Image laden | Kunde |
| 5 | Netzwerkverbindung zur VM | Kunde |
| 6 | Zugriff über den Browser | Kunde |
| 7 | Aktivierungscode eingeben | Kunde |
| 8 | Setup des Mesh-Netzwerks | Kunde |
| 9 | Sicheres Mesh-Netzwerk einrichten | Kunde |
| 10 | Login bei Keycloak | Kunde |
| 11 | Passwort aktualisieren | Kunde |
| 12 | Kontoinformationen aktualisieren | Kunde |
| 13 | Erstkonfiguration und Einrichten der Domäne | Kunde |
| 14 | E-Mail-Transport konfigurieren | Kunde |
| 15 | Whitelist-Header konfigurieren | Kunde |
| 16 | Peer-Zertifikate | HIN |
| 17 | Peer-Zertifikate validieren | Kunde |
| 18 | Mailserver konfigurieren | Kunde |
| 19 | Test vor der Umstellung | Kunde |
| 20 | Validieren nach der Umstellung | Kunde |
| 21 | Bestehendes MGW ausser Betrieb nehmen | Kunde |
| 22 | Passwort der VM ändern | Kunde |
| Anhang 1| Sichern und Wiederherstellen der Appliance-Einstellungen | Kunde |

## Detaillierte Schritte

### Schritt 0 - Voraussetzungen prüfen

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Bitte lesen Sie die "Stargate-Bereitstellungsanweisungen" durch und stellen Sie sicher, dass alle notwendigen Vorbereitungsschritte abgeschlossen sind, bevor die Migrationsarbeiten für das HIN Gateway beginnen.

Die folgenden Punkte müssen vor der Migration verfügbar sein oder bestätigt werden:

- **Die Zugangsdaten werden Ihnen von HIN zugestellt**:
    - VM-Zugangsdaten
    - Keycloak-Zugangsdaten
    - Aktivierungscode
- **Export des privaten Schlüssels**
    - Wenn Sie an einem Windows-Rechner arbeiten, der über Port 22 Zugriff auf die Mail-Gateway-VM hat, können wir Sie während des Gesprächs dabei unterstützen, den Export des privaten Schlüssels aus dem MGW zu aktivieren.
    - Falls Sie keinen Zugriff auf einen solchen Rechner haben, wenden Sie sich bitte per E-Mail oder Telefon (<support@hin.ch> / 0848 830 740) an den HIN Support, damit wir Ihnen helfen können, eine Supportverbindung über "Systemadministration" -> "Supportverbindung" -> "Verbinden" herzustellen.
- **Lade die neueste Version** des [VM-Images](vm/VM-Catalog.md) herunter.
- **Firewall**:
    - Erlauben Sie den Datenverkehr: beliebig zum HIN Gateway und HIN Gateway zum beliebig
        - WireGuard: Siehe [Serveranforderungen – Eingehender Netzwerkzugriff](./index.md#eingehender-netzwerkzugriff-firewall-muss-erlauben):
            - Konfigurieren Sie den WireGuard-Port `19818` (TCP/UDP) in Ihrer Firewall.
                - Eingehender und ausgehender Datenverkehr
    - Erlauben Sie den Datenverkehr: Administrationsrechner zum HIN Gateway-VM
        - Anforderungen für die Installation:
            - HTTPS-Port `443`
                - Eingehender und ausgehender Datenverkehr
            - Keycloak-Port `8180`
                - Eingehender und ausgehender Datenverkehr
        - Anforderungen für die Fehlerbehebung (optional, um Protokolle einzusehen und alle Parameter zu ändern):
            - SSH-Port `22`
                - Eingehender und ausgehender Datenverkehr
                ??? warning "Wichtig, wenn Sie SSH über das Internet verfügbar machen"
                    Wenn Sie SSH (Port 22) über das Internet erreichbar machen, **müssen Sie das Passwort** in ein sicheres Passwort ändern. Führen Sie den folgenden Befehl im Terminal aus, um ein neues Passwort festzulegen:

                    ```bash
                    passwd
                    ```

                    !!! tip
                        Es wird dringend empfohlen, die Passwortanmeldung für alle Benutzer zu deaktivieren und die SSH-Schlüsselauthentifizierung zu verwenden. Fügen Sie dazu Ihren öffentlichen SSH-Schlüssel zu `/home/hinadmin/.ssh/authorized_keys` hinzu.

                        ```bash
                        mkdir ~/.ssh
                        echo "YOUR PUBLIC KEY" >> ~/.ssh/authorized_keys
                        chmod 600 ~/.ssh/authorized_keys
                        ```

                        Überprüfen Sie, dass Sie sich mit diesem Schlüssel anmelden können.

                        - Melden Sie sich von der SSH-Sitzung ab.
                        - Melden Sie sich erneut an. Sie **sollten nicht** zur Eingabe eines Passworts aufgefordert werden.

                        Deaktivieren Sie anschließend die Passwortauthentifizierung in SSHD. Verwenden Sie den folgenden Befehl oder setzen Sie `PasswordAuthentication no` manuell in der Konfiguration:

                        ```bash
                        sudo find /etc/ssh -type f -exec sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/g' {} +
                        # SSHD-Dienst neu starten
                        sudo systemctl restart sshd
                        ```

            - Dozzle-Port `8190`
                - Eingehender und ausgehender Datenverkehr

- Für "[Schritt 5 - Netzwerkverbindung zur VM](#schritt-5-netzwerkverbindung-zur-vm)" sollte ein **DHCP-Zugang** verfügbar sein (empfohlen).
- Anforderungen an die **Datensicherung**, siehe "[Anhang 1 - Sichern und Wiederherstellen der Appliance-Einstellungen](#anhang-1-sichern-und-wiederherstellen-der-appliance-einstellungen)".
- Bestätigung, dass das bestehende MGW erst nach Abschluss der Abnahme gelöscht wird.
- Zugriff auf DNS, Mailserver-Konnektoren, Transportregeln und Relay-Einstellungen.

!!! info "Warum WireGuard?"
    Der WireGuard-Port erfüllt zwei wichtige Funktionen:
    1. Das HIN Gateway nutzt diesen Port, um Peer-Zertifikate von der HIN CA zu beziehen.
    2. Es nutzt diesen Port, um einen sicheren Tunnel zu anderen HIN Gateways aufzubauen, über den der sichere Datenaustausch (z.B. E-Mail-Verkehr) stattfindet.

    Weitere Informationen: [Security Assessment WireGuard EN](https://www.hin.ch/files/pdf1/wireguard-tunnel-en.pdf)

!!! tip "Export des privaten Schlüssels"
    Falls Sie an einem Windows-Rechner arbeiten, der über Port 22 Zugriff auf die Mail Gateway-VM hat, können wir Sie während des Anrufs unterstützen, um den Export des privaten Schlüssels vom MGW zu aktivieren.

    Falls Sie keinen Zugriff auf einen solchen Rechner haben, wenden Sie sich bitte an den HIN [Support](./Support.md) per E-Mail oder Telefon (support@hin.ch / 0848 830 740), um eine Support-Verbindung über Systemverwaltung --> Support-Verbindung --> Verbinden herzustellen.

- Für "Schritt 5 - Netzwerkverbindung zur VM" sollte ein DHCP-Zugang verfügbar sein (empfohlen).
- Anforderungen an die Datensicherung, siehe "[Anhang 1 - Sichern und Wiederherstellen der Appliance-Einstellungen](#anhang-1-sichern-und-wiederherstellen-der-appliance-einstellungen)".
- Bestätigung, dass das bestehende MGW erst nach Abschluss der Abnahme gelöscht wird.
- Zugriff auf DNS, Mailserver-Konnektoren, Transportregeln und Relay-Einstellungen.

### Schritt 1.1 - Smoke-Test

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Senden Sie eine Test-E-Mail an die folgenden Empfänger, wobei Sie Zugriff auf das Postfach haben, um den korrekten Empfang zu überprüfen:

- eine HIN E-Mail-Adresse oder eine HIN Community-Domain von Ihnen, zum Beispiel: `user@hin.ch`
- eine E-Mail-Adresse ausserhalb der HIN Community, zum Beispiel: `user@bluewin.ch`

Überprüfen Sie, ob beide E-Mails erfolgreich zugestellt wurden, einschliesslich Betreff, Inhalt und allfälliger Anhänge.

### Schritt 1.2 - Sichern des bestehenden MGWs

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Erstellen Sie ein Backup der bestehenden MGW-Appliance und stellen Sie sicher, dass die VM so lange bestehen bleibt, bis die Migration erfolgreich abgeschlossen und formell abgenommen wurde. Weitere Informationen finden Sie unter "[Anhang 1 - Sichern und Wiederherstellen der Appliance-Einstellungen](#anhang-1-sichern-und-wiederherstellen-der-appliance-einstellungen)".

### Schritt 1.3 - Exportieren der/des privaten Schlüssel(s)

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)
:heavy_plus_sign:
![Verantwortlichkeit HIN](https://img.shields.io/badge/Verantwortlichkeit-HIN-orange)

!!! warning "Unterstützung durch HIN erforderlich"
    Für diesen Schritt ist ein Freischaltcode erforderlich. Der Code wird von einem HIN Support Engineer bereitgestellt. Wenn Sie die Installation selbstständig fortsetzen möchten, kontaktieren Sie bitte den HIN Support, um den Freischaltcode anzufordern. Andernfalls wird Ihnen der Freischaltcode während des geplanten Migrationstermins zur Verfügung gestellt.

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

**Rollback-Szenario** - Falls ein Rollback erforderlich ist:

1. Das neue HIN Gateway anhalten.
2. Schalten Sie das bestehende MGW ein.
3. Überprüfen Sie, ob der eingehende und ausgehende E-Mail-Verkehr über das bestehende MGW korrekt funktioniert.

### Schritt 1.5 - Bestehende MGW-VM abschalten

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Fahren Sie die bestehende MGW-VM herunter.

!!! warning
    Dieser Schritt unterbricht den E-Mail-Verkehr. Während der Unterbrechung werden E-Mails auf dem Mailserver in die Warteschlange gestellt und erst nach Abschluss der Installation zugestellt (siehe „[Schritt 18 - Mailserver konfigurieren](#schritt-18-mailserver-konfigurieren)“).

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

??? warning "Netzwerk muss vor dem ersten Start konfiguriert sein"
    Das VM-Image führt beim ersten Start eine automatische Installation durch. Wenn das Netzwerk zu diesem Zeitpunkt nicht konfiguriert ist, schlägt die Installation fehl, da die IP-Adresse des Servers nicht ermittelt werden kann.

    Wenn Sie Option C verwendet und das Netzwerk manuell konfiguriert haben, müssen Sie die folgenden Befehle ausführen:

    ```bash
    cd /root/stargate-deployment/docker-compose
    ./scripts/purge.sh
    # Update configuration with a new ip, by editing it with nano
    # SERVER_STATIC_IP=<NEW IP>
    nano customer-config.sh
    # OR use sed
    # sed -i 's/old IP/new IP/g' customer-config.sh
    ./scripts/install.sh
    ```

    Das Installationsskript ermittelt die IP-Adresse des Servers automatisch anhand der Standardroute. Eine beliebige erreichbare IP-Adresse, egal ob öffentlich oder privat, ist ausreichend. Der eigentliche öffentliche Endpunkt wird später über das Dashboard konfiguriert.

!!! tip
    Wenn Sie Option C verwendet und das Netzwerk manuell konfiguriert haben, müssen Sie die folgenden Befehle ausführen:

    ```bash
    cd /root/stargate-deployment/docker-compose
    ./scripts/purge.sh
    # Update configuration with a new ip, by editing it with nano
    # SERVER_STATIC_IP=<NEW IP>
    nano customer-config.sh
    # OR use sed
    # sed -i 's/old IP/new IP/g' customer-config.sh
    ./scripts/install.sh
    ```

    Das Installationsskript ermittelt die IP-Adresse des Servers automatisch anhand der Standardroute. Eine beliebige erreichbare IP-Adresse, egal ob öffentlich oder privat, ist ausreichend. Der eigentliche öffentliche Endpunkt wird später über das Dashboard konfiguriert.

    Nachdem die Skripte erfolgreich ausgeführt wurden, fahren Sie mit "Schritt 6 - Zugriff über den Browser" fort.

    !!! question

        Falls Sie nicht über die HIN-Admin-Zugangsdaten verfügen, wenden Sie sich bitte an den HIN Support per E-Mail oder Telefon (support@hin.ch / 0848 830 740). Siehe [Support-Bereich](./Support.md).

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
    Falls Sie den Aktivationscode nicht haben, wenden Sie sich bitte per E-Mail oder Telefon an den HIN Support (support@hin.ch / 0848 830 740).

    [Klicken Sie hier, um eine E-Mail zu senden](mailto:support@hin.ch?subject=Aktivierungscode%20erforderlich.&body=Sehr%20geehrter%20Support,%0A%0Aich%20benötige%20den%20Aktivierungscode%20für%20meine%20HIN-Gateway-Installation.%0A%0ABITTE%20GEBEN%20SIE%20HIER%20IHRE%20KUNDENINFORMATIONEN%20AN){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Schritt 8 - Setup des Mesh-Netzwerks

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Überprüfen Sie die Konfiguration des Mesh-Netzwerks:

- **IP-Adresse** - Die öffentliche IP-Adresse des ausgehenden Datenverkehrs (wird automatisch erkannt).
- **Transport** - Das Transportprotokoll (Standard: TCP).
- **Port** - Der WireGuard-Port (Standard: 19818).

??? question "Was ist eine öffentliche IP?"
    Dies ist eine IP-Adresse, die der Rechner verwenden wird, um über das Internet erreichbar zu sein.
    Es handelt sich **nicht** um die interne IP-Adresse des Rechners hinter einer Firewall oder NAT, z. B. `10.0.0.0/8`, `172.16.0.0/12` oder `192.168.0.0/16`.

Überprüfen Sie, ob die Werte korrekt sind, und klicken Sie auf "Next".

![Bildschirm für das Mesh-Netzwerk-Setup](assets/installation-guide/step8-mesh-network.png)

### Schritt 9 - Sicheres Mesh-Netzwerk einrichten

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Das System baut nun die Verbindung zum sicheren Mesh-Netzwerk auf. In diesem Schritt wird das HIN Gateway mit dem Iris-Agent verbunden und die Zertifikate werden synchronisiert.

Warten Sie, bis der Vorgang abgeschlossen ist. Die Statusanzeigen zeigen "Up" an, sobald die Verbindung erfolgreich hergestellt wurde. Klicken Sie auf "Finish".

![Sicheres Mesh-Netzwerk einrichten](assets/installation-guide/step9-mesh-connecting.png)

!!! failure "Falls die Verbindung fehlschlägt"
    Falls die Verbindung fehlschlägt oder der Status des Iris-Agents oder der Zertifikatssynchronisation weiterhin "Down" lautet:

    - Stellen Sie sicher, dass Port 19818 (TCP/UDP) in Ihrer Firewall offen ist (siehe "Schritt 2 - WireGuard").
    - Überprüfen Sie, ob die IP-Adresse unter "Schritt 8 - Setup des Mesh-Netzwerks" korrekt ist und über das Internet erreichbar ist.
    - Starten Sie den Vorgang neu oder wenden Sie sich per E-Mail oder Telefon an den HIN Support (support@hin.ch / 0848 830 740).

### Schritt 10 - Login bei Keycloak

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

!!! warning
    Port `8180` muss für Keycloak geöffnet sein. Er muss nicht aus dem gesamten Internet erreichbar sein. Er sollte jedoch zwischen **Ihrem Administrationsrechner** und der VM, die Sie installieren, erreichbar sein. Andernfalls können Sie keine Verbindung zu Keycloak herstellen und die Installation nicht fortsetzen.

    ??? tip "Was tun, wenn ein Verbindungsfehler angezeigt wird?"
        Bitte prüfen Sie, ob Port `8180` von Ihrem Rechner zur VM erreichbar ist. Nachdem Sie die Konfiguration aktualisiert haben, kehren Sie zur Benutzeroberfläche unter `https://<VM IP address>` zurück und klicken Sie auf die Schaltfläche „Login“.

Sobald das Mesh-Netzwerk eingerichtet ist, werden Sie zur Keycloak-Anmeldeseite weitergeleitet. Geben Sie den Benutzernamen und das Passwort ein, die Sie von HIN erhalten haben.

![Keycloak-Anmeldeseite](assets/installation-guide/step10-keycloak-login.png)

!!! question
    Falls Sie diese Anmeldedaten nicht haben, wenden Sie sich bitte per E-Mail oder Telefon an den HIN Support (support@hin.ch / 0848 830 740).

    [Klicken Sie hier, um eine E-Mail zu senden](mailto:support@hin.ch?subject=Keycloak-Anmeldedaten%20erforderlich.&body=Sehr%20geehrter%20Support,%0A%0Aich%20benötige%20die%20Keycloak-Anmeldedaten%20für%20mein%20HIN-Gateway.%0A%0ABITTE%20GEBEN%20SIE%20HIER%20IHRE%20KUNDENINFORMATIONEN%20AN){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Schritt 11 - Passwort aktualisieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Bei der ersten Anmeldung werden Sie aufgefordert, Ihr Passwort zu ändern. Geben Sie ein neues sicheres Passwort ein und bestätigen Sie es.

![Bildschirm zum Aktualisieren des Passworts](assets/installation-guide/step11-update-password.png)

### Schritt 12 - Kontoinformationen aktualisieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Vervollständigen Sie Ihr Kontoprofil, indem Sie Ihren Vornamen und Nachnamen eingeben. Die E-Mail-Adresse ist bereits vorausgefüllt. Klicken Sie auf "Submit", um fortzufahren.

![Bildschirm zum Aktualisieren der Kontoinformationen](assets/installation-guide/step12-account-info.png)

### Schritt 13 - Erstkonfiguration und Einrichten der Domäne

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Konfigurieren Sie auf diesem Bildschirm Ihre Grundeinstellungen:

- Überprüfen Sie, ob alle Ihre aktuellen vertrauenswürdigen Domänen innerhalb der HIN Community korrekt angezeigt werden.
- Wählen Sie aus, welche vertrauenswürdigen Domänen "Enabled" sein sollen, um Peer-Zertifikate von der HIN Zertifizierungsstelle (HIN CA) zu erhalten.
- Geben Sie an, für welche Domäne(n) das Präfix "sec.\<domain\>" bereits konfiguriert ist ("Use sec-prefix").

??? tip "Wie kann ich prüfen, ob meine Domain mit einem Security Prefix eingerichtet ist?"
    Öffnen Sie unser Online-Tool im Browser: https://trust.hin.ls-infra.me/, geben Sie `sec.<domain>` ein und klicken Sie auf die Schaltfläche **Check**. Wenn folgende Meldung angezeigt wird:

    ✅ Diese Domain ist verschlüsselt.

    Dann ist Ihre Domain mit einem Security Prefix eingerichtet und Sie müssen die Option **Use sec-prefix** aktivieren.

- Überprüfen Sie, ob der Organisationsname und die Domain-Inhaber korrekt sind. <br> ![Screenshot](assets/step_13_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" } <br> ![Screenshot](assets/step_13_2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
- Importieren Sie die vorhandene S/MIME-Zertifikatsdatei (`.p12`/`.pfx`) vom bestehenden MGW:
    1. Erweitern Sie die Domäne und wählen Sie die Option "P12/PFX-Datei".
    2. Falls für die Zertifikatsdatei kein Passwort festgelegt wurde, lassen Sie das Passwortfeld leer.
    3. Klicken Sie auf "Importieren".
    4. Nachdem das Zertifikat importiert wurde, wird die Meldung "Certificate imported successfully" angezeigt.
- Klicken Sie am Ende der Seite auf "Save configuration", um die Änderungen zu speichern.

![Bildschirm für die Ersteinrichtung](assets/installation-guide/step13-initial-setup.png)

!!! warning
    - Mindestens eine Domain muss "Enabled" sein, um mit dem Onboarding-Prozess fortzufahren. Die Schaltfläche "Save configuration" wird erst aktiv, wenn diese Voraussetzung erfüllt ist.
    - Sollten Sie feststellen, dass nicht alle vertrauenswürdigen Domains angezeigt werden oder die Organisationsangaben falsch sind, wenden Sie sich bitte per E-Mail oder Telefon an den HIN Support (support@hin.ch / 0848 830 740).

!!! danger "Importieren Sie Ihren bestehenden privaten Schlüssel"
    Wenn Sie den privaten Schlüssel nicht von Ihrem bestehenden MGW importieren, wird ein neuer Schlüssel ausgestellt. Dies kann dazu führen, dass Nachrichten bis zu 6 Stunden lang nicht entschlüsselt werden können, was zu Datenverlust führen könnte.

### Schritt 14 - E-Mail-Transport konfigurieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Konfigurieren Sie auf diesem Bildschirm Ihre E-Mail-Transport-Einstellungen für die Einrichtung des sicheren E-Mail-Relays.

![Bildschirm für die E-Mail-Transport-Konfiguration](assets/installation-guide/step14-mail-transport.png)

Die folgenden Einstellungen stehen zur Verfügung:

| Einstellung | Beschreibung |
|---------|-------------|
| **Hostname des Mail-Servers** | Der FQDN dieser Mail-Gateway-Instanz (z.B. mail.example.com). |
| **IP-Adressen des Mail-Servers** | Die öffentliche(n) IP-Adresse(n) dieses Servers. Füge weitere IP-Adressen hinzu, falls der Server über mehrere Adressen erreichbar ist. |
| **Domänen** | Jede Domain, die dieses Gateway verarbeitet, zusammen mit ihrem Relay-Host (dem internen Mailserver, an den eingehende E-Mails zugestellt werden). |
| **Standard-Relay-Host** | Der Standard-SMTP-Relay für den ausgehenden Versand. |

Im Abschnitt "Erweitert" können Sie optional Folgendes konfigurieren:

| Einstellung | Beschreibung |
|---------|-------------|
| **Konfigurieren der TLS** | TLS-Zertifikateinstellungen für SMTP-Verbindungen. |
| **Inhaltsfilter** | Der interne Endpunkt des Inhaltsfilters (Standard: mxengine:1587). |
| **Vertrauenswürdige Netzwerke** | Zusätzliche Netzwerke, denen die Weiterleitung über dieses Gateway gestattet ist. |

Weitere Aktionen:

- Fügen Sie bei Bedarf weitere Domains hinzu, indem Sie auf "Add domain" klicken.
- Erweitern Sie den Abschnitt "Advanced", um die E-Mail-Transportparameter fein abzustimmen.

!!! note
    Stellen Sie sicher, dass alle Konfigurationen für Relay-Hosts und Domains korrekt sind, bevor Sie fortfahren.

Sobald die Konfiguration überprüft und abgeschlossen ist, klicken Sie auf "Konfiguration übernehmen", um fortzufahren.

### Schritt 15 - Whitelist-Header konfigurieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

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
    Wenden Sie sich bei Problemen per E-Mail oder Telefon an den HIN Support (support@hin.ch / 0848 830 740).

### Schritt 18 - Mailserver konfigurieren

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Wenn Sie die empfohlene Vorgehensweise befolgt haben, d.h. den privaten Schlüssel exportiert, in das HIN Gateway importiert und dieselbe IP-Adresse wie beim bestehenden MGW beibehalten haben, sind keine Änderungen am E-Mail-Server erforderlich.

Andernfalls konfigurieren Sie Ihren Mailserver oder die zugehörigen Komponenten so, dass der Datenverkehr über das neue HIN Gateway geleitet wird. Überprüfen und aktualisieren Sie bei Bedarf die folgenden Einstellungen:

- SMTP-Relay / Smart Host
- Konnektoren
- Transportregeln
- Routing-Domains

Ausführliche Anweisungen finden Sie unter [Exchange-Integration](Exchange-integration.md).

### Schritt 19 - Test vor der Umstellung

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Wiederholen Sie den "[Schritt 1.1 - Smoke-Test](#schritt-11-smoke-test)". Zusätzlich zum Smoke-Test testen und bestätigen Sie bitte die folgenden Schritte:

**Ausgehend:**

- Stellen Sie sicher, dass der Mailserver so konfiguriert ist, dass er E-Mails über ein SMTP-Relay oder einen Exchange-Konnektor an das HIN Gateway versendet.
- Stellen Sie sicher, dass das HIN Gateway E-Mails an Empfänger ausserhalb der HIN Community versenden kann.
- Stellen Sie sicher, dass das HIN Gateway E-Mails über WireGuard an Empfänger innerhalb der HIN Community senden kann.

**Eingehender Verkehr:**

- Stellen Sie sicher, dass verschlüsselte E-Mails aus der HIN Community über WireGuard empfangen werden können. Ein Absender aus der Domäne hin.ch ist der einfachste Testweg.
- Stellen Sie sicher, dass verschlüsselte E-Mails aus der HIN Community über SMTP unter Verwendung von S/MIME empfangen werden können.
- Stellen Sie sicher, dass Antworten von Absendern ausserhalb der HIN Community auf eine erste sichere E-Mail (HIN Mail-SEAL) das HIN Gateway erreichen können.
- Stellen Sie sicher, dass unverschlüsselte E-Mails von externen Absendern ausserhalb der HIN Community empfangen werden können.

### Schritt 20 - Validieren nach der Umstellung

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Bestätigen:

- E-Mails zugestellt
- Verschlüsselung angewendet
- Keine Delays oder Bounces
- Protokollierung erfolgreich

Füllen Sie das [Abnahmeprotokoll](https://www.hin.ch/files/pdf1/gateway-abnahme-de.pdf) aus und senden Sie es an Ihren HIN Ansprechpartner zurück.

### Schritt 21 - Bestehendes MGW ausser Betrieb nehmen

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

!!! warning
    Löschen Sie die bestehende MGW-VM nicht sofort, sondern bewahren Sie sie sicher auf, bis alles betriebsbereit ist.

1. **Stellen Sie sicher, dass kein aktiver Datenverkehr vorhanden ist** - Überprüfen Sie:
    - Es verweisen keine Domains auf das MGW (DNS, SMTP, Konnektoren).
    - Es werden keine E-Mails über die alte Appliance weitergeleitet.
2. **Protokolle archivieren** - exportieren und speichern:
    - E-Mail-Protokolle
    - Sicherheits-/Audit-Protokolle (erforderlich für Compliance und Fehlerbehebung)
3. **Bereinigung (optional)** - Entfernen:
    - Firewall-Regeln
    - DNS-Einträge
    - Routing-Konfigurationen, die auf das bestehende MGW verweisen

### Schritt 22 - Passwort der VM ändern

![Verantwortlichkeit Kunde](https://img.shields.io/badge/Verantwortlichkeit-Kunde-success)

Bitte stellen Sie sicher, dass die Ihnen ursprünglich zur Verfügung gestellten Zugangsdaten für die VM in ein von Ihnen selbst festgelegtes Passwort geändert werden, und bewahren Sie dieses an einem sicheren Ort auf.

## Anhang 1 - Sichern und Wiederherstellen der Appliance-Einstellungen

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
