## v1.2.0

*Veröffentlicht am 26. November 2026.*

Mit diesem Release verwalten Sie Domain-Zertifikate vollständig im Dashboard: Zertifikate werden jetzt automatisch erneuert, und Sie können ein Zertifikat selbst widerrufen oder ein neues ausstellen. Domains können jetzt gelöscht werden, HIN kann Updates für Ihr HIN Gateway planen, und grössere Anhänge werden unterstützt. Ausserdem enthält das Release mehrere Fehlerbehebungen bei der E-Mail-Verarbeitung.

### Highlights

#### Domain-Zertifikate erneuern, widerrufen und neu ausstellen

- **Automatische Erneuerung:** HIN Gateway erneuert das Domain-Zertifikat automatisch vor dem Ablauf und widerruft das alte Zertifikat. Die automatische Erneuerung (**Auto renew**) ist für alle bestehenden und neuen Zertifikate standardmässig aktiviert und kann pro Zertifikat ausgeschaltet werden.
- Mit der Schaltfläche **Renew** stellen Sie aus einem abgelaufenen oder widerrufenen Zertifikat ein neues aus. HIN Gateway erzeugt neue Schlüssel, und ein noch gültiges Zertifikat wird widerrufen.
- Zertifikate lassen sich direkt im Dashboard widerrufen, etwa wenn Sie vermuten, dass der Schlüssel kompromittiert ist.
- Der Bereich **Domain certificates** hat ein neues Design und einen **Status**-Filter (Good, Revoked, Expired). Bald ablaufende Zertifikate sind mit **Expiring soon** markiert.
- Ein Hinweisbanner warnt vor ablaufenden Zertifikaten, die Seite **Domains** hat einen neuen Filter **Expires in 30 days**, und Domains mit ablaufendem oder fehlendem Zertifikat sind in der Domain-Tabelle gekennzeichnet.

Siehe [Domain-Zertifikate erneuern und widerrufen](renew-revoke.md).

#### Domains löschen

- Secure- und Routed-Domains können jetzt auf der Seite **Domain details** gelöscht werden. Das Bestätigungsfenster zeigt den Domain-Namen an, und Sie können gleichzeitig das Domain-Zertifikat widerrufen.
- TLS-Zertifikate können auf der Seite **Domain details** gelöscht werden.

Siehe [Eine Domain löschen](Delete-domain.md).

#### Geplante Updates

- HIN kann jetzt ein Update Ihres HIN Gateway auf eine bestimmte Version zu einem festgelegten Zeitpunkt planen. HIN Gateway prüft regelmässig, ob ein Update geplant ist, und führt es zum festgelegten Zeitpunkt aus. Die Verbindung geht immer vom HIN Gateway aus, über den bestehenden Tunnel.
- Vor jedem Update wird automatisch ein Backup erstellt, damit das System bei einem fehlgeschlagenen Update wiederhergestellt werden kann.
- Das Dashboard zeigt den Fortschritt eines laufenden Updates an.

### Neuerungen und Verbesserungen

- **Grössere Anhänge:** E-Mails mit Anhängen bis insgesamt 25 MB können jetzt über HIN Gateway und SEAL versendet werden.
- **Sicherheit:** HIN Gateway prüft jetzt, ob das Absenderzertifikat zur Domain des Absenders gehört. Der Widerruf eines Zertifikats ist mit dem Dashboard-Benutzerkonto verknüpft, über das er angefordert wurde.
- **Header:** Im Dashboard konfigurierte Header werden genau so gespeichert, wie sie eingegeben wurden, und vor dem Speichern validiert.
- **Trusted Networks:** Das Dashboard zeigt eine Benachrichtigung an, wenn die Trusted Networks nicht aufgelöst werden können.
- **sec-Präfix:** Die Option **Use sec-prefix** ist ausgegraut, wenn für `sec.<domain>` kein MX-Eintrag existiert.
- **Onboarding:** Domains, die Sie erst später einrichten möchten, werden mit dem Status Inactive hinzugefügt.
- **Peers:** Die Peer-Liste im Dashboard wird mit dem zentralen Dienst synchronisiert.
- **WireGuard:** Die WireGuard-IP-Adresse kann im Dashboard nicht mehr geändert werden.
- **SEAL:** Wer fortfährt, ohne die Option zum Angemeldetbleiben zu wählen, wird gefragt, ob das Gerät gespeichert werden soll. So lassen sich künftige sichere Nachrichten ohne neuen Bestätigungscode lesen. SEAL nutzt zudem einen neuen SMS-Anbieter für Bestätigungscodes.
- **Komponenten-Updates:** Zugrunde liegende Dienste und Abhängigkeiten wurden aktualisiert und gemeldete Schwachstellen in Paketen von Drittanbietern behoben.

