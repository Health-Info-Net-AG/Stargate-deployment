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

!!! warning "Update auf ein Major-Release"
    Das Update von 0.6.x auf 1.1.7 ist ein Major-Release-Update. Sie müssen vor Beginn des Updates einen Snapshot der VM als Sicherung erstellen.

    Dieses Release enthält ein erforderliches Sicherheitsupdate, das Keycloak auf 26.8.0 aktualisiert. Bei diesem Upgrade [ändert Keycloak das Datenbankschema](https://github.com/keycloak/keycloak/blob/main/model/jpa/src/main/resources/META-INF/jpa-changelog-26.8.0.xml#L348) und entfernt eine Spalte sowie Indizes, die die vorherige Keycloak-Version (26.7.4) benötigt. Deshalb kann die Schaltfläche `Roll back` keine funktionsfähige Version 0.6.x wiederherstellen. Der VM-Snapshot ist die einzige Möglichkeit, zur vorherigen Version zurückzukehren.

## Wie man ein Rollback durchführt

1. Gehen Sie zur Seite `Settings` und scrollen Sie zum Abschnitt `System version`.

   <br> ![system-version](assets/configuration/step1-update-vm.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

2. Klicken Sie auf die Schaltfläche `Roll back to vX.X.X`.

3. Bestätigen Sie die Aktion auf dem Bestätigungsbildschirm. Das System startet neu und installiert die vorherige stabile Version.

   <br> ![system-version](assets/configuration/step1-rollback.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
