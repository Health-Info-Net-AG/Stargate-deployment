# Proxmox-Bereitstellung mittels eines Images

Stargate auf Proxmox bereitstellen

## URL der Image-Datei abrufen

- Bitte beachten Sie [VM Catalog](VM-Catalog.md?h=qcow2) für eine Liste der Images mit URLs.
- Kopieren Sie die URL in die Zwischenablage, z. B. `https://images.hin.ch/vm-images/Verimesh-HINGateway.v0.5.1.x86_64.qcow2`

## Image-Datei in Proxmox importieren

- Navigieren Sie im Proxmox-WebUI zum Menü **Storage** und klicken Sie auf **Import**
- Klicken Sie auf **Download from URL**, fügen Sie die kopierte URL ein und klicken Sie auf **"Query URL"**.
- Klicken Sie auf **Download** und warten Sie, bis **"TASK OK"** am Ende des Ausgabelogs erscheint.
- Schliessen Sie das **Task Viewer Download**-Fenster.

## VM erstellen

- Klicken Sie auf **"Create VM"**
- Geben Sie einen Namen für die VM ein.
- Klicken Sie auf **"Next"**
- Wählen Sie **"Do not use any media"**
- Klicken Sie auf **"Next"**
- Klicken Sie auf **"Next"**
- Klicken Sie auf das **"Trash icon"** neben **"scsi0"**, um es zu entfernen.
- Klicken Sie auf **"Import"** und wählen Sie unter **"Select Image"** die neu importierte Image-Datei aus.
- Klicken Sie auf **"Next"**
- Wählen Sie **4 CPU-Kerne** und den **CPU-Typ** (oder verwenden Sie **"host"**). Bitte beachten Sie [Server Requirements](../index.md#server-requirements).
- Klicken Sie auf **"Next"**
- Wählen Sie **8192 MiB Memory**. Bitte beachten Sie [Server Requirements](../index.md#server-requirements).
- Klicken Sie auf **"Next"**
- Klicken Sie auf **"Next"**
- Warten Sie, bis der VM-Erstellungsprozess abgeschlossen ist, klicken Sie dann auf die neue VM, klicken Sie auf **"Console"**, dann auf **"Start Now"**

## HIN Gateway installieren

Nach erfolgreicher Erstellung der VM fahren Sie mit den Installations- und Onboarding-Schritten fort, wie in den bereitgestellten [Anweisungen](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/) beschrieben.

!!! tip "Support"
    Für Fragen oder Probleme im Zusammenhang mit der Bereitstellung und dem Betrieb der Stargate-Appliance wenden Sie sich bitte an den HIN-Support.

    Bitte fügen Sie relevante Informationen wie den Kundennamen, die Appliance-Version und Screenshots/[Logs](../Docker-advanced.md#provide-logs-to-support) bei, um uns bei der effizienten Bearbeitung Ihrer Anfrage zu unterstützen.
