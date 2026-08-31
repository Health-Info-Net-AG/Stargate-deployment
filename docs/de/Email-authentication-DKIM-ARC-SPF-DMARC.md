# E-Mail-Authentifizierung (DKIM / ARC / SPF / DMARC)

**Modul:** HIN Mail Gateway -> Domains -> *[Domain]* -> Email authentication
**Gilt für:** Domain-Administratoren, die das ausgehende Signieren und die eingehende Verifizierung für eine Mail-Domain konfigurieren

---

Der Bereich **Email authentication** steuert, wie die Echtheit von E-Mails nachgewiesen wird und wie streng deren Echtheit bei eingehender Mail geprüft wird, also die DKIM-/ARC-/SPF-/DMARC-Verifizierung. Außerdem werden hier die DNS-TXT-Einträge erzeugt, die veröffentlicht werden müssen, damit externe Mailserver die Mail Ihrer Domain verifizieren können.

Der Bereich erreichen Sie über:

```
Domains -> Domain auswählen -> Email authentication
```

Das Panel besteht aus fünf Unterabschnitten:

1. DKIM
2. ARC
3. SPF
4. DMARC
5. Zu veröffentlichende DNS-Einträge

Änderungen werden erst übernommen, nachdem Sie unten auf der Seite auf die Schaltfläche **Save** geklickt haben.

