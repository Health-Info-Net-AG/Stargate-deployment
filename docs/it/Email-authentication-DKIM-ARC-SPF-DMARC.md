# Autenticazione e mail (DKIM / ARC / SPF / DMARC)

**Modulo:** HIN Mail Gateway -> Domains -> *[dominio]* -> Email authentication
**Si applica a:** Amministratori di dominio che configurano la firma in uscita e la verifica in entrata per un dominio di posta

---

La sezione **Email authentication** controlla come viene dimostrata l'autenticità della posta e con quale rigore viene verificata l'autenticità della posta in entrata, ovvero la verifica DKIM/ARC/SPF/DMARC. Genera inoltre i record DNS TXT che devono essere pubblicati affinché i server di posta esterni possano verificare la posta del vostro dominio.

Si accede alla sezione tramite:

```
Domains -> selezionare un dominio -> Email authentication
```

Il pannello è composto da cinque sottosezioni:

1. DKIM
2. ARC
3. SPF
4. DMARC
5. Record DNS da pubblicare

Le modifiche vengono applicate solo dopo aver cliccato sul pulsante **Save** in fondo alla pagina.

![Screenshot](assets/Email-authentication.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

---

### Cosa fa ciascun protocollo

| Protocollo | Direzione | Scopo |
|---|---|---|
| **DKIM** (DomainKeys Identified Mail) | Firma in uscita / Verifica in entrata | Firma crittograficamente i messaggi in uscita con una chiave privata, associata a una chiave pubblica pubblicata nel DNS, in modo che i destinatari possano confermare che il messaggio non è stato alterato durante il transito e proviene realmente da questo dominio |
| **ARC** (Authenticated Received Chain) | Firma della verifica in entrata per il relay successivo | Preserva i risultati di autenticazione DKIM/SPF originali quando un messaggio passa attraverso intermediari (ad es. mailing list, servizi di inoltro) che altrimenti comprometterebbero le firme DKIM |
| **SPF** (Sender Policy Framework) | Verifica in entrata | Verifica che l'indirizzo IP del server di posta mittente sia autorizzato a inviare posta per il dominio del mittente, sulla base di un record DNS pubblicato da quel dominio |
| **DMARC** (Domain-based Message Authentication, Reporting & Conformance) | Verifica in entrata | Collega tra loro i risultati di DKIM e SPF e indica ai server destinatari come comportarsi |

Configurare correttamente DKIM e DMARC per il **proprio dominio** protegge la deliverability e il marchio dallo spoofing. Le impostazioni di **verifica** (i menu a tendina di verifica DKIM, ARC, SPF, DMARC) controllano invece con quanto rigore il gateway si fida di questi segnali sulla posta **in entrata** proveniente da altri domini.

---

### DKIM

| Campo | Descrizione |
|---|---|
| **Enable DKIM signing** | Quando attivo, il gateway firma tutta la posta in uscita da questo dominio con la chiave privata configurata. Attivare questa opzione prima di pubblicare il record DNS DKIM |
| **Generate DKIM key** (pulsante, in alto a destra) | Genera una nuova coppia di chiavi RSA-2048 per questo dominio e popola il campo Private key (PEM) |
| **DKIM verification** | Controlla con quale rigore un'e mail viene verificata rispetto al record DKIM pubblicato del mittente |
| **Selector** | Il selettore DKIM (ad es. `s1`) usato per pubblicare e cercare la chiave pubblica all'indirizzo `<selector>._domainkey.<domain>`. Modificare questo valore solo se è necessario eseguire più chiavi in parallelo (ad es. durante una rotazione delle chiavi): ogni selettore richiede il proprio record DNS TXT |
| **Private key (PEM)** | La chiave privata RSA usata per firmare la posta in uscita. È possibile cliccare su **Generate DKIM key** per crearne una, oppure incollare una propria chiave privata RSA-2048 in formato PEM |

### Come configurare DKIM per un nuovo dominio
1. Cliccare su **Generate DKIM key** (oppure incollare una chiave PEM RSA-2048 esistente gestita esternamente)
2. Lasciare **Selector** sul valore predefinito (`s1`) a meno che non ci sia un motivo per modificarlo
3. Impostare **Enable DKIM signing** su Active
4. Cliccare su **Save**
5. Copiare il record TXT `s1._domainkey.<domain>` generato dal riquadro **DNS records to publish** (vedere §7) e aggiungerlo presso il proprio provider DNS
6. Una volta propagato il record DNS, la posta firmata da questo dominio porterà una firma DKIM valida

### Come ruotare una chiave DKIM
1. Cliccare su **Replace key** accanto a Private key (PEM)
2. Generare una nuova chiave (oppure incollarne una nuova)
3. Pubblicare il record TXT del nuovo selettore nel DNS *prima* di salvarlo/attivarlo in produzione, per evitare una finestra temporale in cui la posta firmata non può essere verificata
4. Salvare, quindi rimuovere il record DNS del vecchio selettore una volta confermato che la nuova chiave sta firmando correttamente

---

### ARC

| Campo | Descrizione |
|---|---|
| **ARC verification** (menu a tendina) | Controlla con quale rigore vengono validate le catene ARC in entrata |
| **Enable ARC signing** | Quando attivo, il gateway aggiunge un sigillo ARC alla posta inoltrata, preservando i risultati di autenticazione se il messaggio viene successivamente inoltrato tramite un altro sistema |
| **Reuse DKIM key** (interruttore) | Quando attivo, la firma ARC utilizza la stessa chiave RSA configurata nella sezione DKIM sopra, invece di richiederne una separata. Consigliato a meno che non ci sia una necessità specifica di mantenere le due firme crittograficamente separate |

---

### SPF

| Campo | Descrizione |
|---|---|
| **SPF verification** | Controlla con quale rigore la posta in entrata viene verificata rispetto al record SPF pubblicato del dominio mittente |

> **Nota:** Questo pannello controlla solo la *verifica* dell'SPF in entrata; non genera un record SPF TXT in uscita per il proprio dominio (nessuna voce SPF compare nella §7 "DNS records to publish"). Se questo dominio invia posta tramite un relay esterno (ad es. Microsoft 365, configurato in **Mail routing -> Outbound relay**), assicurarsi che il meccanismo `include:` di quel provider sia già pubblicato nel record SPF del proprio dominio presso il proprio provider DNS, indipendentemente da questo gateway.

---

### DMARC

| Campo | Descrizione |
|---|---|
| **DMARC verification** | Controlla con quale rigore la posta in entrata viene verificata rispetto alla policy DMARC del mittente |


### Valore di verifica


| Etichetta interfaccia | Valore | Comportamento |
|---|---|---|
| **Disabled** | `disable` | Non viene verificato affatto. Il meccanismo non viene eseguito |
| **Optional** | `relaxed` | Viene verificato e **segnalato** in `Authentication-Results`. Il messaggio viene **sempre accettato**, sia in caso di esito positivo che negativo |
| **Required** | `strict` | Viene verificato e segnalato, e il messaggio viene **rifiutato** in caso di fallimento definitivo. Altrimenti viene accettato |

In sintesi: Disabled significa che non viene effettuato alcun controllo; Optional e Required verificano entrambi ed registrano il risultato. L'unica differenza tra i due è l'applicazione: **Optional non rifiuta mai**, **Required rifiuta in caso di fallimento definitivo**.

Cosa costituisce un "fallimento definitivo" per Required (per meccanismo):
- **DKIM**: il messaggio contiene firme e *tutte* falliscono. Nessuna firma presente equivale a `none`, non un fallimento, quindi non viene rifiutato.
- **SPF**: un fallimento definitivo `-all`. SoftFail/neutral/none/temp error vengono segnalati ma non provocano il rifiuto.
- **DMARC**: né DKIM né SPF risultano allineati, *e* c'è un verdetto di fallimento effettivo. Nessun record DMARC pubblicato equivale a `none`, quindi non viene rifiutato.
- **ARC**: la catena ARC fallisce la convalida. Nessuna catena equivale a `none`, quindi non viene rifiutato.

Due note importanti:
- **DKIM viene sempre eseguito internamente** perché DMARC ne ha bisogno. L'impostazione DKIM controlla solo se viene registrato un risultato `dkim=` e se un fallimento DKIM può causare un rifiuto; non modifica mai il verdetto DMARC.
- Ogni meccanismo è indipendente, quindi è possibile ad esempio impostare **DMARC = Required** mantenendo **DKIM/SPF = Optional**: la posta problematica viene rifiutata in base al verdetto DMARC, e si ottengono comunque righe `dkim=`/`spf=` individuali nell'header per una migliore visibilità.


---

### Record DNS da pubblicare

Questo riquadro mostra i record TXT esatti da creare presso il provider DNS del proprio dominio, affinché i server di posta esterni possano verificare la posta di questo dominio. I record mostrati si aggiornano automaticamente in base al selettore DKIM e alle impostazioni della policy DMARC sopra indicate.

| Record | Host | Tipo | Valore |
|---|---|---|---|
| Chiave pubblica DKIM | `<selector>._domainkey.<domain>` (ad es. `s1._domainkey.vrgnservices.eu`) | TXT | `v=DKIM1; k=rsa; p=<public key>` |
| Policy DMARC | `_dmarc.<domain>` (ad es. `_dmarc.vrgnservices.eu`) | TXT | `v=DMARC1; p=<policy>` (ad es. `p=none`) |

Usare l'icona di copia nell'angolo in alto a destra di ciascun riquadro record per copiarne il valore esatto. Incollare ciascun record come nuovo record TXT presso il proprio registrar/provider DNS, usando **Host/Name** e **Value** come mostrato.

> Le modifiche DNS possono impiegare da pochi minuti fino a 48 ore per propagarsi, a seconda delle impostazioni TTL del proprio provider. L'applicazione DKIM/DMARC non dovrebbe essere resa più severa (ad es. attivando la firma o spostando la policy DMARC oltre `none`) finché non si è confermato che i record si sono propagati e vengono risolti correttamente.

---

## Salvataggio delle modifiche

Nessuna delle impostazioni sopra ha effetto finché non si clicca sul pulsante arancione **Save** in fondo alla pagina. Save applica insieme tutte le modifiche su DKIM, ARC, SPF e DMARC; non esiste un salvataggio per singola sezione.

---

## Risoluzione dei problemi

| Sintomo | Causa probabile |
|---|---|
| La posta in uscita fallisce il controllo DKIM presso i server destinatari | La firma DKIM è attiva ma il record DNS TXT non è ancora pubblicato/propagato, oppure c'è una discrepanza di selettore tra gateway e DNS. |
| Il sigillo ARC manca sulla posta inoltrata | **Enable ARC signing** è disattivato, oppure **Reuse DKIM key** è disattivato senza che sia configurata una chiave ARC separata. |
| Non è possibile vedere la chiave privata DKIM per copiarla altrove | È voluto: una volta salvata, la chiave viene mascherata (`<hidden>`) e non può essere visualizzata nuovamente. Usare **Replace key** per emetterne una nuova se è necessario spostarla su un sistema che non ne possiede già una copia. |
| La posta legittima inizia a essere messa in quarantena/rifiutata dopo una modifica della policy DMARC | Una fonte di invio legittima non è ancora allineata a DKIM/SPF. Riportare la policy a `none`, identificare la fonte problematica, correggere l'allineamento, quindi rendere di nuovo più severa la policy. |
