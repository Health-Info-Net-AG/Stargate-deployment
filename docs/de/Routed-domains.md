# Verwalten von Routed Domains in HIN Gateway

HIN Gateway kann auch den E-Mail-Verkehr für Domains abwickeln, die keine HIN Secure-Domains sind. Dies ist ein gängiges Setup für Kunden, die ihre eigene On-Premises-Mailserver-Infrastruktur betreiben.
Diese Funktion ist in HIN Gateway integriert, sodass Kunden ihr Mail-Setup an ihre eigenen Anforderungen anpassen können.

In HIN Gateway werden diese Domains als **Routed** Domains bezeichnet.
E-Mails für eine Routed Domain durchlaufen HIN Gateway ohne Verarbeitung für die sichere Nachrichtenübermittlung: Sie werden einfach an den nächsten Relay-Host weitergeleitet.


## Eine Routed Domain hinzufügen

Öffnen Sie die Seite **Domains**, klicken Sie auf **Add domain**, geben Sie den Domainnamen ein und klicken Sie auf **Save**.

<br> ![Screenshot](assets/routed-domains/add-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Die Routed Domain konfigurieren

Aktivieren Sie die Domain und konfigurieren Sie sie genauso wie eine HIN Secure-Domain. Die detaillierten Schritte finden Sie in der Installationsanleitung unter [Schritt 14 - E-Mail-Transport konfigurieren](Installation-guide.md#schritt-14-e-mail-transport-konfigurieren).


<br> ![Screenshot](assets/routed-domains/activate-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
