# Stargate-Bereitstellung auf Cloudscale mittels eines Images

## URL der Image-Datei abrufen

- Informationen zu den verfügbaren Images mit URLs finden Sie im [VM Catalog](VM-Catalog.md?h=qcow2).
- Kopieren Sie die `qcow2`-URL in Ihre Zwischenablage.

## Image-Datei in Cloudscale importieren

- Navigieren Sie im Cloudscale-WebUI zum Menü **"Custom Images"** und klicken Sie auf **"Import a Custom Image"**.
- Geben Sie einen geeigneten **Image-Namen** ein.
- Definieren Sie einen **Slug**, z. B. "stargate".
- Fügen Sie die Stargate-Image-URL in das Feld **Download URL** ein.
- Setzen Sie **Source Format** auf das Upload-Format, empfohlen: `qcow2`.
- Konfigurieren Sie zusätzliche Einstellungen nach Bedarf.
- Klicken Sie auf **Import**.

## VM erstellen

- Navigieren Sie zu **Servers** und klicken Sie auf **Launch a new Server**.
- Geben Sie Ihren bevorzugten **FQDN** oder Hostnamen ein.
- Unter **Operating System** wählen Sie **Custom Images** und das importierte Image aus.
- Unter **Compute Flavor** wählen Sie **Flex-4-2** oder **Flex-8-2** abhängig von der erwarteten Last (kann später angepasst werden). Siehe [Server Requirements](../index.md#server-anforderungen) für Details.
- Unter **Storage Capacity** stellen Sie mindestens **20 GB** ein. Bitte beachten Sie [Server Requirements](../index.md#server-anforderungen).
- Unter **Server Location** wählen Sie Ihre bevorzugte Zone.
- Unter **Network Management** aktivieren Sie nur **IPv4**, falls die Stargate-Instanz internetzugänglich sein muss (z. B. für Office 365).
- Unter **Access Security** wählen Sie Ihren SSH-Schlüssel (benutzbar mit dem `almalinux`-Benutzer).
- Klicken Sie auf **Launch**.

## Anmelden und die Stargate-Instanz initialisieren

- Melden Sie sich an der VM-Konsole mit dem `hinadmin`-Benutzer an, um die Stargate-Komponenten zu konfigurieren und zu installieren.
- Um das `hinadmin`-Passwort zu erhalten, senden Sie eine E-Mail an <support@hin.ch> mit dem Betreff: **"Password required for VM installation."**

[Hier klicken, um eine E-Mail zu senden](mailto:support@hin.ch?subject=Password%20required%20for%20VM%20installation.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20password%20for%20a%20VM%20installation.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE) { .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

```shell
sudo su -
cd ~/stargate-deployment/docker-compose/
```

- Bearbeiten Sie `customer-config.sh` mit vi/nano.
- Konfigurationsdetails finden Sie in der [README - Schritt 1: Kunden-Einstellungen konfigurieren](../Docker-deploy.md#schritt-1-kundeneinstellungen-konfigurieren)
- Führen Sie das Installationsskript aus:

```shell
./scripts/install.sh
```

!!! tip "Support"
    Für Fragen oder Probleme im Zusammenhang mit der Bereitstellung und dem Betrieb der Stargate-Appliance wenden Sie sich bitte an den HIN-Support.

    Bitte fügen Sie relevante Informationen wie den Kundennamen, die Appliance-Version und Screenshots/[Logs](../Docker-advanced.md#logs-an-den-support-senden) bei, um uns bei der effizienten Bearbeitung Ihrer Anfrage zu unterstützen.
