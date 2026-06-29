# Configurazione DNS per Stargate

Questa guida copre tutti i record DNS richiesti per un deployment funzionante di Stargate. Configurare questi record **prima** di installare Stargate o immediatamente dopo, a seconda del tipo di record.

In questa guida:

- `<STARGATE_IP>` - l'indirizzo IP pubblico statico del server Stargate (`SERVER_STATIC_IP` in `customer-config.sh`)
- `<MAIL_HOSTNAME>` - il FQDN del relay Stargate (es. `mail.example.ch`; configurato tramite la pagina `/mail` del dashboard)
- `<YOUR_DOMAIN>` - il dominio di posta (es. `example.ch`; configurato tramite la pagina `/mail` del dashboard)

---

## Riepilogo dei record

| Record | Nome | Valore | Richiesto | Quando |
|--------|------|-------|----------|------|
| [A](#record-a) | `<MAIL_HOSTNAME>` | `<STARGATE_IP>` | Sì | Prima dell'installazione |
| [MX](#record-mx) | `<YOUR_DOMAIN>` | `<MAIL_HOSTNAME>` (priorità 15) | Sì | Prima dell'installazione |
| [SPF](#record-spf) | `<YOUR_DOMAIN>` | `ip4:<STARGATE_IP>` aggiunto a TXT | Sì | Prima dell'installazione |
| [PTR](#ptr-dns-inverso) | `<STARGATE_IP>` | `<MAIL_HOSTNAME>` | Raccomandato | Prima dell'installazione |
| [DMARC](#record-dmarc) | `_dmarc.<YOUR_DOMAIN>` | `v=DMARC1; p=none; ...` | Raccomandato | Dopo l'installazione |
| [DKIM](#record-dkim) | `selector._domainkey.<YOUR_DOMAIN>` | Da M365/provider | Raccomandato | Dopo l'installazione |

Per deployment multi-dominio, ripetere i record MX, SPF, DMARC e DKIM per ogni dominio elencato in `MAIL_DOMAINS`.

---

## Record richiesti

### Record A

Creare un record A che punti il nome host di posta Stargate all'IP pubblico del server:

```plain
<MAIL_HOSTNAME>.    A    <STARGATE_IP>
```

Esempio:

```plain
mail.example.ch.    A    128.140.117.200
```

Se Stargate ha un indirizzo IPv6, aggiungere anche un record AAAA:

```plain
mail.example.ch.    AAAA    2a01:4f8:c012:1234::1
```

**Perché**: I server di posta esterni si connettono a questo nome host per consegnare le email. Senza il record A, il record MX sottostante non è risolvibile.

### Record MX

Aggiungere un record MX per Stargate con una **priorità più alta** (numero inferiore) rispetto al server di posta esistente. Ciò garantisce che le email in entrata raggiungano prima Stargate per l'elaborazione S/MIME prima di essere inoltrate a Exchange o alla piattaforma di posta.

```plain
<YOUR_DOMAIN>.    MX    15    <MAIL_HOSTNAME>.
```

Mantenere il record MX esistente di Exchange / server di posta con una priorità inferiore (numero superiore):

```plain
<YOUR_DOMAIN>.    MX    20    <YOUR_DOMAIN>.mail.protection.outlook.com.
```

Esempio (insieme MX completo):

```plain
example.ch.    MX    15    mail.example.ch.
example.ch.    MX    20    example-ch.mail.protection.outlook.com.
```

!!! info
    Il numero MX inferiore significa priorità più alta. Stargate con priorità 15 riceve le email prima di Exchange Online con priorità 20.

**Perché**: Stargate intercetta le email in entrata, elabora S/MIME, quindi le inoltra al successivo MX (Exchange). Il secondo record MX è utilizzato anche da Stalwart per sapere dove inoltrare le email elaborate.

**Importante**: Se Stargate è l'**unico** record MX per un dominio, Stalwart filtrerà il proprio nome host e non avrà alcuna destinazione di consegna. Mantenere sempre un secondo MX che punti al server di posta effettivo.

### Record SPF

Aggiungere l'IP del server Stargate **e l'IP del sigillatore HIN** al record SPF del dominio in modo che le email in uscita inoltrate attraverso di esso superino i controlli SPF presso il destinatario.

**Se si utilizza M365 / Exchange Online:**

```plain
<YOUR_DOMAIN>.    TXT    "v=spf1 ip4:<STARGATE_IP> ip4:<HIN_SEALER_IP> include:spf.protection.outlook.com -all"
```

**Se non si utilizza M365 / Google Workspace:**

```plain
<YOUR_DOMAIN>.    TXT    "v=spf1 ip4:<STARGATE_IP> ip4:<HIN_SEALER_IP> -all"
```

Esempio:

```plain
example.ch.    TXT    "v=spf1 ip4:128.140.117.200 ip4:193.247.208.66 include:spf.protection.outlook.com -all"
```

!!! question "Perché l'IP del sigillatore HIN è richiesto"
    Quando Stargate produce un messaggio SIGILLATO (crittografato) per un destinatario non HIN, l'ultimo salto in uscita verso il destinatario è il **sigillatore HIN**, non il vostro Stargate o M365. Senza l'IP del sigillatore nel record SPF, ogni messaggio in uscita SIGILLATO fallirà il controllo SPF presso il destinatario e - poiché non c'è una firma DKIM sul payload SIGILLATO - anche DMARC fallirà. I destinatari con DMARC rigoroso (Gmail, Outlook con enforcement `p=reject`, Proofpoint) respingeranno o cestineranno il messaggio.

    IP del sigillatore da aggiungere in SPF:

    | Ambiente | Host del sigillatore | IP da aggiungere a SPF |
    |-------------|-------------|------------------|
    | HIN Test (alpha/beta) | `mx3.hintest.ch` | `193.247.208.66` |
    | HIN Produzione | TBD - richiedere lista canonica a HIN prima del go-live | TBD |

    Se HIN pubblica più di un host di sigillatura (es. `mx1`, `mx2`, `mx3`), includere **tutti** i loro IP. Risolverli con `dig +short mx hintest.ch` seguito da `dig +short A <ogni-mx>`. Fino a quando non si ha la lista completa, lasciare la policy SPF a `~all` (softfail) invece di `-all` (hardfail) in modo che le email SIGILLATE legittime attraverso un IP di sigillatore non elencato non vengano immediatamente respinte.

!!! warning "Limite di ricerca SPF"
    La catena `include:` totale in un record SPF deve rimanere al di sotto di **10 ricerche DNS**. L'aggiunta di voci `ip4:` non conta verso questo limite. Verificare il conteggio con [MXToolbox SPF lookup](https://mxtoolbox.com/spf.aspx).

**Come Stargate utilizza SPF**: Il demone mtaconf risolve il record SPF di ogni dominio per popolare automaticamente l'elenco degli IP autorizzati a inoltrare attraverso Stargate senza autenticazione. Ecco come gli IP in uscita di Microsoft 365 vengono automaticamente inseriti nella whitelist - appaiono nella catena `include:spf.protection.outlook.com`.

---

## Record raccomandati

### PTR (DNS inverso)

Configurare il record DNS inverso (PTR) per l'IP Stargate in modo che corrisponda a `<MAIL_HOSTNAME>`:

```plain
200.117.140.128.in-addr.arpa.    PTR    mail.example.ch.
```

Questo viene configurato presso il **provider di hosting** (Hetzner, Azure, AWS, ecc.), non nel pannello DNS del registrar del dominio. La maggior parte dei provider ha un'impostazione "DNS inverso" o "rDNS" nella pagina di gestione del server/IP.

**Perché**: Molti server di posta riceventi (inclusi Gmail e Outlook) controllano che il record PTR dell'IP di connessione risolva un nome host e che quel nome host risolva lo stesso IP (DNS inverso a conferma diretta / FCrDNS). Un PTR mancante o non corrispondente è un forte segnale di spam e può causare fallimenti di consegna.

### Record DMARC

Pubblicare una policy DMARC per ogni dominio mittente. Iniziare con `p=none` (solo monitoraggio), quindi rafforzare dopo aver confermato l'allineamento:

```plain
_dmarc.<YOUR_DOMAIN>.    TXT    "v=DMARC1; p=none; rua=mailto:postmaster@<YOUR_DOMAIN>"
```

Esempio:

```plain
_dmarc.example.ch.    TXT    "v=DMARC1; p=none; rua=mailto:postmaster@example.ch"
```

Una volta che i report aggregati DMARC confermano che SPF e/o DKIM passano costantemente, rafforzare la policy:

1. `p=none` - solo monitoraggio (iniziare qui)
2. `p=quarantine` - le email sospette vanno in spam
3. `p=reject` - le email non autorizzate vengono respinte

**Perché**: DMARC lega insieme SPF e DKIM e dice ai destinatari cosa fare con le email che falliscono entrambi. Anche `p=none` è sufficiente per rimuovere il banner "non possiamo verificare questo mittente" di Outlook, purché SPF passi.

Verificare il record DMARC: [MXToolbox DMARC lookup](https://mxtoolbox.com/dmarc.aspx)

### Record DKIM

Se il dominio è un dominio accettato in M365 o Google Workspace, abilitare la firma DKIM nel centro amministrativo e pubblicare i record CNAME come indicato:

**Esempio M365:**

```plain
selector1._domainkey.<YOUR_DOMAIN>.    CNAME    selector1-<YOUR_DOMAIN_DASHED>._domainkey.<TENANT>.onmicrosoft.com.
selector2._domainkey.<YOUR_DOMAIN>.    CNAME    selector2-<YOUR_DOMAIN_DASHED>._domainkey.<TENANT>.onmicrosoft.com.
```

!!! note
    Pubblicare i record CNAME da soli non è sufficiente - la firma DKIM deve anche essere **abilitata** nel centro amministrativo M365 (portale Defender > Autenticazione email > DKIM).

**Perché**: DKIM dimostra che il corpo del messaggio non è stato manomesso durante il transito. Combinato con SPF e DMARC, fornisce la più forte autenticazione del mittente.

---

## Configurazione multi-dominio

Per deployment che gestiscono più domini di posta (configurati tramite la pagina `/mail` del dashboard), ogni dominio necessita del proprio set di record DNS.

### Record per dominio

Per ogni dominio configurato:

| Record | Richiesto |
|--------|----------|
| MX che punta a `<MAIL_HOSTNAME>` | Sì |
| SPF che include `ip4:<STARGATE_IP>` | Sì |
| DMARC (`_dmarc.<domain>`) | Raccomandato |
| DKIM (dal provider di posta) | Raccomandato |

Il record A e il record PTR sono condivisi (puntano al server Stargate, non ai singoli domini).

### Routing di posta per dominio

I record MX di ogni dominio dicono a Stargate dove consegnare le email elaborate. Se domini diversi utilizzano server Exchange diversi:

```plain
domain1.ch    MX    15    mail.domain1.ch.
domain1.ch    MX    20    exchange1.domain1.ch.

domain2.ch    MX    15    mail.domain2.ch.
domain2.ch    MX    20    exchange2.domain2.ch.
```

In alternativa, configurare destinazioni di relay esplicite per dominio tramite la pagina `/mail` del dashboard (campo host di relay per dominio) per sovrascrivere il routing basato su MX.

---

## Verifica

Dopo aver configurato tutti i record, verificarli:

```bash
# Record A
host <MAIL_HOSTNAME>
# Previsto: <MAIL_HOSTNAME> ha indirizzo <STARGATE_IP>

# Record MX
host -t mx <YOUR_DOMAIN>
# Previsto: Entrambi i record MX di Stargate ed Exchange elencati

# Record SPF
host -t txt <YOUR_DOMAIN> | grep v=spf1
# Previsto: Il record SPF include ip4:<STARGATE_IP>

# PTR (DNS inverso)
host <STARGATE_IP>
# Previsto: <STARGATE_IP> → <MAIL_HOSTNAME>

# DNS inverso a conferma diretta (FCrDNS)
host $(host <STARGATE_IP> | awk '{print $NF}' | sed 's/\.$//')
# Previsto: risolve in <STARGATE_IP>

# DMARC
host -t txt _dmarc.<YOUR_DOMAIN>
# Previsto: v=DMARC1; p=...

# DKIM (M365)
host -t cname selector1._domainkey.<YOUR_DOMAIN>
# Previsto: CNAME verso il onmicrosoft.com del tenant
```

Esempio di output:

```shell
$ host mail.example.ch
mail.example.ch ha indirizzo 128.140.117.200

$ host -t mx example.ch
example.ch la posta è gestita da 15 mail.example.ch.
example.ch la posta è gestita da 20 example-ch.mail.protection.outlook.com.

$ host -t txt example.ch | grep v=spf1
example.ch testo descrittivo "v=spf1 ip4:128.140.117.200 include:spf.protection.outlook.com -all"

$ host 128.140.117.200
200.117.140.128.in-addr.arpa puntatore nome dominio mail.example.ch.

$ host -t txt _dmarc.example.ch
_dmarc.example.ch testo descrittivo "v=DMARC1; p=none; rua=mailto:postmaster@example.ch"
```

Strumenti online:

- [MXToolbox MX Lookup](https://mxtoolbox.com/MXLookup.aspx)
- [MXToolbox SPF Check](https://mxtoolbox.com/spf.aspx) (include conteggio ricerche)
- [MXToolbox DMARC Check](https://mxtoolbox.com/dmarc.aspx)
- [Mail-Tester](https://www.mail-tester.com/) (inviare una email di test per ottenere un punteggio di deliverability)

---

## Risoluzione dei problemi

### "Client host rejected: Access denied" (554 5.7.1)

Stalwart sta rifiutando il server mittente perché il suo IP non è nell'elenco dei relay autorizzati. Questo di solito significa:

- Il record SPF del dominio non include l'intervallo IP del server mittente
- La configurazione della posta non è stata ricaricata da quando il record SPF è stato aggiornato

Ricaricare la configurazione della posta tramite la pagina `/mail` del dashboard (inviare di nuovo la configurazione) o riavviare il container: `docker compose restart stalwart`

### Email contrassegnata come spam / "impossibile verificare il mittente"

- SPF manca o non include l'IP Stargate - aggiungere `ip4:<STARGATE_IP>` al record SPF
- DMARC non è pubblicato - aggiungere almeno `v=DMARC1; p=none`
- Il record PTR manca o non corrisponde - configurare il DNS inverso presso il provider di hosting
- DKIM non è abilitato nel tenant M365/provider

### La ricerca MX restituisce solo Stargate

Se Stargate è l'unico MX per un dominio, Stalwart filtra il proprio nome host e non ha alcuna destinazione di relay. Aggiungere un secondo record MX che punti al server di posta:

```plain
example.ch.    MX    15    mail.example.ch.          ← Stargate (in entrata)
example.ch.    MX    20    example-ch.mail.protection.outlook.com.  ← Exchange (destinazione relay)
```

### Conteggio ricerche SPF superato (> 10)

Ogni `include:` nel record SPF attiva ulteriori ricerche DNS. La catena totale deve rimanere sotto 10. Soluzioni:

- Utilizzare voci `ip4:` / `ip6:` invece di `include:` dove possibile (non contano)
- Appiattire gli include nidificati usando uno strumento come [SPF Flattener](https://dmarcly.com/tools/spf-record-flattener)
- Rimuovere le voci `include:` inutilizzate da vecchi provider

### Porta 25 bloccata dal provider di hosting

Alcuni provider cloud (Azure, alcuni piani Hetzner) bloccano la porta 25 in uscita per impostazione predefinita. Verificare con il provider e richiedere un'eccezione. Questo influisce sia sulla consegna in entrata (server esterni che si connettono a Stargate) sia sul relay in uscita (Stargate che consegna alle destinazioni MX).
