# Stargate Azure Deployment mittels eines Images

Stargate auf Azure bereitstellen

## Azure Port 25 (SMTP) Anforderungen

!!! warning
    Bevor Sie mit der Installation auf Microsoft Azure beginnen, überprüfen Sie die folgenden Anforderungen in Bezug auf ausgehende SMTP-Konnektivität auf Port 25. Das Überspringen dieses Schritts kann nach der Installation zu E-Mail-Zustellungsfehlern führen.

Ob Port 25 verfügbar ist, hängt von Ihrem Azure-Abonnementtyp ab:

- :white_check_mark: **Enterprise Agreement (EA) oder MCA-E** – Ausgehender SMTP auf Port 25 ist nicht blockiert. Beachten Sie, dass externe Domänen E-Mails dennoch ablehnen können – dies liegt ausserhalb der Kontrolle von Azure.
- :white_check_mark: **Enterprise Dev/Test** – Standardmässig blockiert, kann aber entfernt werden. Um die Entfernung zu beantragen, gehen Sie zu *Diagnose und Behebung* > *E-Mails können nicht gesendet werden (SMTP-Port 25)* in der Azure Virtual Network-Ressource im Azure-Portal.
- :x: **Alle anderen Abonnementtypen** – Blockiert und **kann nicht entsperrt werden**.

Referenz: [Troubleshoot outbound SMTP connectivity in Azure](https://learn.microsoft.com/en-us/troubleshoot/azure/virtual-network/troubleshoot-outbound-smtp-connectivity)

## Image-Datei herunterladen

- Laden Sie die neueste VHD-Image-Datei herunter. Bitte beachten Sie [VM Catalog](VM-Catalog.md?h=vhd)

## Azure VHD-Image-Datei hochladen

- Navigieren Sie zu <https://portal.azure.com/#home>
- Klicken Sie auf **Storage accounts**
- Wählen Sie das zu verwendende Speicherkonto aus oder erstellen Sie ein neues.
- Klicken Sie auf **Block service** und dann auf **Containers**
- Wählen Sie den Container aus, in den die Datei hochgeladen werden soll, oder erstellen Sie einen neuen, falls Sie keinen Container haben.
- Klicken Sie auf **Upload** und wählen Sie die VHD-Image-Datei aus.
- Stellen Sie sicher, dass der Blob-Typ **Page Blob** ist.

## Image erstellen

- Navigieren Sie zu <https://portal.azure.com/#home>
- Klicken Sie auf **Images**
- Klicken Sie auf **Create**
- Wählen Sie die zu verwendende Ressourcengruppe oder erstellen Sie eine neue.
- Geben Sie einen **Namen** für das Image ein.
- Wählen Sie den **OS-Typ Linux** und **VM-Generation Gen 2**
- Bei **Storage blob** klicken Sie auf **Browse** und wählen Sie das neu hochgeladene VHD-Image aus.
- Klicken Sie auf **Review and create**
- Klicken Sie auf **Create**

## VM erstellen

- Navigieren Sie zu <https://portal.azure.com/#home>
- Klicken Sie auf **Virtual Machines**
- Klicken Sie auf **Create** und wählen Sie **Virtual Machine** aus dem Dropdown-Menü.
- Wählen Sie die **Ressourcengruppe**
- Geben Sie einen **Namen** für die VM ein.
- Bei **Image**, klicken Sie auf **"See all images"**, dann auf **"My Images"** und wählen Sie das neu erstellte Image aus.
- Wählen Sie die VM-Grösse.
- Wählen Sie den Authentifizierungstyp.
- Klicken Sie auf **Next: Disks**
- Wählen Sie eine OS-Disk-Grösse von mindestens 20 GiB. Bitte beachten Sie [Server Requirements](../index.md#server-anforderungen)
- Klicken Sie auf **Review + create**
- Klicken Sie auf **Create**

## Öffentliche IP-Adresse der neuen VM finden und eingehende Firewall-Regeln hinzufügen

- Navigieren Sie zu <https://portal.azure.com/#home>
- Klicken Sie auf **Virtual Machines**
- Klicken Sie auf die neue VM.
- Sie können die öffentliche IP-Adresse unter **"Primary NIC public IP"** sehen.
- Scrollen Sie nach unten zu **Networking** und klicken Sie darauf.
- Klicken Sie auf **+ Create port rule**, **Inbound port rule**, **Destination port ranges** 25, **Protocol** TCP, benennen Sie es **SMTP**. Wiederholen Sie dies für die weiteren erforderlichen eingehenden Ports — **8084** (Seal-Callback) und **19818** (WireGuard). Die vollständige Liste finden Sie unter [Server-Anforderungen → Eingehender Netzwerkzugriff](../index.md#eingehender-netzwerkzugriff-firewall-muss-erlauben).

!!! warning "Zuerst die Data Disk anhängen"
    Hängen Sie vor dem ersten Start eine zweite, leere Festplatte mit mindestens 30 GB an. Beim ersten Start formatiert die Appliance sie als Data Disk (`VEREIGN-DATA`, gemountet unter `/var/data`) und speichert dort die gesamte Konfiguration und alle Daten; ohne sie schlägt der Start fehl und wird zurückgerollt. Siehe [Installationsanleitung → Schritt 4](../Installation-guide.md#schritt-4-vm-image-laden).

## HIN Gateway installieren

Nach erfolgreicher Erstellung der VM fahren Sie mit den Installations- und Onboarding-Schritten fort, wie in den bereitgestellten [Anweisungen](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/) beschrieben.

!!! tip "Support"
    Für Fragen oder Probleme im Zusammenhang mit der Bereitstellung und dem Betrieb der Stargate-Appliance wenden Sie sich bitte an den HIN-Support.

    Bitte fügen Sie relevante Informationen wie den Kundennamen, die Appliance-Version und Screenshots/[Logs](../Docker-advanced.md#logs-an-den-support-senden) bei, um uns bei der effizienten Bearbeitung Ihrer Anfrage zu unterstützen.