### Fehlerbehebungen

- Problem behoben, bei dem Anhänge auf etwa das 2,5-Fache ihrer Grösse anwuchsen, sodass Dateien von rund 11 MB das Limit von 25 MB überschritten.
- Fehlgeschlagene Body-Hash-Prüfung von DKIM-Signaturen behoben.
- Verlust des E-Mail-Texts behoben, wenn eine eingehende Regel den Betreff zweimal änderte.
- HIN Gateway behält jetzt die ursprüngliche Reihenfolge sowie die Gross- und Kleinschreibung der E-Mail-Header bei.
- Von Lobos erzeugte E-Mails werden vom MIME-Parser nicht mehr abgelehnt.
- Validierung im Mail-Handler verbessert.
- 500 Internal Server Error beim Speichern der E-Mail-Authentifizierungseinstellungen ohne ARC-Selektor behoben.
- Problem behoben, bei dem ein Peer-Eintrag erstellt wurde, wenn der zweite Installationsschritt fehlschlug.
- Beim Neugenerieren des Aktivierungscodes wird der Peer jetzt korrekt zurückgesetzt, wenn seine Verbindung bereits gelöscht war.
- Bei einem falschen Aktivierungscode wird jetzt die richtige Fehlermeldung angezeigt.
- Fehler beim Löschen einer Domain behoben. Ein Zertifikat lässt sich jetzt wieder importieren, nachdem seine Domain gelöscht und erneut hinzugefügt wurde.
- Führende und nachgestellte Leerzeichen werden beim Erstellen oder Aktualisieren einer Domain jetzt entfernt.
- Ein Rollback des Iris Agent auf eine frühere Version beschädigt die Installation nicht mehr.
- SEAL: Fehlermeldungen zu TOTP korrigiert, auch wenn ein neues TOTP-Secret den Namen eines inaktiven Secrets trägt.
- Das französische Dashboard verwendet jetzt einen einheitlichen Begriff für Peer.

### Wichtige Informationen

Nach dem Update ist die automatische Erneuerung für alle bestehenden Domain-Zertifikate aktiviert. Wenn ein Zertifikat nicht automatisch erneuert werden soll, schalten Sie **Auto renew** im Bereich **Domain certificates** der Domain aus.

Das Update kann direkt über das HIN Gateway Dashboard durchgeführt werden. Ein manueller Download des VM-Images ist nicht erforderlich.


## v1.1.8

*Veröffentlicht am 10. November 2026.*

Dieses Wartungs- und Sicherheitsrelease behebt eine Schwachstelle im Linux-Kernel und aktualisiert mehrere zugrunde liegende Komponenten, um die Sicherheit, Stabilität und Zuverlässigkeit von HIN Gateway zu verbessern.

### Neuerungen und Verbesserungen

- **Sicherheit:** Der Linux-Kernel wurde aktualisiert, um CVE-2026-98432 zu beheben.
- **Komponenten-Updates:** Mehrere zugrunde liegende Dienste und Abhängigkeiten wurden aktualisiert, darunter Keycloak, Stalwart, Caddy, NATS, Loki und weitere Infrastrukturkomponenten.
- **Systemwartung:** Container-Images und Komponenten des Basisbetriebssystems wurden aktualisiert, um Wartungs- und Sicherheitsverbesserungen einzubinden.

### Wichtige Informationen

Wir empfehlen, alle HIN Gateway-Installationen auf v1.1.8 zu aktualisieren, damit die neuesten Sicherheitspatches angewendet werden.

Das Update kann direkt über das HIN Gateway Dashboard durchgeführt werden. Ein manueller Download des VM-Images ist nicht erforderlich.

## v1.1.7

*Veröffentlicht am 14. Oktober 2026.*

### Neuerungen und Verbesserungen

