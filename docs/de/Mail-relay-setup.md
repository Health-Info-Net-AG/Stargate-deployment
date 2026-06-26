# Stargate-Mail-Relay-Einrichtung

## Erstellen Sie ein Stargate-Relay für eine in Microsoft Office 365 gehostete Mail-Domain

Für das Relay benötigen wir eine VM oder einen Server mit einer echten statischen IP-Adresse.

In diesem Beispiel verwenden wir eine VM mit der IP-Adresse `128.140.117.200` und dem Hostnamen `mail.vrgnservices.eu`, um E-Mails für die Domain `vrgnservices.eu` weiterzuleiten.

## DNS-Einträge einrichten

Siehe den [DNS-Einrichtungsleitfaden](./DNS-setup.md) für vollständige Anweisungen zu allen erforderlichen Einträgen (A, MX, SPF, PTR, DMARC, DKIM).

Schnellbeispiel für die Domain `vrgnservices.eu` mit Stargate-IP `128.140.117.200`:

* **A-Eintrag**: `mail.vrgnservices.eu` → `128.140.117.200`
* **MX-Eintrag**: `MX @ 15 mail.vrgnservices.eu.` (höhere Priorität als der vorhandene Exchange-MX mit 20)
* **SPF-Eintrag**: `v=spf1 ip4:128.140.117.200 include:spf.protection.outlook.com -all`

Überprüfen:

```shell
# host mail.vrgnservices.eu
mail.vrgnservices.eu hat die Adresse 128.140.117.200
```

```shell
# host -t mx vrgnservices.eu
vrgnservices.eu Mail wird bearbeitet von 20 vrgnservices-eu.mail.protection.outlook.com.
vrgnservices.eu Mail wird bearbeitet von 15 mail.vrgnservices.eu.
```

```shell
# host -t txt vrgnservices.eu|grep v=spf1
vrgnservices.eu beschreibender Text "v=spf1 ip4:128.140.117.200 include:spf.protection.outlook.com -all"
```

## Die Stargate-Docker-Compose-Container installieren

[Stargate-Bereitstellung](./Docker-deploy.md)

### Anforderungen

* **2 CPU-Kerne** (Minimum)
* **4 GB RAM** (Minimum)
* **20 GB Speicher** (Minimum)
* **Root-Zugriff**: Muss als Root oder mit `sudo` ausgeführt werden
* **Unterstützte Distributionen**:
    * RHEL 8, 9 und 10 kompatible Distributionen wie Alma Linux, Rocky Linux, CentOS Stream
    * Ubuntu 22 und 24
    * Debian 11, 12 und 13
* **Reale IPv4-Adresse**
* **Gültige DNS-Einträge**: Ihre Domain muss Folgendes haben:
    * MX-Einträge, die auf Ihre Mailserver verweisen
    * SPF-Eintrag, der die erlaubten sendenden Netzwerke definiert

Das Skript installiert alle Komponenten und startet sie. Mail-Domains und der Stalwart-Hostname werden dann zur Laufzeit über die `/mail`-Seite des Dashboards konfiguriert (der mtaconf-Daemon extrahiert die erforderlichen Mail-Relay-Einstellungen basierend auf diesen Domains aus DNS).

## Exchange einrichten

Wir müssen Connectors und eine Transportregel in Exchange konfigurieren, um alle ausgehenden E-Mails an das Stargate-Relay weiterzuleiten und eingehende E-Mails von diesem zu erlauben.

