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
