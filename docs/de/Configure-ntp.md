# NTP konfigurieren

HIN Gateway hält seine Uhrzeit mit NTP (Network Time Protocol) genau. Eine genaue Uhrzeit ist zwingend: Zertifikatsprüfung, Nachrichtensignierung und Anmeldesitzungen schlagen fehl, wenn die Uhr abweicht.

So funktioniert es:

- Standardmässig synchronisiert HIN Gateway seine Uhrzeit mit `ntp.metas.ch`
- Wenn Ihr Netzwerk kein ausgehendes NTP ins Internet zulässt oder Ihre Organisation eigene Zeitserver betreibt, können Sie den Standard durch einen oder mehrere eigene Zeitserver ersetzen
- Sie können mehrere Zeitserver hinzufügen. Ist einer nicht erreichbar, verwendet HIN Gateway den nächsten

## Bevor Sie beginnen

- Sie benötigen Zugriff auf das HIN Gateway Dashboard
- Erfragen Sie den Hostnamen des Zeitservers (bzw. der Zeitserver) bei Ihrer Netzwerkadministration
- Stellen Sie sicher, dass HIN Gateway den Zeitserver (bzw. die Zeitserver) über UDP-Port 123 erreichen kann

## Aktuelle Zeitsynchronisation prüfen

1. Melden Sie sich beim HIN Gateway Dashboard an.
2. Öffnen Sie **Settings** und scrollen Sie nach unten zum Abschnitt **Time synchronisation**.

    ![Abschnitt Time synchronisation mit dem Standard-Zeitserver](./assets/ntp-config-1.png)

    Die Statuszeile zeigt, ob die Uhr synchron ist (**In sync**), zusammen mit der IP-Adresse des verwendeten Zeitservers, dem Offset und dem Stratum. **Time servers** zeigt, welche Server konfiguriert sind. Ohne eigene Server steht dort **Using the default time server (ntp.metas.ch)**.

## Eigene Zeitserver hinzufügen

1. Klicken Sie im Abschnitt **Time synchronisation** auf **Edit**. Ein leeres Feld für den ersten Zeitserver erscheint.

    ![Abschnitt Time synchronisation im Bearbeitungsmodus](./assets/ntp-config-2.png)

2. Geben Sie den Hostnamen des Zeitservers ein (zum Beispiel `ntp.example.com`).
3. Wählen Sie mit dem Schalter neben dem Feld die Art des Eintrags:
    - **Server**: ein einzelner NTP-Server
    - **Pool**: ein NTP-Pool, also ein Hostname, der auf mehrere Server auflöst (zum Beispiel `ch.pool.ntp.org`). HIN Gateway verwendet mehrere Server aus dem Pool
4. Um einen weiteren Zeitserver hinzuzufügen, klicken Sie auf **Add server** und wiederholen Sie die Schritte 2 und 3. Sie können Pools und Server kombinieren.

    ![Abschnitt Time synchronisation mit einem Pool und einem Server](./assets/ntp-config-3.png)

    Um einen Eintrag zu entfernen, klicken Sie auf das Minus-Symbol daneben.

5. Klicken Sie auf **Save**.

HIN Gateway synchronisiert seine Uhrzeit nun mit den konfigurierten Zeitservern statt mit dem Standard-Zeitserver.

## Konfiguration überprüfen

Prüfen Sie die Statuszeile im Abschnitt **Time synchronisation**. Sie sollte **In sync** und die IP-Adresse eines Ihrer Zeitserver anzeigen. Um sofort zu synchronisieren, klicken Sie auf **Sync now**.

## Zum Standard-Zeitserver zurückkehren

Klicken Sie auf **Edit**, entfernen Sie alle Einträge mit dem Minus-Symbol und klicken Sie auf **Save**. HIN Gateway verwendet dann wieder `ntp.metas.ch`.