Navigieren Sie zu [https://admin.exchange.microsoft.com/#/connectors](https://admin.exchange.microsoft.com/#/connectors)

### Ausgehender Connector

Erstellen Sie einen ausgehenden Mail-Connector, klicken Sie auf "Hinzufügen":

Wählen Sie "Verbindung von": "Office 365" "Verbindung zu": "E-Mail-Server Ihrer Organisation", klicken Sie auf "Weiter".

![Screenshot](./assets/new_connector_outgoing1.png)

Benennen Sie ihn z.B. "Von Office 365 zum Stargate-Relay-Server" und aktivieren Sie "Interne Exchange-E-Mail-Header beibehalten", klicken Sie auf "Weiter".

![Screenshot](./assets/new_connector_outgoing2.png)

Wählen Sie "Nur wenn ich eine Transportregel eingerichtet habe, die Nachrichten an diesen Connector weiterleitet", klicken Sie auf "Weiter".

![Screenshot](./assets/new_connector_outgoing3.png)

Geben Sie die IP-Adresse des Stargate-Relay-Servers ein, klicken Sie auf "+", klicken Sie auf "Weiter".

![Screenshot](./assets/new_connector_outgoing4.png)

Wählen Sie "Beliebiges digitales Zertifikat, einschließlich selbstsignierter Zertifikate", klicken Sie auf "Weiter".

![Screenshot](./assets/new_connector_outgoing5.png)

Geben Sie eine gültige E-Mail-Adresse für Ihre Domain ein, klicken Sie auf "+", klicken Sie auf "Validieren", klicken Sie auf "Weiter".

![Screenshot](./assets/new_connector_outgoing6.png)

Klicken Sie auf "Connector erstellen".

![Screenshot](./assets/new_connector_outgoing7.png)

Klicken Sie auf "Einen weiteren Connector hinzufügen".

![Screenshot](./assets/new_connector_outgoing8.png)

### Eingehender Connector

Erstellen Sie einen eingehenden Mail-Connector, wählen Sie "Verbindung von": "E-Mail-Server Ihrer Organisation", klicken Sie auf "Weiter".

![Screenshot](./assets/new_connector_incoming1.png)

Benennen Sie ihn z.B. "E-Mails vom Stargate-Relay-Server empfangen" und aktivieren Sie "Interne Exchange-E-Mail-Header beibehalten", klicken Sie auf "Weiter".

![Screenshot](./assets/new_connector_incoming2.png)

Wählen Sie "Durch Überprüfen, ob die IP-Adresse des sendenden Servers mit einer der folgenden IP-Adressen übereinstimmt", geben Sie die IP-Adresse des Stargate-Servers ein, klicken Sie auf "+", klicken Sie auf "Weiter".

![Screenshot](./assets/new_connector_incoming3.png)

Klicken Sie auf "Connector erstellen".

![Screenshot](./assets/new_connector_incoming4.png)

Klicken Sie auf "Fertig".

![Screenshot](./assets/new_connector_incoming5.png)

So sieht es aus, wenn es fertig ist:

![Screenshot](./assets/new_connector_incoming6.png)

### Transportregel

Erstellen Sie die Transportregel. Navigieren Sie zu [https://admin.exchange.microsoft.com/#/transportrules](https://admin.exchange.microsoft.com/#/transportrules)

Klicken Sie auf "+Regel hinzufügen" --> "Neue Regel erstellen".

![Screenshot](./assets/new_transport_rule1.png)

Benennen Sie sie z.B. "Alle E-Mails an Stargate weiterleiten, außer E-Mails von diesem", wählen Sie "Regel anwenden, wenn" "Der Empfänger:" "ist extern/intern" "Außerhalb der Organisation", klicken Sie auf "Speichern".

![Screenshot](./assets/new_transport_rule2.png)

Wählen Sie "Folgendes tun" "Nachricht an folgenden Connector umleiten" "Von Office 365 zum Stargate-Relay-Server", klicken Sie auf "Speichern".

![Screenshot](./assets/new_transport_rule3.png)

Wählen Sie "Außer wenn Die Absender-IP-Adresse in einem dieser Bereiche liegt" geben Sie die IP-Adresse des Stargate-Servers ein, klicken Sie auf "Hinzufügen", überprüfen Sie die IP-Adresse und klicken Sie auf "Speichern".

Dies ist notwendig, um E-Mail-Schleifen zu vermeiden, da diese Regel auch für andere in Office 365 gehostete Domains gilt.

![Screenshot](./assets/new_transport_rule4.png)

Jetzt sollte es so aussehen, klicken Sie auf "Weiter":

![Screenshot](./assets/new_transport_rule5.png)

Klicken Sie auf "Weiter".

![Screenshot](./assets/new_transport_rule6.png)

Klicken Sie auf "Fertig".

![Screenshot](./assets/new_transport_rule7.png)

Klicken Sie auf "Fertig".

![Screenshot](./assets/new_transport_rule8.png)

![Screenshot](./assets/new_transport_rule9.png)

Klicken Sie auf die Regel und setzen Sie die Option "Regel aktivieren oder deaktivieren" auf "Aktiviert"

![Screenshot](./assets/new_transport_rule10.png)
