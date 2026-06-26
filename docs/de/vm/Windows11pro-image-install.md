
# Windows 11 Pro-Bereitstellung mittels eines Images

Stargate auf Windows Pro bereitstellen (Nicht-Pro-Versionen unterstützen Hyper-V nicht)

## Hyper-V installieren

- Klicken Sie auf den **Start**-Button und geben Sie **"Windows-Features aktivieren oder deaktivieren"** ein.
- Klicken Sie auf diesen Button.
- Aktivieren Sie **Hyper-V** und klicken Sie auf **"OK"**.
- Nach Abschluss der Installation klicken Sie auf **"Jetzt neu starten"** und warten Sie, bis Windows neu startet.

**Hinweis:** Wir empfehlen, die VM mit Hyper-V Generation 2 bereitzustellen.

## Image abrufen

- Laden Sie die .vhdx-Image-Datei herunter. Bitte beachten Sie [VM Catalog](VM-Catalog.md?h=vhdx)

## Image-Datei importieren und VM damit erstellen

- Klicken Sie auf den **Start**-Button und geben Sie **"Hyper-V Quick Create"** ein.
- Klicken Sie auf dieses Symbol.
- Wählen Sie **"Lokale Installationsquelle"**.
- Deaktivieren Sie **"Dieser Computer wird Windows ausführen"**.
- Klicken Sie auf **"Installationsquelle ändern"**, navigieren Sie zur heruntergeladenen .VHDX-Image-Datei und klicken Sie darauf.
- Klicken Sie auf **"Virtuellen Computer erstellen"**.
- Klicken Sie auf **"Einstellungen bearbeiten"**.
- Unter **"Speicher"** wählen Sie **"RAM"** 8192 MB. Bitte beachten Sie [Server Requirements](../index.md#server-requirements).
- Unter **"Prozessor"** wählen Sie **"Anzahl der virtuellen Prozessoren"** 4. Bitte beachten Sie [Server Requirements](../index.md#server-requirements).
- Klicken Sie auf **"OK"**.
- Klicken Sie auf **"Verbinden"**.
- Klicken Sie auf **"Starten"**.

## Anmelden und die Stargate-Instanz initialisieren

- Melden Sie sich an der VM-Konsole mit dem `hinadmin`-Benutzer an, um die Stargate-Komponenten zu konfigurieren und zu installieren.
- Um das `hinadmin`-Passwort zu erhalten, senden Sie eine E-Mail an support@hin.ch mit dem Betreff: **"Password required for VM installation."**

[Hier klicken, um eine E-Mail zu senden](mailto:support@hin.ch?subject=Password%20required%20for%20VM%20installation.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20password%20for%20a%20VM%20installation.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE) { .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

```shell
sudo su -
cd ~/stargate-deployment/docker-compose/
```

- Bearbeiten Sie `customer-config.sh` mit vi/nano.
- Konfigurationsdetails finden Sie in der [README - Schritt 1: Kunden-Einstellungen konfigurieren](../Docker-deploy.md#step-1-configure-customer-settings)
- Führen Sie das Installationsskript aus:

```shell
./scripts/install.sh
```

!!! tip "Support"
    Für Fragen oder Probleme im Zusammenhang mit der Bereitstellung und dem Betrieb der Stargate-Appliance wenden Sie sich bitte an den HIN-Support.

    Bitte fügen Sie relevante Informationen wie den Kundennamen, die Appliance-Version und Screenshots/[Logs](../Docker-advanced.md#provide-logs-to-support) bei, um uns bei der effizienten Bearbeitung Ihrer Anfrage zu unterstützen.