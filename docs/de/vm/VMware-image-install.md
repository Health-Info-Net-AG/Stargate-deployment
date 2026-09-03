# HIN Gateway VMware ESXi-Bereitstellung mittels eines Images

HIN Gateway auf VMware bereitstellen

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

!!! info "Data Disk enthalten"
    Die OVA enthält bereits die Data Disk der Appliance (`VEREIGN-DATA`, gemountet unter `/var/data`) — es muss keine zusätzliche Festplatte angehängt werden. Siehe [Installationsanleitung → Schritt 4](../Installation-guide.md#schritt-4-vm-image-laden).

## HIN Gateway installieren

Nach erfolgreicher Erstellung der VM fahren Sie mit den Installations- und Onboarding-Schritten fort, wie in den bereitgestellten [Anweisungen](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/) beschrieben.

!!! tip "Support"
    Für Fragen oder Probleme im Zusammenhang mit der Bereitstellung und dem Betrieb der Stargate-Appliance wenden Sie sich bitte an den HIN-Support.

    Bitte fügen Sie relevante Informationen wie den Kundennamen, die Appliance-Version und Screenshots/[Logs](../Docker-advanced.md#logs-an-den-support-senden) bei, um uns bei der effizienten Bearbeitung Ihrer Anfrage zu unterstützen.
