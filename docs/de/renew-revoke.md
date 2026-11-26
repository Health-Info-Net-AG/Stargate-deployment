# Domain-Zertifikate erneuern und widerrufen

Jede Domain in HIN Gateway hat ein Domain-Zertifikat. HIN Gateway verwendet es, um Nachrichten für die Domain zu signieren und zu verschlüsseln. Im Dashboard können Sie das Zertifikat automatisch von HIN Gateway erneuern lassen, ein Zertifikat widerrufen und ein neues ausstellen.

## Domain-Zertifikate anzeigen

1. Melden Sie sich im HIN Gateway Dashboard an
2. Öffnen Sie **Domains** und wählen Sie die Domain aus
3. Öffnen Sie den Bereich **Domain certificates**

    ![Bereich Domain certificates mit einem Zertifikat im Status Good](./assets/domain-certs-1.png)

    Für jedes Zertifikat zeigt der Bereich die **Serial Number**, die Gültigkeitsdauer (**Valid from** und **Valid until**) und den **Status** an.
    Ein Zertifikat, das bald abläuft, ist mit **Expiring soon** markiert, und sein Datum unter **Valid until** wird rot angezeigt.

## Zertifikate nach Status filtern

Mit dem Filter **Status** oben rechts im Bereich wählen Sie aus, welche Zertifikate angezeigt werden:

- **Good:** gültige Zertifikate, die aktuell verwendet werden
- **Revoked:** widerrufene Zertifikate
- **Expired:** Zertifikate, deren Gültigkeitsdauer abgelaufen ist

![Domain-Zertifikate gefiltert nach Status Revoked](./assets/domain-certs-4.png)

## Automatische Erneuerung ein- oder ausschalten

Der Schalter **Auto renew** legt fest, ob HIN Gateway das Zertifikat automatisch erneuert:

- **Ein:** HIN Gateway erneuert das Zertifikat automatisch, kurz bevor es abläuft. Diese Einstellung wird empfohlen
- **Aus:** Das Zertifikat wird nicht erneuert. Wenn es abläuft, müssen Sie manuell ein neues Zertifikat ausstellen

Klicken Sie auf den Schalter, um die Einstellung zu ändern.

!!! warning
    Wenn die automatische Erneuerung ausgeschaltet ist und das Zertifikat abläuft, kann HIN Gateway damit keine Nachrichten mehr signieren und verschlüsseln, bis Sie ein neues Zertifikat ausstellen.

## Ein Zertifikat widerrufen

Widerrufen Sie ein Zertifikat, wenn es nicht mehr verwendet werden soll, zum Beispiel wenn Sie vermuten, dass der Schlüssel kompromittiert ist.

1. Suchen Sie im Bereich **Domain certificates** das Zertifikat, das Sie widerrufen möchten
2. Klicken Sie auf das rote Symbol **Revoke** (durchgestrichener Kreis). Ein Bestätigungsfenster öffnet sich

    ![Bestätigung zum Widerrufen des Zertifikats](./assets/domain-certs-2.png)

3. Klicken Sie zur Bestätigung auf **Revoke** oder auf **Cancel**, um das Zertifikat zu behalten.

!!! warning
    Der Widerruf eines Zertifikats kann nicht rückgängig gemacht werden. Das Zertifikat hat danach den Status **Revoked** und erscheint unter dem Statusfilter **Revoked**.

## Ein neues Zertifikat ausstellen

Sie können aus einem abgelaufenen oder einem widerrufenen Zertifikat ein neues Zertifikat ausstellen.

1. Wählen Sie im Filter **Status** die Option **Expired** oder **Revoked**.
2. Suchen Sie das Zertifikat und klicken Sie auf das Symbol **Renew** (Uhr mit Pfeil). Ein Bestätigungsfenster öffnet sich.

    ![Bestätigung zum Erneuern des Zertifikats](./assets/domain-certs-3.png)

3. Klicken Sie zur Bestätigung auf **Renew** oder auf **Cancel**, um abzubrechen.

HIN Gateway erzeugt einen neuen öffentlichen und privaten Schlüssel und stellt das neue Zertifikat aus. War das alte Zertifikat noch gültig, wird es widerrufen.

!!! note
    Es kann einige Stunden dauern, bis das neue Zertifikat bei allen anderen Teilnehmenden angekommen ist. In dieser Zeit können Sie Nachrichten weiterhin mit Ihrem aktuellen privaten Schlüssel entschlüsseln.

## Das neue Zertifikat prüfen

Wählen Sie im Filter **Status** die Option **Good**. Das neue Zertifikat wird mit dem Status **Good** sowie einer neuen **Serial Number** und Gültigkeitsdauer angezeigt.