- Ausgehende Relays können sich jetzt pro Domain mit Benutzername und Passwort authentifizieren.
- Eingehende Relays können sich jetzt pro Domain mit Benutzername und Passwort authentifizieren.
- Outlook-Vertraulichkeitskennzeichnung: E-Mails, die im Feld für Microsoft-Vertraulichkeitsbezeichnungen als vertraulich markiert sind, werden jetzt über HIN Mail verschlüsselt an Nicht-HIN-Mitglieder zugestellt.
- Zeitsynchronisierung: HIN Gateway verwendet jetzt NTP, um seine Uhr mit vertrauenswürdigen Zeitservern synchron zu halten. NTP kann im Dashboard konfiguriert werden.
- Log-Weiterleitung: Logs können jetzt mit einem API-Token an Loki gesendet werden.
- Migration von v0.5.x: Ein Migrationsskript exportiert den S/MIME-Schlüssel und das Zertifikat beim Wechsel von v0.5.x auf v0.6.x oder höher.
- Netzwerk-Standardwerte: Der Standard-DNS-Server ist jetzt 8.8.8.8 (bisher 1.1.1.1). Der DNS-Server kann während der Konfiguration geändert werden.

### Fehlerbehebungen

- Wiederholte Neustarts (bis zu drei hintereinander) nach einer Änderung der Netzwerkeinstellungen behoben.
- Fehler beim Onboarding behoben, wenn der Zertifikatsimport startete, bevor die Synchronisierung des Iris Agent abgeschlossen war.
- Domains werden beim Hinzufügen jetzt von Leerzeichen bereinigt und in Kleinbuchstaben umgewandelt.
- Bestätigungsmeldung nach dem Aktualisieren eines Peers korrigiert.
- Die Benachrichtigung über eine neue Version ist jetzt in alle unterstützten Sprachen übersetzt.

## v0.6.2

*Veröffentlicht am 24. September 2026.*

Dieses Hotfix-Release stärkt die Sicherheit von HIN Gateway, korrigiert die Stalwart-Version und deaktiviert die Spam-Filterung.

### Neuerungen und Verbesserungen

- Enthält Stalwart v0.16.23, das mit dem aktuellen Regelsatz für den Spamfilter funktioniert.
- Der Spam-Regelsatz und der SpamFilter sind deaktiviert, damit ein Upstream-Release des Regelsatzes eine fixierte Version nicht beschädigen kann.

### Fehlerbehebungen

- Behandlung des Spamfilters im Provisionierungsskript angepasst und Fehlerprotokollierung verbessert.
- Stalwart-Image auf Version v0.16.23 aktualisiert und eine Funktion zum Entfernen von DNSBL-Servern hinzugefügt.

## v0.6.1

*Veröffentlicht am 4. September 2026.*

Dieses Wartungsrelease stärkt die Sicherheit von HIN Gateway, korrigiert die Verarbeitung von E-Mail-Headern und verbessert die Anleitungen für Updates und Migrationen.

### Neuerungen und Verbesserungen

- **Sicherheit:** Der externe Zugriff auf interne Service-Ports wurde eingeschränkt, Authentifizierungseinstellungen und Berechtigungen wurden verschärft.
- **Updates und Rollback:** Anleitungen zum Aktualisieren von HIN Gateway und zur Rückkehr zu einer früheren Version wurden hinzugefügt, verfügbar auf Englisch, Deutsch, Französisch und Italienisch.
- **Migrationsanleitung:** Die E-Mail-Prüfungen vor und nach der Migration wurden aktualisiert und die Multi-Domain-Anleitung wurde übersetzt.

### Fehlerbehebungen

- Verarbeitung HIN-spezifischer E-Mail-Header korrigiert.
- Das fehlende VMware-Datenträger-Image wurde zu den Downloads von v0.6.0 hinzugefügt.

## v0.6.0

*Veröffentlicht am 31. August 2026.*

Dieses Release bringt Unterstützung für Multi-Domain-Migrationen, Relay-Konfiguration auf Domain-Ebene, E-Mail-Authentifizierung (etwa DKIM und ARC) sowie Verbesserungen bei Installation, Sicherheit und Stabilität.

### Neuerungen und Verbesserungen

