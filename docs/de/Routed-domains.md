# Verwalten von Routed Domains in HIN Gateway

HIN Gateway kann auch den Datenverkehr für Domains verwalten, die keine HIN Secure-Domains sind. Dies ist ein gängiges Setup für Kunden, die ihre eigene On-Premises-E-Mail-Server-Infrastruktur betreiben.
Diese Funktion ist in HIN Gateway integriert und gibt Kunden die Flexibilität, ihre Kommunikationsumgebung präzise nach ihren Bedürfnissen zu gestalten.

In HIN Gateway werden diese Domains als **Routed** Domains bezeichnet.
Eine Routed Domain ist eine Domain, deren Datenverkehr durch HIN Gateway geleitet wird, ohne für sichere Nachrichtenübermittlung verarbeitet zu werden - er wird hauptsächlich an den nächsten Relay-Host weitergeleitet.


### Eine Routed Domain hinzufügen

Öffnen Sie die Seite **Domains**, klicken Sie auf **Add domain**, geben Sie den Domainnamen ein und klicken Sie anschliessend auf **Save**.

<br> ![Screenshot](assets/routed-domains/add-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Die Routed Domain konfigurieren

Aktivieren Sie die Domain und konfigurieren Sie sie genauso wie jede andere HIN Secure-Domain. Detaillierte Konfigurationsschritte finden Sie im [Leitfaden zur Mail-Transport-Konfiguration](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/#step-14-configure-mail-transport).


<br> ![Screenshot](assets/routed-domains/activate-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
