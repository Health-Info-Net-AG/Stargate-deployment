# Authentifizierung eingehender Verbindungen

Mit der Authentifizierung eingehender Verbindungen kann ein externes System, etwa ein Mail-Relay, eine Anwendung oder ein Mail-Client, E-Mails für eine Ihrer Domains über HIN Gateway versenden, indem es sich mit Benutzername und Passwort anmeldet. Das ist nützlich, wenn der Absender nicht allein über seine IP-Adresse zugelassen werden kann.

So funktioniert es:

- Der Absender verbindet sich mit HIN Gateway über den Submission-Port **587** und authentifiziert sich mit SMTP AUTH
- Zugangsdaten werden pro Domain im HIN Gateway Dashboard erstellt


## Bevor Sie beginnen

- Sie benötigen Zugriff auf das HIN Gateway Dashboard
- Die Domain, von der Sie senden möchten, muss bereits in HIN Gateway hinzugefügt und aktiviert (onboarded) sein
- TLS muss für die Domain aktiviert sein. Passwörter werden nur über TLS akzeptiert, ohne TLS-Zertifikat funktionieren die Zugangsdaten daher nicht
- Sie benötigen Zugriff auf die Konfiguration des sendenden Systems (MTA / Anwendung), da Sie dort die neuen Zugangsdaten eintragen

## Zugangsdaten erstellen

1. Melden Sie sich beim HIN Gateway Dashboard an.
2. Öffnen Sie **Domains** und wählen Sie die Domain aus, von der Sie senden möchten.
3. Scrollen Sie nach unten zum Abschnitt **SMTP authentication (port 587)**.

    ![Abschnitt SMTP authentication](./assets/inbound-basic-auth-1.png)

    Hier werden alle Zugangsdaten aufgelistet, die für die Domain bereits bestehen.

    !!! warning "TLS muss aktiviert sein"
        Hat die Domain noch kein TLS-Zertifikat, zeigt der Abschnitt die Meldung **No TLS certificate yet**. Die Zugangsdaten funktionieren erst, wenn TLS aktiviert ist, da Passwörter nur über TLS akzeptiert werden.

        ![Warnung: kein TLS-Zertifikat](./assets/inbound-basic-auth-4.png)

        Um TLS zu aktivieren, öffnen Sie auf derselben Domain-Seite den Abschnitt **Configure TLS** und fügen Sie ein Zertifikat hinzu, oder klicken Sie auf **Generate TLS certificate**, um eines zu erzeugen. Kehren Sie danach zu diesem Abschnitt zurück.

    Der Schalter **Verify a trusted network** legt fest, von wo aus die Zugangsdaten verwendet werden können. Steht er auf **Off**, funktionieren die Zugangsdaten von jeder IP-Adresse aus. Aktivieren Sie ihn, wenn Sie Anmeldungen auf `Trusted networks` beschränken möchten.

4. Klicken Sie auf **Add credential**. Ein Formular mit zwei Feldern öffnet sich:

    ![Formular Add credential](./assets/inbound-basic-auth-2.png)

    Wählen Sie eine der folgenden Möglichkeiten:

    - **Zugangsdaten automatisch erzeugen (empfohlen):** Lassen Sie **Username** und **Password** leer. HIN Gateway erzeugt einen Benutzernamen und ein starkes Zufallspasswort
    - **Eigene Zugangsdaten festlegen:** Geben Sie **Username** und **Password** ein. Das Passwort muss mindestens 16 Zeichen lang sein.

5. Klicken Sie auf **Create**.
6. Kopieren Sie Benutzername und Passwort.

    ![Neue Zugangsdaten kopieren](./assets/inbound-basic-auth-3.png)

    !!! warning
        Das Passwort wird **nur einmal** angezeigt. Klicken Sie auf **Copy** und bewahren Sie es an einem sicheren Ort auf (zum Beispiel in einem Passwort-Manager), bevor Sie fortfahren. Geht das Passwort verloren, erzeugen Sie mit **Rotate password** ein neues.

7. Klicken Sie auf **Done**. Die neuen Zugangsdaten erscheinen nun in der Liste.

## Sendendes System konfigurieren

Tragen Sie die Zugangsdaten im sendenden MTA bzw. in der Anwendung ein:

| Einstellung       | Wert                                     |
|-------------------|------------------------------------------|
| SMTP-Server       | Die IP-Adresse Ihres HIN Gateway         |
| Port              | `587`                                    |
| Verschlüsselung   | STARTTLS                                 |
| Authentifizierung | Benutzername und Passwort (SMTP AUTH)    |
| Benutzername      | Der Benutzername aus Schritt 6           |
| Passwort          | Das Passwort aus Schritt 6               |

Die Absenderadresse (`MAIL FROM`) muss zur Domain gehören, für die die Zugangsdaten erstellt wurden, sonst wird die Nachricht abgewiesen.

## Bestehende Zugangsdaten verwalten

Für alle Zugangsdaten im Abschnitt **SMTP authentication (port 587)** stehen zwei Aktionen zur Verfügung:

- **Rotate password:** erzeugt ein neues Passwort für die Zugangsdaten. Das alte Passwort funktioniert danach nicht mehr, aktualisieren Sie das sendende System also sofort.
- **Delete:** löscht die Zugangsdaten. Systeme, die sie noch verwenden, können nicht mehr über HIN Gateway senden.


!!! tip
    Erstellen Sie für jedes sendende System eigene Zugangsdaten. So können Sie den Zugriff für ein System erneuern oder widerrufen, ohne die anderen zu beeinträchtigen.
