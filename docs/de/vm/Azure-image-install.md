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

- Navigieren Sie zu https://portal.azure.com/#home
- Klicken Sie auf **Storage accounts**
- Wählen Sie das zu verwendende Speicherkonto aus oder erstellen Sie ein neues.
- Klicken Sie auf **Block service** und dann auf **Containers**
- Wählen Sie den Container aus, in den die Datei hochgeladen werden soll, oder erstellen Sie einen neuen, falls Sie keinen Container haben.
- Klicken Sie auf **Upload** und wählen Sie die VHD-Image-Datei aus.
- Stellen Sie sicher, dass der Blob-Typ **Page Blob** ist.

## Image erstellen

- Navigieren Sie zu https://portal.azure.com/#home
- Klicken Sie auf **Images**
- Klicken Sie auf **Create**
- Wählen Sie die zu verwendende Ressourcengruppe oder erstellen Sie eine neue.
- Geben Sie einen **Namen** für das Image ein.
- Wählen Sie den **OS-Typ Linux** und **VM-Generation Gen 2**
- Bei **Storage blob** klicken Sie auf **Browse** und wählen Sie das neu hochgeladene VHD-Image aus.
- Klicken Sie auf **Review and create**
- Klicken Sie auf **Create**

## VM erstellen

- Navigieren Sie zu https://portal.azure.com/#home
- Klicken Sie auf **Virtual Machines**
- Klicken Sie auf **Create** und wählen Sie **Virtual Machine** aus dem Dropdown-Menü.
- Wählen Sie die **Ressourcengruppe**
- Geben Sie einen **Namen** für die VM ein.
- Bei **Image**, klicken Sie auf **"See all images"**, dann auf **"My Images"** und wählen Sie das neu erstellte Image aus.
- Wählen Sie die VM-Grösse.
- Wählen Sie den Authentifizierungstyp.
- Klicken Sie auf **Next: Disks**
- Wählen Sie eine OS-Disk-Grösse von mindestens 20 GiB. Bitte beachten Sie [Server Requirements](../index.md#server-requirements)
- Klicken Sie auf **Review + create**
- Klicken Sie auf **Create**

## Öffentliche IP-Adresse der neuen VM finden und eingehende Firewall-Regeln hinzufügen

- Navigieren Sie zu https://portal.azure.com/#home
- Klicken Sie auf **Virtual Machines**
- Klicken Sie auf die neue VM.
- Sie können die öffentliche IP-Adresse unter **"Primary NIC public IP"** sehen.
- Scrollen Sie nach unten zu **Networking** und klicken Sie darauf.
- Klicken Sie auf **+ Create port rule**, **Inbound port rule**, **Destination port ranges** 25, **Protocol** TCP, benennen Sie es **SMTP**, wiederholen Sie den gleichen Schritt mit **Destination port range** 1587 und benennen Sie es **mxengine**

## Anmelden und die Stargate-Instanz initialisieren

- Melden Sie sich bei der VM mit dem Benutzer an, den Sie während der VM-Erstellung gewählt haben, und der öffentlichen IP-Adresse der neuen VM:
- Um das `hinadmin`-Passwort zu erhalten, senden Sie eine E-Mail an support@hin.ch mit dem Betreff: **"Password required for VM installation."**

[Hier klicken, um eine E-Mail zu senden](mailto:support@hin.ch?subject=Password%20required%20for%20VM%20installation.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20password%20for%20a%20VM%20installation.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE) { .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

```shell
ssh hinadmin@11.22.33.44 
```

- Nach der Anmeldung in der VM:

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