![Screenshot](assets/Email-authentication.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

---

### Was jedes Protokoll bewirkt

| Protokoll | Richtung | Zweck |
|---|---|---|
| **DKIM** (DomainKeys Identified Mail) | Ausgehende Signierung / Eingehende Verifizierung | Signiert ausgehende Nachrichten kryptografisch mit einem privaten Schlüssel, der einem öffentlich in DNS veröffentlichten Schlüssel zugeordnet ist, sodass Empfänger bestätigen können, dass die Nachricht während der Übertragung nicht verändert wurde und tatsächlich von dieser Domain stammt |
| **ARC** (Authenticated Received Chain) | Signierung der eingehenden Verifizierung für den nächsten Relay-Schritt | Bewahrt die ursprünglichen DKIM-/SPF-Authentifizierungsergebnisse, während eine Nachricht durch Zwischenstationen (z.B. Mailinglisten, Weiterleitungsdienste) läuft, die DKIM-Signaturen sonst zerstören würden |
| **SPF** (Sender Policy Framework) | Eingehende Verifizierung | Prüft anhand eines von der Absenderdomain veröffentlichten DNS-Eintrags, ob die IP-Adresse des sendenden Mailservers berechtigt ist, Mail für diese Domain zu versenden |
| **DMARC** (Domain-based Message Authentication, Reporting & Conformance) | Eingehende Verifizierung | Verknüpft die Ergebnisse von DKIM und SPF und teilt empfangenden Servern mit, wie zu verfahren ist |

Wenn DKIM und DMARC für **Ihre eigene Domain** korrekt eingerichtet sind, schützt das Ihre Zustellbarkeit und Ihre Marke vor Spoofing. Die **Verifizierungs**-Einstellungen (DKIM-, ARC-, SPF-, DMARC-Verifizierungs-Dropdowns) steuern dagegen, wie streng das Gateway diesen Signalen bei **eingehender** Mail von anderen Domains vertraut.

---

### DKIM

| Feld | Beschreibung |
|---|---|
| **Enable DKIM signing** | Wenn aktiv, signiert das Gateway alle ausgehende Mail dieser Domain mit dem konfigurierten privaten Schlüssel. Aktivieren Sie dies, bevor Sie den DKIM-DNS-Eintrag veröffentlichen |
| **Generate DKIM key** (Schaltfläche, oben rechts) | Erzeugt ein neues RSA-2048-Schlüsselpaar für diese Domain und füllt das Feld Private key (PEM) |
| **DKIM verification** | Steuert, wie streng eine E-Mail gegen den veröffentlichten DKIM-Eintrag des Absenders geprüft wird |
| **Selector** | Der DKIM-Selector (z.B. `s1`), der zum Veröffentlichen und Nachschlagen des öffentlichen Schlüssels unter `<selector>._domainkey.<domain>` verwendet wird. Ändern Sie dies nur, wenn Sie mehrere Schlüssel parallel benötigen (z.B. während einer Schlüsselrotation): jeder Selector benötigt seinen eigenen DNS-TXT-Eintrag |
| **Private key (PEM)** | Der private RSA-Schlüssel, mit dem ausgehende Mail signiert wird. Klicken Sie entweder auf **Generate DKIM key**, um einen zu erzeugen, oder fügen Sie Ihren eigenen privaten RSA-2048-Schlüssel im PEM-Format ein |

### So richten Sie DKIM für eine neue Domain ein
1. Klicken Sie auf **Generate DKIM key** (oder fügen Sie einen vorhandenen, extern verwalteten RSA-2048-PEM-Schlüssel ein)
2. Belassen Sie **Selector** auf dem Standardwert (`s1`), sofern es keinen Grund zur Änderung gibt
3. Setzen Sie **Enable DKIM signing** auf Active
4. Klicken Sie auf **Save**
5. Kopieren Sie den erzeugten `s1._domainkey.<domain>`-TXT-Eintrag aus dem Feld **DNS records to publish** (siehe §7) und tragen Sie ihn bei Ihrem DNS-Anbieter ein
6. Sobald sich der DNS-Eintrag verbreitet hat, trägt die von dieser Domain signierte Mail eine gültige DKIM-Signatur

### So rotieren Sie einen DKIM-Schlüssel
1. Klicken Sie neben Private key (PEM) auf **Replace key**
2. Erzeugen Sie einen neuen Schlüssel (oder fügen Sie einen neuen ein)
3. Veröffentlichen Sie den TXT-Eintrag des neuen Selectors im DNS *bevor* Sie ihn in Produktion speichern/aktivieren, um ein Zeitfenster zu vermeiden, in dem signierte Mail nicht verifiziert werden kann
4. Speichern Sie und entfernen Sie den DNS-Eintrag des alten Selectors, sobald Sie bestätigt haben, dass der neue Schlüssel korrekt signiert

---

### ARC

| Feld | Beschreibung |
|---|---|
| **ARC verification** (Dropdown) | Steuert, wie streng eingehende ARC-Ketten validiert werden |
| **Enable ARC signing** | Wenn aktiv, fügt das Gateway weitergeleiteter Mail ein ARC-Seal hinzu und bewahrt so die Authentifizierungsergebnisse, falls die Nachricht später über ein anderes System weitergeleitet wird |
| **Reuse DKIM key** (Umschalter) | Wenn aktiv, verwendet die ARC-Signierung denselben RSA-Schlüssel, der oben im DKIM-Bereich konfiguriert ist, statt einen separaten Schlüssel zu benötigen. Empfohlen, sofern Sie keinen besonderen Grund haben, die beiden Signaturen kryptografisch getrennt zu halten |

---

### SPF

| Feld | Beschreibung |
|---|---|
| **SPF verification** | Steuert, wie streng eingehende Mail gegen den veröffentlichten SPF-Eintrag der Absenderdomain geprüft wird |

> **Hinweis:** Dieses Panel steuert nur die *Verifizierung* eingehender SPF-Prüfungen. Es erzeugt keinen ausgehenden SPF-TXT-Eintrag für Ihre eigene Domain (in §7 "DNS records to publish" erscheint kein SPF-Eintrag). Wenn diese Domain Mail über ein externes Relay versendet (z.B. Microsoft 365, konfiguriert unter **Mail routing -> Outbound relay**), stellen Sie sicher, dass der `include:`-Mechanismus dieses Anbieters bereits unabhängig von diesem Gateway im eigenen SPF-Eintrag Ihrer Domain bei Ihrem DNS-Anbieter veröffentlicht ist.

---

### DMARC

| Feld | Beschreibung |
|---|---|
| **DMARC verification** | Steuert, wie streng eingehende Mail gegen die DMARC-Richtlinie des Absenders geprüft wird |


### Verifizierungswert


| UI-Bezeichnung | Wert | Verhalten |
|---|---|---|
| **Disabled** | `disable` | Wird überhaupt nicht geprüft. Mechanismus läuft nicht |
| **Optional** | `relaxed` | Wird verifiziert und im `Authentication-Results` **gemeldet**. Die Nachricht wird **immer angenommen**, ob bestanden oder nicht |
| **Required** | `strict` | Wird verifiziert und gemeldet, und die Nachricht wird bei einem Hard-Fail **abgelehnt**. Andernfalls wird sie angenommen |

Kurz gesagt: Disabled bedeutet, es wird nicht geprüft; Optional und Required prüfen beide und vermerken das Ergebnis. Der einzige Unterschied zwischen beiden ist die Durchsetzung: **Optional lehnt nie ab**, **Required lehnt bei einem Hard-Fail ab**.

Was als "Hard Failure" für Required gilt (pro Mechanismus):
- **DKIM**: Die Nachricht enthält Signaturen und *alle* schlagen fehl. Gar keine Signatur ergibt `none`, keinen Fehlschlag, also keine Ablehnung.
- **SPF**: Ein harter `-all`-Fehlschlag. SoftFail/neutral/none/temp-error werden gemeldet, führen aber nicht zur Ablehnung.
- **DMARC**: Weder DKIM noch SPF richtet sich aus, *und* es liegt ein tatsächliches Fail-Ergebnis vor. Kein veröffentlichter DMARC-Eintrag ergibt `none`, also keine Ablehnung.
- **ARC**: Die ARC-Kette schlägt bei der Validierung fehl. Keine Kette ergibt `none`, also keine Ablehnung.

Zwei wichtige Hinweise:
- **DKIM läuft intern immer**, weil DMARC es benötigt. Die DKIM-Einstellung steuert nur, ob ein `dkim=`-Ergebnis vermerkt wird und ob ein DKIM-Fehlschlag zur Ablehnung führen kann; sie ändert nie das DMARC-Ergebnis.
- Jeder Mechanismus ist unabhängig, sodass Sie z.B. **DMARC = Required** bei **DKIM/SPF = Optional** ausführen können: Schlechte Mail wird anhand des DMARC-Ergebnisses abgelehnt, und Sie erhalten trotzdem einzelne `dkim=`/`spf=`-Zeilen im Header zur besseren Nachvollziehbarkeit.


---

### Zu veröffentlichende DNS-Einträge

Dieser Bereich zeigt die exakten TXT-Einträge, die Sie beim DNS-Anbieter Ihrer Domain anlegen müssen, damit externe Mailserver Mail von dieser Domain verifizieren können. Die angezeigten Einträge werden automatisch anhand Ihres DKIM-Selectors und der DMARC-Richtlinie oben aktualisiert.

| Eintrag | Host | Typ | Wert |
|---|---|---|---|
| DKIM-Öffentlicher Schlüssel | `<selector>._domainkey.<domain>` (z.B. `s1._domainkey.vrgnservices.eu`) | TXT | `v=DKIM1; k=rsa; p=<public key>` |
| DMARC-Richtlinie | `_dmarc.<domain>` (z.B. `_dmarc.vrgnservices.eu`) | TXT | `v=DMARC1; p=<policy>` (z.B. `p=none`) |

Verwenden Sie das Kopiersymbol oben rechts in jedem Eintragsfeld, um dessen exakten Wert zu kopieren. Fügen Sie jeden Eintrag als neuen TXT-Eintrag bei Ihrem DNS-Registrar/-Anbieter ein, indem Sie **Host/Name** und **Value** wie angezeigt verwenden.

> DNS-Änderungen können je nach TTL-Einstellung Ihres Anbieters zwischen wenigen Minuten und 48 Stunden zur Verbreitung benötigen. Die DKIM-/DMARC-Durchsetzung sollte erst verschärft werden (z.B. Signieren aktivieren oder die DMARC-Richtlinie über `none` hinaus verschärfen), nachdem Sie bestätigt haben, dass sich die Einträge verbreitet haben und korrekt aufgelöst werden.

---

## Änderungen speichern

Keine der oben genannten Einstellungen wird wirksam, bevor Sie unten auf der Seite auf die orangefarbene Schaltfläche **Save** klicken. Save übernimmt alle Änderungen an DKIM, ARC, SPF und DMARC gemeinsam; es gibt kein Speichern pro Abschnitt.

---

## Fehlerbehebung

| Symptom | Wahrscheinliche Ursache |
|---|---|
| Ausgehende Mail besteht DKIM bei empfangenden Servern nicht | DKIM-Signierung aktiviert, aber der DNS-TXT-Eintrag noch nicht veröffentlicht/verbreitet, oder Selector-Mismatch zwischen Gateway und DNS. |
| ARC-Seal fehlt bei weitergeleiteter Mail | **Enable ARC signing** ist deaktiviert, oder **Reuse DKIM key** ist deaktiviert, ohne dass ein separater ARC-Schlüssel konfiguriert ist. |
| Der private DKIM-Schlüssel kann nicht eingesehen werden, um ihn andernorts zu kopieren | So gewollt: Nach dem Speichern ist der Schlüssel maskiert (`<hidden>`) und kann nicht erneut angezeigt werden. Verwenden Sie **Replace key**, um einen neuen auszustellen, wenn Sie ihn auf ein System übertragen müssen, das noch keine Kopie besitzt. |
| Legitime Mail wird nach einer Änderung der DMARC-Richtlinie plötzlich unter Quarantäne gestellt/abgelehnt | Eine legitime Versandquelle ist noch nicht DKIM-/SPF-ausgerichtet. Setzen Sie die Richtlinie auf `none` zurück, identifizieren Sie die fehlerhafte Quelle, beheben Sie die Ausrichtung und verschärfen Sie die Richtlinie danach erneut. |
