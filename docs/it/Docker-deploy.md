# Deployment Docker di Stargate

## Prerequisiti

**Requisiti del server:**

Fare riferimento a [Requisiti raccomandati](./index.md#requisiti-del-server)

* Docker verrà installato automaticamente se mancante
* Assicurarsi che ci sia una connessione Internet sulla macchina dove si stanno installando i servizi Stargate
* Assicurarsi che il traffico sia configurato correttamente per raggiungere l'istanza Stargate

## Passo 1: Configurare le impostazioni cliente

!!! tip
    È possibile clonare il nostro repository con tutti i dati e le configurazioni di esempio all'interno con il comando:

    ```bash
    git clone https://github.com/Health-Info-Net-AG/Stargate-deployment.git
    ```

    Se non si ha `git` installato, è sempre possibile ottenere un archivio con tutti i file all'interno. Scaricarlo tramite il seguente link. [Scarica come ZIP](https://github.com/Health-Info-Net-AG/Stargate-deployment/archive/refs/heads/main.zip){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

Lo script di installazione crea automaticamente `customer-config.sh` dal modello fornito al primo avvio, quindi una nuova installazione non richiede **alcuna configurazione manuale**. Se si preferisce crearlo manualmente, copiare il modello:

```bash
cp customer-config-prod.example.sh customer-config.sh
```

**Non** è necessario modificarlo - ogni valore viene rilevato automaticamente oppure configurato successivamente tramite la dashboard:

| Impostazione | Come viene impostata |
|---------|---------------|
| `SERVER_STATIC_IP` | Rilevato automaticamente dall'interfaccia di rete principale del server. |
| `CUSTOMER_NAME` | Per impostazione predefinita, il nome host del sistema. |
| `DEPLOYMENT_NAME` | Derivato da `CUSTOMER_NAME` (utilizzato nelle etichette dei log e nel nome host di Alloy). |
| Password e chiavi (`POSTGRES_PASSWORD`, `S3_SECRET_KEY`, `VAULT_TOKEN`, `WG_PRIVATE_KEY`) | Generate in modo sicuro al primo avvio e riscritte in `customer-config.sh`. |

I domini di posta, il nome host di posta, i certificati S/MIME e i peer WireGuard sono tutti configurati in fase di esecuzione tramite la dashboard dopo l'avvio dello stack - non fanno parte di `customer-config.sh`.

!!! note "Dietro NAT o un IP flottante?"
    Il rilevamento automatico utilizza l'IP dell'interfaccia principale del server. Se il server è raggiungibile tramite un IP pubblico o flottante *diverso* (comune con il NAT), impostare `SERVER_STATIC_IP` su quell'IP pubblico in `customer-config.sh` prima dell'installazione, in modo che gli URL della dashboard e di login di Keycloak puntino all'indirizzo raggiungibile. In caso contrario, lasciarlo vuoto.

**Impostazioni auto-derivate — lasciare vuote a meno che non sia necessario sovrascriverle:**

| Impostazione | Derivata da | Predefinito |
|---------|-------------|---------|
| `MXENGINE_PUBLIC_ADDRESS` | `SERVER_STATIC_IP` | `http://<SERVER_STATIC_IP>:8084` |

**Impostazioni del certificato S/MIME:**

| Impostazione | Descrizione | Predefinito |
|---------|-------------|---------|
| `CERT_CA_IRISAGENT_DOMAIN` | Dominio CA per l'emissione del certificato tramite tunnel WireGuard | `hintest.ch` |

!!! note
    **La configurazione del peer WireGuard** viene eseguita in fase di esecuzione tramite il dashboard (pagina `/installation`). I dettagli del peer sono configurati per deployment dopo che lo stack è attivo - non fanno parte di `customer-config.sh`.

**Impostazioni locali WireGuard (in genere lasciate ai valori predefiniti):**

| Impostazione | Predefinito | Descrizione |
|---------|---------|-------------|
| `WG_PRIVATE_KEY` | *(auto-generato)* | Generato da IRISAgent al primo avvio, poi salvato in `customer-config.sh` |
| `WG_LOCAL_IP` | `SERVER_STATIC_IP` | Auto-derivato. Sovrascrivere solo se è necessario un indirizzo di tunnel diverso. |
| `WG_INTERFACE_PORT` | `19818` | Porta del tunnel WireGuard (sia TCP che UDP sono esposti) |
| `WG_TRANSPORT_MODE` | `tcp` | Protocollo di trasporto: `tcp` (predefinito, funziona attraverso la maggior parte dei firewall) o `udp` |

**Impostazioni opzionali (hanno valori predefiniti ragionevoli):**

| Impostazione | Predefinito | Descrizione |
|---------|-------------|---------|
| `POSTGRES_PASSWORD` | *(auto-generato)* | Password casuale di 24 caratteri auto-generata se vuota |
| `S3_SECRET_KEY` | *(auto-generato)* | Chiave segreta S3 per lo storage di oggetti |
| `OUTBOUND_SEALER_MX_DOMAIN` | `hintest.ch` | Dominio MX del sigillatore per la consegna dei sigilli in uscita |
| `POLICY_SYNC_REPO_URL` | GitHub HIN Stargate policies | URL del repository Git per la sincronizzazione delle policy OPA/Rego |
| `LOKI_URL` | *(non impostato)* | Endpoint Loki per l'invio centralizzato dei log (es. `https://loki.example.com`) |

**Auto-generati (non impostare manualmente):**

* `VAULT_TOKEN` — Generato da Vault durante la prima inizializzazione, salvato in `customer-config.sh`
* `WG_PRIVATE_KEY` — Generato da IRISAgent al primo avvio, salvato in `customer-config.sh`

## Passo 2: Deploy su un server

!!! tip
    È possibile clonare il nostro repository con tutti i dati e le configurazioni di esempio all'interno con il comando:

    ```bash
    git clone https://github.com/Health-Info-Net-AG/Stargate-deployment.git && \
      cd Stargate-deployment-main
    ```

    Se non si ha `git` installato, è sempre possibile ottenere un archivio con tutti i file all'interno ed estrarlo:

    ```bash 
    wget https://github.com/Health-Info-Net-AG/Stargate-deployment/archive/refs/heads/main.zip && \
      unzip main.zip && \
      rm main.zip && \
      cd Stargate-deployment-main
    ```

Copiare manualmente i file sul server

```bash
scp -r docker-compose/* tuo-server:/percorso/verso/stargate/
```

SSH al server

```bash
ssh tuo-server
cd /percorso/verso/stargate
```

Creare la configurazione cliente dal modello e compilare le impostazioni richieste ([vedere Passo 1](#passo-1-configurare-le-impostazioni-cliente))

```bash
cp customer-config-prod.example.sh customer-config.sh
nano customer-config.sh   # Compilare le impostazioni richieste (vedere Passo 1)
```

Eseguire l'installazione

```bash
chmod +x scripts/*.sh
./scripts/install.sh
```

## Passo 3: Cosa fa l'installazione

Lo script di installazione (`install.sh`) esegue i seguenti passi:

1. **Controllare le dipendenze** — Rileva Docker, Docker Compose e `jq`. Se mancano, li installa automaticamente (supporta Ubuntu/Debian, RHEL/AlmaLinux/Rocky).
2. **Caricare e validare** `customer-config.sh` — Controlla i campi richiesti (`SERVER_STATIC_IP`, `CUSTOMER_NAME`, `DEPLOYMENT_NAME`). Deriva automaticamente i campi opzionali (URL MXEngine, ecc.).
3. **Generare `.env`** dalla configurazione cliente — Genera automaticamente le password se non impostate.
4. **Avviare tutti i servizi** tramite Docker Compose (infrastruttura + applicazioni).
5. **Inizializzare Vault** — Il container `vault-init` inizializza, scongela e crea i mount dei segreti KV-v2. Scrive opzionalmente la chiave privata WireGuard in Vault.
6. **Salvare le chiavi Vault** in `secrets/vault-keys.json` e aggiornare `.env` con il token root. Il token viene anche salvato in `customer-config.sh` per la persistenza attraverso le ricreazioni della VM.
7. **Riavviare i servizi applicativi** per applicare il token Vault.
8. **Salvare la chiave privata WireGuard** in `customer-config.sh` — estratta da Vault dopo che IRISAgent l'ha generata.
9. **Impostare il cron job di backup giornaliero** (viene eseguito alle 2:00 AM).

Una volta completata l'installazione, lo stack è in esecuzione ma non sono ancora configurati domini di posta, certificato S/MIME o peer WireGuard. Continuare con [Passo 4: Onboarding tramite il dashboard](#passo-4-onboarding-tramite-il-dashboard).

## Passo 4: Onboarding tramite il dashboard

Dopo l'installazione, completare l'onboarding tramite il dashboard all'indirizzo `https://<SERVER_STATIC_IP>`. Il dashboard guida attraverso tre pagine in ordine:

### `/installation` — Configurazione del peer WireGuard

Esegue l'handshake nonce/HIN per stabilire una connessione peer WireGuard e salva la configurazione WireGuard risultante nel servizio IRISAgent.

### `/onboarding` — Certificato S/MIME

Genera la chiave di firma S/MIME e il CSR tramite il servizio smimekeys e invia il CSR alla CA attraverso il tunnel WireGuard ora stabilito. (Questo sostituisce il precedente flusso di certificati basato su script.)

### `/mail` — Domini di posta e configurazione del relay

Invia il nome host e l'elenco dei domini di relay al servizio `mtaconf` tramite la sua API REST. Il demone applica la configurazione a Stalwart senza riavviare il container.

!!! tip "Aggiungere o modificare domini in seguito"
    Riaprire la pagina `/mail` nel dashboard, modificare l'elenco dei domini e inviare. Il demone applica la modifica in fase di esecuzione - nessuna invocazione di script, nessuna modifica di `.env`, nessun riavvio del servizio necessario.

## Passo 5: Registrazione del peer WireGuard

L'invio del CSR S/MIME su `/onboarding` fallirà se l'istanza Stargate non è ancora registrata come peer WireGuard sul lato CA HIN. Questo è il problema più comune durante la configurazione iniziale.

La pagina `/installation` del dashboard gestisce automaticamente la registrazione del peer WireGuard tramite l'handshake nonce/HIN. Se la registrazione automatica fallisce, è possibile effettuare la registrazione manuale fornendo i seguenti valori a HIN:

1. **Chiave pubblica WireGuard** — estrarre dai log irisagent:

   ```bash
   docker compose logs irisagent | grep "public key"
   ```

2. **`DEPLOYMENT_NAME`** — dal proprio `customer-config.sh`
3. **`SERVER_STATIC_IP`** — l'IP pubblico del server Stargate
4. **`WG_INTERFACE_PORT`** — solo se modificato rispetto al valore predefinito `19818`

**Dopo la conferma della registrazione del peer:**

Rieseguire la pagina `/onboarding` nel dashboard per rigenerare il CSR e inviarlo attraverso il tunnel ora attivo.

**Per verificare il tunnel prima di richiedere il certificato:**

Riavviare solo irisagent

```bash
docker compose restart irisagent
```

Verificare l'handshake WireGuard riuscito

```bash
docker compose logs irisagent 2>&1 | grep -i "handshake\|peer"
```

!!! tip
    Controllare il firewall: La porta `19818/TCP` deve essere aperta **in entrambe le direzioni, in entrata e in uscita** sul server Stargate.

## Passo 6: Raccomandazioni post-onboarding

Una volta emesso il certificato e la posta in circolazione, due elementi di configurazione sono fortemente raccomandati per qualsiasi deployment in produzione. Saltarli non rompe la crittografia, ma degrada la reputazione del mittente, causa avvisi "non possiamo verificare il mittente" in Outlook/Gmail e può portare a un blocco della posta in uscita.

### Passo 6.1 SPF / DKIM / DMARC per i domini mittente

Stargate invia la posta dal proprio IP pubblico per conto degli utenti. Senza record di autenticazione DNS corretti, i destinatari vedranno avvisi "non possiamo verificare questo mittente" e potrebbero rifiutare la posta.

Per istruzioni complete sulla configurazione dei record SPF, DKIM, DMARC e PTR, vedere la [Guida alla configurazione DNS](DNS-setup.md#record-raccomandati).

Come minimo, per ogni dominio instradato attraverso Stargate:

* **SPF**: aggiungere `ip4:<STARGATE_IP>` al record TXT del dominio
* **DMARC**: pubblicare `v=DMARC1; p=none` su `_dmarc.<YOUR_DOMAIN>`
* **PTR**: impostare il DNS inverso per l'IP Stargate in modo che corrisponda a `MAIL_HOSTNAME`

### Passo 6.2 Relay della posta in uscita attraverso la piattaforma di posta (raccomandato per M365 / Exchange Online)

Per impostazione predefinita, dopo che Stargate firma/crittografa una posta in uscita, la consegna direttamente al MX del destinatario. Questo funziona, ma l'IP di connessione è l'IP di Stargate - e a meno che quell'IP non abbia anni di reputazione positiva, può finire su liste nere di terze parti (es. Barracuda, Abusix), causando fallimenti di consegna intermittenti.

Il modello raccomandato è **inviare la posta firmata attraverso il tenant M365 / Exchange** in modo che l'ultimo salto verso Internet sia l'infrastruttura ben reputata di Microsoft. Stargate firma e verifica ancora ogni messaggio secondo le policy; solo l'ultimo salto cambia. Questo rispecchia il modello di connettore "Invia a MX" del vecchio HIN MGW.

#### Lato Stargate — relay per dominio

Configurare il relay per dominio tramite la pagina `/mail` del dashboard. Ogni dominio può essere mappato al proprio endpoint in entrata M365 / Exchange; il dashboard invia il mapping all'API REST di mtaconf e Stalwart viene riconfigurato in fase di esecuzione.

Dopo che mxengine firma la posta, Stalwart la restituirà al tenant sulla porta 25 con TLS invece di consegnarla direttamente al MX del destinatario. Vedere `Exchange-integration.md` per la sintassi completa per dominio.

#### Lato M365 / Exchange Online

Si ricrea essenzialmente lo stesso insieme di connettori + regole di trasporto del vecchio HIN MGW (il manuale O365 originale di HIN MGW è il riferimento - si applicano le stesse cinque regole). Il minimo è:

1. **Connettore in entrata** - accetta la posta da Stargate, identificato dal certificato TLS (il soggetto del certificato deve corrispondere a un dominio accettato nel tenant). Un certificato auto-firmato su Stargate sarà respinto da questo connettore - utilizzare un certificato valido emesso da CA (Let's Encrypt va bene).
2. **Connettore in uscita "Invia a MX"** - consegna al MX del destinatario, attivato solo dalla regola di trasporto.
3. **Regola di trasporto `set_header`** - etichetta la posta in uscita con un header come `outgoing: outgoing_<dominio>` prima che lasci O365 la prima volta, in modo che il viaggio di ritorno possa riconoscerlo.
4. **Regola di trasporto `outgoing_to_mx`** - corrisponde all'header `outgoing_<dominio>` sulla posta che torna da Stargate e la instrada tramite il connettore "Invia a MX".
5. **Regola di trasporto `mgw_bypass_antispam`** - bypassa il filtraggio antispam sulla posta che torna da Stargate.

mxengine non rimuove header arbitrari, quindi il tag `outgoing_<dominio>` impostato da `set_header` sopravvive al viaggio di andata e ritorno e attiva correttamente `outgoing_to_mx`.

!!! info "Perché questo modello è importante"
    Con la configurazione di relay di ritorno, il mittente pubblico verso Internet è Microsoft. Combinato con SPF/DKIM/DMARC corretti (sezione 6.1), i destinatari vedono un IP Microsoft con `spf=pass` e `dkim=pass` allineati al dominio - che è il profilo di reputazione più pulito che si possa dare loro.

Vedere `Exchange-integration.md` per istruzioni dettagliate passo-passo incluse schermate.

## Avvii successivi (dopo il riavvio)

L'installatore abilita un'unità systemd `stargate`, quindi lo stack si avvia automaticamente all'avvio. Per avviarlo manualmente:

```bash
sudo systemctl start stargate
```

Questo esegue `start.sh`, che:

1. Avvia i servizi di infrastruttura
2. Scongela Vault utilizzando le chiavi memorizzate
3. Avvia i servizi applicativi

(`./scripts/start.sh` funziona ancora direttamente se si preferisce.)

## Arrestare i servizi

```bash
sudo systemctl stop stargate
```

(o direttamente `./scripts/stop.sh`)

Questo arresta i container ma preserva tutti i dati.

## Persistenza dei dati

Tutti i dati sono memorizzati in volumi Docker e **persistono attraverso i riavvii**.

| Servizio | Volume | Dati |
|---------|--------|------|
| PostgreSQL | `postgres_data` | Tutti i database (smimekeys, policy, irisagent, mxengine) |
| Vault | `vault_data` | Chiavi di crittografia, segreti, chiavi S/MIME |
| SeaweedFS | `seaweedfs_data` | Storage di oggetti (messaggi, allegati) |
| Stalwart | `stalwart_data` | Stato del server di posta |

### Operazioni sicure (dati preservati)

Arrestare e avviare:

```bash
sudo systemctl stop stargate
sudo systemctl start stargate
```

O utilizzando direttamente gli script:

```bash
./scripts/stop.sh
./scripts/start.sh
```

!!! warning "Non utilizzare i comandi `docker compose` direttamente"
    Utilizzare sempre `systemctl` o gli script forniti (`start.sh` / `stop.sh`) per gestire il deployment. L'esecuzione diretta di `docker compose up`, `docker compose down` o `docker compose restart` **non scongelerà Vault**, lasciando i servizi dipendenti impossibilitati ad avviarsi. Lo script `start.sh` gestisce automaticamente la procedura di scongelamento di Vault.

### Comportamento di scongelamento di Vault

**Vault si congela** quando il suo container viene riavviato. Questa è una funzionalità di sicurezza.

Lo script `start.sh` (e il servizio systemd) scongelano automaticamente Vault utilizzando le chiavi memorizzate in `secrets/vault-keys.json`. Questo è il motivo per cui è necessario utilizzare sempre gli script forniti o il servizio systemd per gestire lo stack.

## :warning: Operazioni distruttive (dati cancellati)

!!! warning
    Questi comandi **CANCELLANO TUTTI I DATI** - usare con cautela!

    È possibile ripristinare i dati solo se si eseguono [operazioni di backup](./Docker-advanced.md#backup-manuale) prima e si salva il backup in un luogo sicuro.

!!! danger
    Eliminare tutto (volumi, segreti, config)

    ```bash
    ./scripts/purge.sh
    ```

    O rimuovere manualmente i volumi. Il flag -v rimuove i volumi

    ```bash
    docker compose down -v
    ```

## Riferimento script

| Script | Scopo |
|--------|--------|
| `install.sh` | Prima installazione (Docker, Vault). La configurazione di dominio/certificato/peer avviene successivamente nel dashboard. |
| `update.sh` | Aggiornare le immagini dei servizi (preserva il token Vault, ricrea i container) |
| `start.sh` | Avviare i servizi e scongelare Vault |
| `stop.sh` | Arrestare i container (dati preservati) |
| `backup.sh` | Backup completo (database, chiavi Vault, configurazione, certificati) |
| `restore.sh` | Ripristinare da archivio di backup (funziona su macchina nuova) |
| `purge.sh` | :warning: Eliminare TUTTI i dati (richiede conferma) |
| `health-check.sh` | Health check completo di tutti i servizi (exit 0 = healthy, 1 = fallimenti) |
| `init-vault.sh` | Inizializzazione Vault (utilizzato dal container `vault-init`, non chiamato direttamente) |
| `init-keycloak.sh` | Impostazione password amministratore Keycloak (utilizzato dal container `keycloak-init`, non chiamato direttamente) |
| `gather-app-versions.sh` | Raccoglie le versioni delle app dagli endpoint `/liveness` per node-exporter (viene eseguito nel container `version-collector`) |

## File di configurazione

| File | Scopo |
|------|---------|
| `customer-config-prod.example.sh` | Modello per le impostazioni cliente (copiare in `customer-config.sh`) |
| `customer-config.sh` | Impostazioni specifiche del cliente (create dal modello, compilare prima dell'installazione) |
| `.env` | File di ambiente generato (creato da `install.sh`) |
| `secrets/vault-keys.json` | Chiavi di scongelamento Vault e token root (effettuare backup sicuro!) |
| `secrets/signing-key.csr` | CSR generato per il certificato S/MIME |

## Supporto

!!! tip "Supporto"

    Per qualsiasi domanda o problema relativo al deployment e al funzionamento dell'appliance Stargate, contattare il supporto HIN.

    Includere informazioni rilevanti come il nome del cliente, la versione dell'appliance e schermate/[log](./Docker-advanced.md#fornire-log-al-supporto) dove applicabile, per aiutarci a elaborare la richiesta in modo efficiente.
