# Authentifizierung ausgehender Verbindungen

Wenn HIN Gateway Nachrichten für eine Domain an den nächsten Hop weiterleitet (zum Beispiel an ein Mail-Relay oder einen Mailserver), kann dieser verlangen, dass sich der Absender anmeldet, bevor er E-Mails annimmt. Mit der Authentifizierung ausgehender Verbindungen meldet sich HIN Gateway beim nächsten Hop mit Benutzername und Passwort an (SMTP AUTH).

So funktioniert es:

- Jede Domain hat im HIN Gateway Dashboard ein eigenes **Outbound relay** (Host und Port)
- Ist **Require authentication** aktiv, meldet sich HIN Gateway mit den von Ihnen eingegebenen Zugangsdaten beim Outbound Relay an, bevor es eine Nachricht weiterleitet

## Bevor Sie beginnen

- Sie benötigen Zugriff auf das HIN Gateway Dashboard
- Die Domain muss bereits in HIN Gateway hinzugefügt und aktiviert (onboarded) sein
- Erfragen Sie Benutzername und Passwort bei der Administration der empfangenden Seite (des Relays oder Mailservers, der die Authentifizierung verlangt)

## Zugangsdaten konfigurieren

1. Melden Sie sich beim HIN Gateway Dashboard an.
2. Öffnen Sie **Domains** und wählen Sie die Domain aus.
3. Scrollen Sie nach unten zu **Mail routing** und suchen Sie den Abschnitt **Outbound**.

    ![Abschnitt Outbound mit inaktiver Authentifizierung](./assets/outbound-basic-auth-1.png)

    Prüfen Sie, ob **Outbound relay** den richtigen Host und Port des nächsten Hops anzeigt (zum Beispiel `relay.example.com:25`). Diese Zugangsdaten werden nur für dieses Relay verwendet.

4. Klicken Sie auf den Schalter **Require authentication**, sodass er **Active** anzeigt. Die Felder **Username** und **Password** erscheinen.

    ![Abschnitt Outbound mit aktiver Authentifizierung](./assets/outbound-basic-auth-2.png)

5. Geben Sie den auf der empfangenden Seite konfigurierten **Username** und das **Password** ein. Klicken Sie auf das Augen-Symbol, um das Passwort anzuzeigen und auf Tippfehler zu prüfen.
6. Scrollen Sie nach unten und klicken Sie auf **Save**.

Ab sofort meldet sich HIN Gateway bei jeder Weiterleitung einer Nachricht für diese Domain beim Outbound Relay an.

## Konfiguration überprüfen

Senden Sie über HIN Gateway eine Testnachricht an einen Empfänger hinter dem Outbound Relay und prüfen Sie, ob sie ankommt. Falls nicht, öffnen Sie im Dashboard **Logs** und suchen Sie nach Authentifizierungsfehlern des Relays. Die häufigsten Ursachen sind:

- Falscher Benutzername oder falsches Passwort
- Das Relay unterstützt SMTP AUTH auf dem konfigurierten Port nicht oder lässt es nicht zu
- Host oder Port des **Outbound relay** ist falsch

## Zugangsdaten ändern oder entfernen

- **Passwort ändern:** Wenn die empfangende Seite das Passwort ändert, geben Sie das neue im Feld **Password** ein und klicken Sie auf **Save**. Bis dahin schlägt die Authentifizierung für Nachrichten an das Relay fehl.
- **Authentifizierung ausschalten:** Klicken Sie auf **Require authentication**, sodass **Inactive** angezeigt wird, und klicken Sie auf **Save**. HIN Gateway verbindet sich dann ohne Anmeldung mit dem Relay.
