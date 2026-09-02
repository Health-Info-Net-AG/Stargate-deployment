# Update HIN Gateway

Dieses Dokument erklärt:

* Wie Sie eine HIN Gateway Instanz auf eine neuere Version aktualisieren.
* Wie Sie ein Rollback auf eine vorherige Version durchführen.

!!! warning "Anwendbare Versionen"
    Dieses Verfahren gilt nur für Version 0.6.x und höher.

## Wie man aktualisiert

1. Gehen Sie zur Seite `Settings` und scrollen Sie zum Abschnitt `System version`.

   <br> ![system-version](assets/configuration/step1-update-vm.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

2. Klicken Sie auf `Other versions`.

3. Wählen Sie aus der Liste der verfügbaren Versionen die Zielversion aus.

   * Neuere Versionen verwenden eine fortlaufende Nummerierung, daher hat die Zielversion eine höhere Nummer als die aktuelle.

4. Klicken Sie auf die Schaltfläche `Download`. Dadurch wird nur der Download gestartet, das Update wird noch nicht installiert.

   <br> ![system-version](assets/configuration/step2-update-vm.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

   <br> ![system-version](assets/configuration/step4-update-vm-downloading.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

5. Nach Abschluss des Downloads erscheint ein Bestätigungsdialog mit zwei Optionen:

   * `Restart now`: startet die Maschine sofort neu und installiert die neue Version.
   * `Later`: verschiebt das Update. Die neue Version wird beim nächsten Neustart der Maschine installiert.

   <br> ![system-version](assets/configuration/step5-update-vm-confir-restart.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

   <br> ![system-version](assets/configuration/step5-updatevm-later-restart.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Wie man ein Rollback durchführt

1. Gehen Sie zur Seite `Settings` und scrollen Sie zum Abschnitt `System version`.

   <br> ![system-version](assets/configuration/step1-update-vm.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

2. Klicken Sie auf die Schaltfläche `Roll back to vX.X.X`.

3. Bestätigen Sie die Aktion auf dem Bestätigungsbildschirm. Das System startet neu und installiert die vorherige stabile Version.

   <br> ![system-version](assets/configuration/step1-rollback.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
