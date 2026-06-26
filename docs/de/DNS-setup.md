# DNS-Einrichtung für Stargate

Dieser Leitfaden deckt alle DNS-Einträge ab, die für eine funktionierende Stargate-Bereitstellung erforderlich sind. Konfigurieren Sie diese Einträge **vor** der Installation von Stargate oder unmittelbar danach, je nach Eintragstyp.

In diesem Leitfaden:

- `<STARGATE_IP>` – die öffentliche statische IP-Adresse Ihres Stargate-Servers (`SERVER_STATIC_IP` in `customer-config.sh`)
- `<MAIL_HOSTNAME>` – der FQDN des Stargate-Relays (z.B. `mail.example.ch`; konfiguriert über die `/mail`-Seite des Dashboards)
- `<YOUR_DOMAIN>` – Ihre Mail-Domain (z.B. `example.ch`; konfiguriert über die `/mail`-Seite des Dashboards)

---

## Eintragsübersicht

| Eintrag | Name | Wert | Erforderlich | Wann |
|--------|------|-------|----------|------|
| [A](#a-eintrag) | `<MAIL_HOSTNAME>` | `<STARGATE_IP>` | Ja | Vor der Installation |
| [MX](#mx-eintrage) | `<YOUR_DOMAIN>` | `<MAIL_HOSTNAME>` (Priorität 15) | Ja | Vor der Installation |
| [SPF](#spf-eintrag) | `<YOUR_DOMAIN>` | `ip4:<STARGATE_IP>` zum TXT hinzufügen | Ja | Vor der Installation |
| [PTR](#ptr-reverse-dns) | `<STARGATE_IP>` | `<MAIL_HOSTNAME>` | Empfohlen | Vor der Installation |
| [DMARC](#dmarc-eintrag) | `_dmarc.<YOUR_DOMAIN>` | `v=DMARC1; p=none; ...` | Empfohlen | Nach der Installation |
| [DKIM](#dkim-eintrage) | `selector._domainkey.<YOUR_DOMAIN>` | Von M365/Anbieter | Empfohlen | Nach der Installation |

Für Multi-Domain-Bereitstellungen wiederholen Sie die MX-, SPF-, DMARC- und DKIM-Einträge für jede in `MAIL_DOMAINS` aufgeführte Domain.

---

## Erforderliche Einträge

### A-Eintrag

Erstellen Sie einen A-Eintrag, der den Stargate-Mail-Hostnamen auf die öffentliche IP des Servers verweist:

```plain
<MAIL_HOSTNAME>.    A    <STARGATE_IP>
```

Beispiel:

```plain
mail.example.ch.    A    128.140.117.200
```

Wenn Stargate eine IPv6-Adresse hat, fügen Sie auch einen AAAA-Eintrag hinzu:

```plain
mail.example.ch.    AAAA    2a01:4f8:c012:1234::1
```

**Warum**: Externe Mailserver verbinden sich mit diesem Hostnamen, um E-Mails zuzustellen. Ohne den A-Eintrag ist der unten stehende MX-Eintrag nicht auflösbar.

### MX-Einträge

Fügen Sie einen MX-Eintrag für Stargate mit einer **höheren Priorität** (niedrigere Zahl) als den vorhandenen Mailserver hinzu. Dies stellt sicher, dass eingehende E-Mails zuerst Stargate zur S/MIME-Verarbeitung erreichen, bevor sie an Exchange oder Ihre Mail-Plattform weitergeleitet werden.

```plain
<YOUR_DOMAIN>.    MX    15    <MAIL_HOSTNAME>.
```

Behalten Sie den vorhandenen Exchange/Mailserver-MX-Eintrag mit einer niedrigeren Priorität (höhere Zahl):

```plain
<YOUR_DOMAIN>.    MX    20    <YOUR_DOMAIN>.mail.protection.outlook.com.
```

Beispiel (vollständiger MX-Satz):

```plain
example.ch.    MX    15    mail.example.ch.
example.ch.    MX    20    example-ch.mail.protection.outlook.com.
```

!!! info
    Die niedrigere MX-Zahl bedeutet höhere Priorität. Stargate mit Priorität 15 empfängt E-Mails vor Exchange Online mit Priorität 20.

**Warum**: Stargate fängt eingehende E-Mails ab, verarbeitet S/MIME und leitet sie dann an den nächsten MX (Exchange) weiter. Der zweite MX-Eintrag wird auch von Stalwart verwendet, um zu wissen, wohin verarbeitete E-Mails weitergeleitet werden sollen.

**Wichtig**: Wenn Stargate der **einzige** MX-Eintrag für eine Domain ist, filtert Stalwart seinen eigenen Hostnamen heraus und hat kein Zustellziel. Behalten Sie immer einen zweiten MX bei, der auf Ihren tatsächlichen Mailserver verweist.

### SPF-Eintrag

Fügen Sie die Stargate-Server-IP **und die HIN-Sealer-IP** zum SPF-Eintrag Ihrer Domain hinzu, damit über Stargate weitergeleitete ausgehende E-Mails die SPF-Prüfungen beim Empfänger bestehen.

**Wenn Sie M365 / Exchange Online verwenden:**

```plain
<YOUR_DOMAIN>.    TXT    "v=spf1 ip4:<STARGATE_IP> ip4:<HIN_SEALER_IP> include:spf.protection.outlook.com -all"
```

**Wenn Sie M365 / Google Workspace nicht verwenden:**

```plain
<YOUR_DOMAIN>.    TXT    "v=spf1 ip4:<STARGATE_IP> ip4:<HIN_SEALER_IP> -all"
```

Beispiel:

```plain
example.ch.    TXT    "v=spf1 ip4:128.140.117.200 ip4:193.247.208.66 include:spf.protection.outlook.com -all"
```

!!! question "Warum die HIN-Sealer-IP erforderlich ist"
    Wenn Stargate eine SEAL'd (verschlüsselte) Nachricht für einen Nicht-HIN-Empfänger erzeugt, ist der letzte ausgehende Hop zum Empfänger der **HIN-Sealer**, nicht Ihr Stargate oder M365. Ohne die Sealer-IP in Ihrem SPF-Eintrag wird jede SEAL'd ausgehende Nachricht beim Empfänger die SPF-Prüfung nicht bestehen, und – da es keine DKIM-Signatur auf der SEAL'd-Nutzlast gibt – wird auch DMARC fehlschlagen. Strenge DMARC-Empfänger (Gmail, Outlook mit `p=reject`-Durchsetzung, Proofpoint) werden die Nachricht ablehnen oder im Spam-Ordner ablegen.

    Sealer-IPs, die in SPF aufgenommen werden müssen:

    | Umgebung | Sealer-Host | In SPF aufzunehmende IP |
    |-------------|-------------|------------------|
    | HIN Test (alpha/beta) | `mx3.hintest.ch` | `193.247.208.66` |
    | HIN Produktion | TBD – vor dem Produktivstart die kanonische Liste von HIN anfordern | TBD |

    Wenn HIN mehr als einen Sealer-Host veröffentlicht (z.B. `mx1`, `mx2`, `mx3`), nehmen Sie **alle** deren IPs auf. Lösen Sie sie mit `dig +short mx hintest.ch` auf, gefolgt von `dig +short A <jeder-mx>`. Bis Sie die vollständige Liste haben, belassen Sie die SPF-Richtlinie auf `~all` (Softfail) anstelle von `-all` (Hardfail), damit legitime SEAL-E-Mails über eine nicht aufgeführte Sealer-IP nicht sofort abgewiesen werden.

!!! warning "SPF-Lookup-Limit"
    Die gesamte `include:`-Kette in einem SPF-Eintrag darf **10 DNS-Lookups** nicht überschreiten. Das Hinzufügen von `ip4:`-Einträgen zählt nicht zu diesem Limit. Überprüfen Sie Ihre Anzahl mit [MXToolbox SPF-Lookup](https://mxtoolbox.com/spf.aspx).

**Wie Stargate SPF verwendet**: Der mtaconf-Daemon löst den SPF-Eintrag jeder Domain auf, um die Liste der IPs, die ohne Authentifizierung über Stargate weiterleiten dürfen, automatisch zu befüllen. So werden die ausgehenden IPs von Microsoft 365 automatisch auf die Whitelist gesetzt – sie erscheinen in der `include:spf.protection.outlook.com`-Kette.

---

## Empfohlene Einträge

### PTR (Reverse DNS)

Konfigurieren Sie den Reverse-DNS (PTR)-Eintrag für die Stargate-IP so, dass er mit `<MAIL_HOSTNAME>` übereinstimmt:

```plain
200.117.140.128.in-addr.arpa.    PTR    mail.example.ch.
```

Dies wird bei Ihrem **Hosting-Anbieter** (Hetzner, Azure, AWS usw.) konfiguriert, nicht im DNS-Panel Ihres Domain-Registrars. Die meisten Anbieter haben eine Einstellung "Reverse DNS" oder "rDNS" in der Server/IP-Verwaltungsseite.

**Warum**: Viele empfangende Mailserver (einschließlich Gmail und Outlook) prüfen, ob der PTR-Eintrag der verbindenden IP zu einem Hostnamen aufgelöst wird und ob dieser Hostname wiederum auf dieselbe IP aufgelöst wird (forward-confirmed reverse DNS / FCrDNS). Ein fehlender oder nicht übereinstimmender PTR ist ein starkes Spam-Signal und kann zu Zustellfehlern führen.

### DMARC-Eintrag

Veröffentlichen Sie eine DMARC-Richtlinie für jede sendende Domain. Beginnen Sie mit `p=none` (nur Überwachung), dann verschärfen Sie nach Bestätigung der Ausrichtung:

```plain
_dmarc.<YOUR_DOMAIN>.    TXT    "v=DMARC1; p=none; rua=mailto:postmaster@<YOUR_DOMAIN>"
```

Beispiel:

```plain
_dmarc.example.ch.    TXT    "v=DMARC1; p=none; rua=mailto:postmaster@example.ch"
```

Sobald die DMARC-Aggregatberichte bestätigen, dass SPF und/oder DKIM durchgängig erfolgreich sind, verschärfen Sie die Richtlinie:

1. `p=none` – nur Überwachung (hier beginnen)
2. `p=quarantine` – verdächtige E-Mails gehen in den Spam-Ordner
3. `p=reject` – nicht autorisierte E-Mails werden abgewiesen

**Warum**: DMARC verbindet SPF und DKIM und teilt Empfängern mit, was mit E-Mails geschehen soll, die beide Prüfungen nicht bestehen. Selbst `p=none` reicht aus, um die Outlook-Warnung "Wir können diesen Absender nicht überprüfen" zu beseitigen, solange SPF erfolgreich ist.

Überprüfen Sie Ihren DMARC-Eintrag: [MXToolbox DMARC-Lookup](https://mxtoolbox.com/dmarc.aspx)

### DKIM-Einträge

Wenn Ihre Domain eine akzeptierte Domain in M365 oder Google Workspace ist, aktivieren Sie die DKIM-Signatur im Admin-Center und veröffentlichen Sie die CNAME-Einträge wie angewiesen:

**M365-Beispiel:**

```plain
selector1._domainkey.<YOUR_DOMAIN>.    CNAME    selector1-<YOUR_DOMAIN_DASHED>._domainkey.<TENANT>.onmicrosoft.com.
selector2._domainkey.<YOUR_DOMAIN>.    CNAME    selector2-<YOUR_DOMAIN_DASHED>._domainkey.<TENANT>.onmicrosoft.com.
```

!!! note
    Das Veröffentlichen der CNAME-Einträge allein reicht nicht aus – die DKIM-Signatur muss auch im M365-Admin-Center **aktiviert** werden (Defender-Portal > E-Mail-Authentifizierung > DKIM).

**Warum**: DKIM beweist, dass der Nachrichtentext während des Transports nicht manipuliert wurde. In Kombination mit SPF und DMARC bietet es die stärkste Sender-Authentifizierung.

---

## Multi-Domain-Setup

Für Bereitstellungen, die mehrere Mail-Domains verwalten (konfiguriert über die `/mail`-Seite des Dashboards), benötigt jede Domain ihren eigenen Satz von DNS-Einträgen.

### Einträge pro Domain

Für jede konfigurierte Domain:

| Eintrag | Erforderlich |
|--------|----------|
| MX, der auf `<MAIL_HOSTNAME>` verweist | Ja |
| SPF mit `ip4:<STARGATE_IP>` | Ja |
| DMARC (`_dmarc.<domain>`) | Empfohlen |
| DKIM (von Ihrem Mail-Anbieter) | Empfohlen |

Der A-Eintrag und der PTR-Eintrag werden gemeinsam genutzt (sie verweisen auf den Stargate-Server, nicht auf einzelne Domains).

### Mail-Routing pro Domain

Die MX-Einträge jeder Domain sagen Stargate, wohin verarbeitete E-Mails zugestellt werden sollen. Wenn verschiedene Domains unterschiedliche Exchange-Server verwenden:

```plain
domain1.ch    MX    15    mail.domain1.ch.
domain1.ch    MX    20    exchange1.domain1.ch.

domain2.ch    MX    15    mail.domain2.ch.
domain2.ch    MX    20    exchange2.domain2.ch.
```

Alternativ konfigurieren Sie explizite pro-Domain-Relay-Ziele über die `/mail`-Seite des Dashboards (Relay-Host-Feld pro Domain), um das MX-basierte Routing zu überschreiben.

---

## Überprüfung

Nach der Konfiguration aller Einträge überprüfen Sie diese:

```bash
# A-Eintrag
host <MAIL_HOSTNAME>
# Erwartet: <MAIL_HOSTNAME> has address <STARGATE_IP>

# MX-Einträge
host -t mx <YOUR_DOMAIN>
# Erwartet: Sowohl Stargate- als auch Exchange-MX-Einträge aufgelistet

# SPF-Eintrag
host -t txt <YOUR_DOMAIN> | grep v=spf1
# Erwartet: SPF-Eintrag enthält ip4:<STARGATE_IP>

# PTR (Reverse DNS)
host <STARGATE_IP>
# Erwartet: <STARGATE_IP> → <MAIL_HOSTNAME>

# Forward-confirmed reverse DNS (FCrDNS)
host $(host <STARGATE_IP> | awk '{print $NF}' | sed 's/\.$//')
# Erwartet: löst auf <STARGATE_IP> auf

# DMARC
host -t txt _dmarc.<YOUR_DOMAIN>
# Erwartet: v=DMARC1; p=...

# DKIM (M365)
host -t cname selector1._domainkey.<YOUR_DOMAIN>
# Erwartet: CNAME zu Ihrer Tenant-onmicrosoft.com
```

Beispielausgabe:

```shell
$ host mail.example.ch
mail.example.ch has address 128.140.117.200

$ host -t mx example.ch
example.ch mail is handled by 15 mail.example.ch.
example.ch mail is handled by 20 example-ch.mail.protection.outlook.com.

$ host -t txt example.ch | grep v=spf1
example.ch descriptive text "v=spf1 ip4:128.140.117.200 include:spf.protection.outlook.com -all"

$ host 128.140.117.200
200.117.140.128.in-addr.arpa domain name pointer mail.example.ch.

$ host -t txt _dmarc.example.ch
_dmarc.example.ch descriptive text "v=DMARC1; p=none; rua=mailto:postmaster@example.ch"
```

Online-Tools:

- [MXToolbox MX-Lookup](https://mxtoolbox.com/MXLookup.aspx)
- [MXToolbox SPF-Prüfung](https://mxtoolbox.com/spf.aspx) (beinhaltet Lookup-Zählung)
- [MXToolbox DMARC-Prüfung](https://mxtoolbox.com/dmarc.aspx)
- [Mail-Tester](https://www.mail-tester.com/) (senden Sie eine Test-E-Mail, um einen Zustellbarkeits-Score zu erhalten)

---

## Fehlerbehebung

### "Client host rejected: Access denied" (554 5.7.1)

Stalwart lehnt den sendenden Server ab, weil seine IP nicht in der erlaubten Relay-Liste ist. Dies bedeutet normalerweise:

- Der SPF-Eintrag für Ihre Domain enthält nicht den IP-Bereich des sendenden Servers
- Die Mail-Konfiguration wurde seit der SPF-Eintragsaktualisierung nicht neu geladen

Laden Sie die Mail-Konfiguration über die `/mail`-Seite des Dashboards neu (Konfiguration erneut übermitteln) oder starten Sie den Container neu: `docker compose restart stalwart`

### E-Mail als Spam markiert / "Absender kann nicht überprüft werden"

- SPF fehlt oder enthält nicht die Stargate-IP – fügen Sie `ip4:<STARGATE_IP>` zu Ihrem SPF-Eintrag hinzu
- DMARC ist nicht veröffentlicht – fügen Sie mindestens `v=DMARC1; p=none` hinzu
- PTR-Eintrag fehlt oder stimmt nicht überein – konfigurieren Sie Reverse DNS bei Ihrem Hosting-Anbieter
- DKIM ist in Ihrem M365/Anbieter-Mandanten nicht aktiviert

### MX-Lookup gibt nur Stargate zurück

Wenn Stargate der einzige MX für eine Domain ist, filtert Stalwart seinen eigenen Hostnamen heraus und hat kein Relay-Ziel. Fügen Sie einen zweiten MX-Eintrag hinzu, der auf Ihren Mailserver verweist:

```plain
example.ch.    MX    15    mail.example.ch.          ← Stargate (eingehend)
example.ch.    MX    20    example-ch.mail.protection.outlook.com.  ← Exchange (Relay-Ziel)
```

### SPF-Lookup-Limit überschritten (> 10)

Jedes `include:` im SPF-Eintrag löst zusätzliche DNS-Lookups aus. Die gesamte Kette muss unter 10 bleiben. Lösungen:

- Verwenden Sie `ip4:` / `ip6:`-Einträge anstelle von `include:`, wo möglich (sie zählen nicht)
- Flatten Sie verschachtelte Includes mit einem Tool wie [SPF Flattener](https://dmarcly.com/tools/spf-record-flattener)
- Entfernen Sie nicht verwendete `include:`-Einträge von alten Anbietern

### Port 25 wird vom Hosting-Anbieter blockiert

Einige Cloud-Anbieter (Azure, bestimmte Hetzner-Tarife) blockieren ausgehenden Port 25 standardmäßig. Überprüfen Sie dies bei Ihrem Anbieter und beantragen Sie eine Ausnahme. Dies betrifft sowohl die eingehende Zustellung (externe Server, die sich mit Ihrem Stargate verbinden) als auch das ausgehende Relay (Stargate, das an MX-Ziele zustellt).