- **Multi-Domain-Setups:** Mehrere Domains können jetzt auf einem einzelnen HIN Gateway konfiguriert oder dorthin migriert werden. Die aktualisierte Anleitung deckt vollständige und schrittweise Migrationen ab, einschließlich Rollback-Szenarien.
- **Domain-basierte Konfiguration:** Die Relay-Konfiguration ist jetzt pro Domain verfügbar.
- **E-Mail-Authentifizierung:** DKIM- und ARC-Signierung sowie DKIM-, ARC-, SPF- und DMARC-Prüfung können jetzt pro Domain konfiguriert werden. Die erforderlichen DNS-Einträge werden direkt im HIN Gateway angezeigt.
- **Installation und Migration:** Die aktualisierten Anleitungen umfassen jetzt Neuinstallationen, Single-Domain- und Multi-Domain-Migrationen, Exchange-Integration, Mail-Routing, Netzwerk und TLS-Tests.
- **Appliance-Migration:** Für den Umzug einer bestehenden Docker-Compose-Installation auf die Image-basierte HIN Gateway Appliance steht ein dokumentiertes Verfahren zur Verfügung.
- **Backup und Wiederherstellung:** Persistente Daten liegen jetzt an einem einheitlichen Ort. Die Wiederherstellung ist sicherer und es erscheinen Warnungen, wenn sich die Versionen von Backup und Ziel unterscheiden.
- **Diagnose und Sicherheit:** Health-Checks, Protokollierung und die Erfassung von Diagnosedaten wurden verbessert. Installations- und Wiederherstellungsskripte schützen Zugangsdaten und Backup-Daten jetzt besser.

### Fehlerbehebungen

- Erstinitialisierung der Vault- und WireGuard-Einstellungen verbessert.
- Start der Dienste auf langsameren virtuellen Maschinen verbessert.
- Sonderfälle bei Backup- und Wiederherstellungsvorgängen behoben.
- Ungenaue Health-Check-Ergebnisse und fehlerhafte Konfigurations-Fallbacks behoben.

### Wichtige Informationen zu Appliance-Migrationen

Folgen Sie beim Umzug einer bestehenden Docker-Compose-Installation auf die Image-basierte Appliance der entsprechenden Migrationsanleitung. Beim Wiederherstellen eines Backups werden alle Daten auf der Ziel-Appliance ersetzt. Ändert sich deren öffentliche IP-Adresse, muss HIN die zentrale WireGuard-Registrierung aktualisieren.

## v0.5.3

*Veröffentlicht am 29. Juli 2026. Hotfix angewendet am 5. August 2026.*

Dieses Release verbessert die E-Mail-Zustellung, die Zertifikatsverwaltung, das Dashboard und die Fehlerbehebung. An SEAL gibt es keine Änderungen.

### Hotfix, 5. August 2026

Im Zertifikatsimport wurde ein Problem behoben, bei dem die Domain nicht korrekt mit dem zugehörigen HIN Gateway Peer verknüpft wurde.

Der Fix wurde auf die zentralen Dienste angewendet. Lokale Installationen auf virtuellen Maschinen waren nicht betroffen und benötigten kein Update.

### Neuerungen und Verbesserungen

- Für Absender und Empfänger können jetzt getrennte Relays konfiguriert werden.
- E-Mails an Empfänger außerhalb des HIN-Netzwerks können über das konfigurierte SMTP-Relay gesendet werden.
- Das bisherige stündliche Limit für die E-Mail-Verarbeitung wurde aufgehoben.
- Die Zuordnung von Absendern und Empfängern bei ein- und ausgehenden E-Mails wurde verbessert.
- Vor der Ausstellung eines S/MIME-Zertifikats wird jetzt die Inhaberschaft der Domain geprüft.
- Peer-Zertifikate können jetzt durchsucht und sortiert werden.
- TLS-Zertifikate können direkt im Dashboard erzeugt werden.
- Die Peer-Übersicht hat eine Suche und eine Seitennavigation erhalten.
- Die Suche in Logs ist jetzt einfacher.
- Wenn der private Schlüssel nicht importiert wurde, wird eine Warnung angezeigt.
- Fehlermeldungen und Diagnoseinformationen wurden verbessert.

### Fehlerbehebungen

- Auswahl des Zertifikats beim Senden verschlüsselter E-Mails verbessert.
- Verarbeitung verschlüsselter Nachrichten, die mit widerrufenen oder nicht vertrauenswürdigen Zertifikaten signiert sind, korrigiert.
- Problem mit Session-Refresh-Tokens behoben.
- Mehrere Fehler in den Formularen für Einrichtung und Domain-Verwaltung behoben.
- Auswahl der Ländervorwahl und Feldvalidierung korrigiert.
- Problem beim erneuten Erzeugen eines Aktivierungscodes behoben.
- Verarbeitung bestimmter S/MIME-Signaturinformationen korrigiert.
- Fehlende Verbindungsinformationen in den Zustellprotokollen des Tunnels ergänzt.
- Die Netzwerkeinstellungen werden nach einer Änderung der IP-Adresse der virtuellen Maschine jetzt korrekt zurückgesetzt.

## v0.5.1

Unser erstes Release.
