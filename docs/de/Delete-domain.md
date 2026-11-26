# Eine Domain löschen

Sie können eine Domain aus HIN Gateway löschen, wenn über das Gateway keine E-Mails für diese Domain mehr gesendet oder empfangen werden sollen, zum Beispiel weil die Domain stillgelegt oder auf ein anderes System umgezogen wurde.

Diese Schritte gelten für beide Domain-Typen auf der Seite **Domains**: **Secure** (HIN Secure-Domains) und **Routed** Domains. Mehr zu Routed Domains finden Sie unter [Verwalten von Routed Domains in HIN Gateway](Routed-domains.md).

## Vor dem Löschen

- Stellen Sie sicher, dass kein System mehr E-Mails für die Domain über HIN Gateway sendet. Nach dem Löschen verarbeitet HIN Gateway keine Nachrichten mehr für diese Domain
- Entscheiden Sie, ob das Domain-Zertifikat widerrufen werden soll. Ein Widerruf kann nicht rückgängig gemacht werden

## Die Domain löschen

1. Melden Sie sich im HIN Gateway Dashboard an.
2. Öffnen Sie **Domains** und wählen Sie die Domain aus, die Sie löschen möchten. Die Seite **Domain details** öffnet sich.
3. Klicken Sie neben dem Domain-Status auf das rote Symbol **Delete** (Papierkorb).

    ![Seite Domain details mit dem Löschsymbol](./assets/delete-domain-1.png)

    Ein Bestätigungsfenster öffnet sich.

    ![Bestätigung zum Löschen der Domain](./assets/delete-domain-2.png)

4. Legen Sie fest, ob das Domain-Zertifikat widerrufen werden soll:

    - **Revoke domain's certificate** ausgewählt: Das Zertifikat der Domain wird beim Löschen der Domain ebenfalls widerrufen
    - **Revoke domain's certificate** nicht ausgewählt: Die Domain wird gelöscht, ihr Zertifikat wird jedoch nicht widerrufen

5. Klicken Sie auf **Yes**, um die Domain zu löschen, oder auf **No**, um abzubrechen.

Die Domain wird aus der Liste **Domains** entfernt.

!!! warning
    Wenn Sie **Revoke domain's certificate** auswählen, wird das Zertifikat widerrufen und kann nicht mehr verwendet werden. Ein Widerruf kann nicht rückgängig gemacht werden.
