
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
- Unter **"Speicher"** wählen Sie **"RAM"** 8192 MB. Bitte beachten Sie [Server Requirements](../index.md#server-anforderungen).
- Unter **"Prozessor"** wählen Sie **"Anzahl der virtuellen Prozessoren"** 4. Bitte beachten Sie [Server Requirements](../index.md#server-anforderungen).
- Klicken Sie auf **"OK"**.
- Klicken Sie auf **"Verbinden"**.
- Klicken Sie auf **"Starten"**.

!!! warning "Zuerst die Data Disk anhängen"
    Hängen Sie vor dem ersten Start eine zweite, leere Festplatte mit mindestens 30 GB an. Beim ersten Start formatiert die Appliance sie als Data Disk (`VEREIGN-DATA`, gemountet unter `/var/data`) und speichert dort die gesamte Konfiguration und alle Daten; ohne sie schlägt der Start fehl und wird zurückgerollt. Siehe [Installationsanleitung → Schritt 4](../Installation-guide.md#schritt-4-vm-image-laden).

## HIN Gateway installieren

Nach erfolgreicher Erstellung der VM fahren Sie mit den Installations- und Onboarding-Schritten fort, wie in den bereitgestellten [Anweisungen](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/) beschrieben.

!!! tip "Support"
    Für Fragen oder Probleme im Zusammenhang mit der Bereitstellung und dem Betrieb der Stargate-Appliance wenden Sie sich bitte an den HIN-Support.

    Bitte fügen Sie relevante Informationen wie den Kundennamen, die Appliance-Version und Screenshots/[Logs](../Docker-advanced.md#logs-an-den-support-senden) bei, um uns bei der effizienten Bearbeitung Ihrer Anfrage zu unterstützen.
