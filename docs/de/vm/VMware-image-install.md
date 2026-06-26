# Stargate VMware ESXi-Bereitstellung mittels eines Images

Stargate auf VMware bereitstellen

## Image-Datei herunterladen

- Laden Sie die neueste OVA-(oder OVF- und VMDK-Datei, falls bevorzugt) Image-Datei herunter. Bitte beachten Sie [VM Catalog](VM-Catalog.md?h=ova)

## Navigieren Sie zur ESXi-Web-Benutzeroberfläche

- Klicken Sie auf **Virtual Machines**
- Klicken Sie auf **Create/Register VM**
- Wählen Sie **"Deploy a virtual machine from an OVF or OVA file"**
- Klicken Sie auf **Next**
- Geben Sie einen Namen für die VM ein.
- Klicken Sie auf **Next**
- Klicken Sie auf **Select files** und wählen Sie die OVA-Image-Datei (oder OVF und VMDK, falls bevorzugt)
- Klicken Sie auf **Next**
- Wählen Sie den zu verwendenden Speicher aus.
- Klicken Sie auf **Next**
- Wählen Sie Netzwerk und Disk für die Bereitstellung.
- Klicken Sie auf **Next**
- Klicken Sie auf **Finish**

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
