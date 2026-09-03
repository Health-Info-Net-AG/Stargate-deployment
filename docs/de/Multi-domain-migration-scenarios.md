# Szenario für die Migration mehrerer Domains

*MGW → HIN Gateway – Architektur des E-Mail-Flusses, schrittweiser Umzug und Rollback-Plan*

## Phase 1 Start – Ausgangslage (alle Domains auf MGW)

**Ausgangszustand**

- Alle Domains werden über das **MGW** weitergeleitet. Beispiel: domain1.ch, domain2.ch, domain3.ch, un-domain1.ch, un-domain2.ch
- Vorbereitungen für die Inbetriebnahme des HIN Gateways – noch kein Live-Verkehr
- DNS-MX-/SPF-Einträge werden weiterhin auf **Public IP A** (MGW) aufgelöst – dies gilt für den Fall, dass das MGW der nach aussen gerichtete Datenverkehr oder der letzte MTA ist

!!! info "Checkliste vor der Migration"
    - Baseline: aktuelle MGW-Kapazität und E-Mail-Verlaufsprotokolle
    - Verbindung von HIN Gateway Lab zu Online Protect / Exchange Online / dem lokalen E-Mail-Server überprüfen
    - Beteiligte über Migrationszeitplan und Kommunikationsplan informieren
    - Dokumentation zu Firewall und Ports vor der Bereitstellung der öffentlichen IP B (Phase 2, Schritt 1) überprüfen

 <br> ![Start-Baseline](assets/multi-domain-scenario/Phase1-start-baseline.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Phase 2 Migration – schrittweise, eine Domain nach der anderen

**Migrationsschritte**

1. **Einrichtung** des HIN&nbsp;Gateways – `Public IP B` zuweisen und Firewall-Regeln anpassen (die erforderlichen Ports sind der Netzwerkdokumentation zu entnehmen)
2. **Erstellen Sie zwei Konnektoren** in Exchange Online – einen für eingehenden und einen für ausgehenden Datenverkehr –, die auf HIN Gateway verweisen
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

## Vergleich von Migrationsstrategien

!!! tip "Empfohlen – alle Domains auf einmal umziehen"
    - Keine zusätzliche Public IP erforderlich
    - Keine vorübergehenden Änderungen an Konnektoren oder E-Mail-Fluss-Regeln
    - Einfaches Rollback: HIN Gateway ausschalten, alte MGW-VM wieder einschalten
    - Kürzestes Umstellungsfenster – geringste Wahrscheinlichkeit von Konfigurationsabweichungen

!!! note "Alternative – schrittweise, eine Domain nach der anderen"
    - Geringere Auswirkungen pro Schritt – jeweils nur eine Domain ist gefährdet
    - Erfordert eine zweite Public IP sowie temporäre Aufteilungsregeln und Konnektoren
    - Kundenspezifische Header müssen pro Domain berücksichtigt werden
    - Für ein Rollback muss die genaue Änderungssequenz in umgekehrter Reihenfolge wiederholt werden

---

!!! warning
    Überprüfen Sie vor der Durchführung jeglicher Installationsschritte die genauen Firewall-Ports und Konnektoren-Einstellungen anhand der aktuellen Netzwerkdokumentation.

!!! note
    Beachten Sie die spezifischen Anmerkungen zur Migration mehrerer Domains im [Installationshandbuch für Domains](Installation-guide.md).
