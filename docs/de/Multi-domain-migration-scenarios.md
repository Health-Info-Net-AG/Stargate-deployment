# Szenario für die Migration mehrerer Domains

*MGW → HIN Gateway – Architektur des E-Mail-Flusses, schrittweiser Umzug und Rollback-Plan*

## Phase 1 Start – Ausgangslage (alle Domains auf MGW)

**Ausgangszustand**

- Alle Domains werden über das **MGW** weitergeleitet. Beispiel: domain1.ch, domain2.ch, domain3.ch, un-domain1.ch, un-domain2.ch
- Vorbereitungen für die Inbetriebnahme des HIN Gateways – noch kein Live-Verkehr
- DNS-MX-/SPF-Einträge werden weiterhin auf **Public IP A** (MGW) aufgelöst – dies gilt für den Fall, dass das MGW der nach aussen gerichtete Datenverkehr oder der letzte MTA ist

!!! info "Checkliste vor der Migration"
    - Baseline: aktuelle MGW-Kapazität und E-Mail-Verlaufsprotokolle
    - Verbindung von Stargate Lab zu Online Protect / Exchange Online / dem lokalen E-Mail-Server überprüfen
    - Beteiligte über Migrationszeitplan und Kommunikationsplan informieren
    - Dokumentation zu Firewall und Ports vor der Bereitstellung der öffentlichen IP B (Phase 2, Schritt 1) überprüfen

 <br> ![Start-Baseline](assets/multi-domain-scenario/Phase1-start-baseline.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Phase 2 Migration – schrittweise, eine Domain nach der anderen

**Migrationsschritte**

1. **Einrichtung** des HIN&nbsp;Gateways – `Public IP B` zuweisen und Firewall-Regeln anpassen (die erforderlichen Ports sind der Netzwerkdokumentation zu entnehmen)
2. **Erstellen Sie zwei Konnektoren** in Exchange Online – einen für eingehenden und einen für ausgehenden Datenverkehr –, die auf Stargate verweisen
3. **Fügen Sie eine E-Mail-Fluss-Regel hinzu,** die nach Domain weiterleitet: domain1.ch → HIN&nbsp;Gateway, alle übrigen Domains bleiben auf dem MGW
4. **Schrittweise wiederholen** – jeweils eine weitere Domain umstellen, bis alle Domains auf dem HIN&nbsp;Gateway laufen

!!! danger "Rollback (pro Domain)"
    - E-Mail-Fluss-Regel der betroffenen Domain wieder auf das MGW richten
    - Stargate-Konnektoren für den nächsten Versuch belassen
    - Chronologisches **Änderungsprotokoll** über jede Änderung an Konnektoren und Regeln führen – beim Rollback muss der Prozess in umgekehrter Reihenfolge wiederholt werden

!!! warning "Achten Sie auf kundenspezifische Header"
    Einige Domains nutzen benutzerdefinierte X-Header (Routing, Anti-Spam-Whitelists, Compliance-Tags). Vergewissern Sie sich, dass die Stargate-Konnektoren diese Header beibehalten bzw. replizieren, bevor Sie eine Domain umstellen – fehlende Header können zu Fehlweiterleitungen oder abgelehnten E-Mails führen.

![Phase 2 Migration - gradual, domain-by-domain](assets/multi-domain-scenario/Phase2-migration-domain-by-domain.png)

## Phase 3 Abschluss – vollständige Migration zum HIN&nbsp;Gateway

!!! success "Endzustand"
    - Alle Domains werden nun über das HIN&nbsp;Gateway geleitet
    - **MGW** überträgt keinen Produktionsverkehr
    - DNS/SPF verweisen nun auf **Public IP B** (für den Fall, dass das HIN&nbsp;Gateway der nach aussen gerichtete Verkehr oder der letzte MTA ist)

!!! note "Checkliste für die Bereinigung"
    - Alte MGW-Konnektoren und E-Mail-Fluss-Regeln entfernen
    - MGW-VM ausser Betrieb nehmen, sobald die Überwachung bestätigt, dass kein Datenverkehr mehr vorhanden ist und der E-Mail-Fluss ordnungsgemäss funktioniert
    - **Public IP A** freigeben, falls sie nicht mehr benötigt wird
    - Runbooks und DNS-Dokumentation aktualisieren

![Phase 3 Final - fully migrated to HIN Gateway](assets/multi-domain-scenario/Phase3-final-fully-migrated.png)

## Empfohlener Migrationsansatz nach Anzahl der Domains

!!! tip "Kunden mit 3 oder weniger Domains"
    - HIN empfiehlt, alle Domains auf einmal zu migrieren.
    - HIN unterstützt den Kunden bei der erfolgreichen Migration der ersten Domain.
    - Sobald die erste Domain erfolgreich migriert wurde, kann der Kunde die übrigen Domains eigenständig migrieren.
    - Dieser Ansatz hält die Migration einfach und vermeidet die Notwendigkeit einer parallelen Umgebung.

!!! note "Kunden mit mehr als 3 Domains"
    - HIN empfiehlt, eine parallele Umgebung neben dem bestehenden MGW einzurichten.
    - Die Domains können anschliessend schrittweise in die neue Umgebung migriert werden.
    - HIN unterstützt den Kunden bei der erfolgreichen Migration der ersten Domain.
    - Nach der ersten erfolgreichen Migration kann der Kunde entscheiden, wie und wann die übrigen Domains in die neue Umgebung verschoben werden.

---

!!! warning
    Überprüfen Sie vor der Durchführung jeglicher Installationsschritte die genauen Firewall-Ports und Konnektoren-Einstellungen anhand der aktuellen Netzwerkdokumentation.

!!! note
    Beachten Sie die spezifischen Anmerkungen zur Migration mehrerer Domains im [Installationshandbuch für Domains](Installation-guide.md).
