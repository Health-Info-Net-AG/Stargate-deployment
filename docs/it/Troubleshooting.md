# Troubleshooting e diagnostica

Una guida strutturata per diagnosticare un'appliance Stargate dalla riga di comando: cosa verificare, dove si trovano i log e quali azioni di ripristino sono sicure.

!!! info "Dove si trovano gli script"
    Gli script di supporto si trovano nella directory di deployment, sotto `scripts/`. I comandi seguenti utilizzano il **percorso completo delle immagini VM**: `/usr/share/stargate-deployment/docker-compose/scripts/`. Se l'installazione è stata eseguita altrove, sostituirlo con la propria directory di installazione (la cartella che contiene `docker-compose.yml` e `scripts/`).

    I comandi `docker compose ...` devono essere eseguiti **dalla directory di deployment**:

    ```bash
    cd /usr/share/stargate-deployment/docker-compose   # adjust to your install path
    ```

!!! info "Dove si trovano i dati scrivibili"
    L'albero `docker-compose/` indicato sopra (script, `docker-compose.yml`, modelli di configurazione) è **di sola lettura durante l'esecuzione**. Tutti i dati scrivibili si trovano invece sotto **`/var/data`**: `.env`, `customer-config.sh`, `secrets/`, la configurazione TLS, Keycloak e APISIX generata, i backup e i dati propri di ciascun servizio (`STARGATE_DATA_DIR` sostituisce questa radice a scopo di test). In particolare: configurazione e secret si trovano in `/var/data/vereign/`, i backup in `/var/data/backups/` e il log degli aggiornamenti in `/var/data/vereign/update.log`. Per la descrizione completa, vedere [Configurazione avanzata di Docker](Docker-advanced.md). Utilizzare preferibilmente gli script wrapper (`./scripts/start.sh`, `./scripts/update.sh`, ...) anziché un semplice `docker compose up -d`, che non legge `/var/data/vereign/.env` in modo autonomo.

---

## 1. Per iniziare: il controllo dello stato

Un unico comando fornisce una panoramica dell'intera appliance:

=== "Rapido"

    ```bash
    /usr/share/stargate-deployment/docker-compose/scripts/health-check.sh
    ```

=== "Dettagliato"

    ```bash
    /usr/share/stargate-deployment/docker-compose/scripts/health-check.sh -v
    ```

Il comando segnala l'esito positivo o negativo per: **container** (in esecuzione / healthy), endpoint di **liveness** (smimekeys, policy, irisagent, mxengine), stato di sigillatura di **Vault**, connettività e database **PostgreSQL**, **SeaweedFS**, tunnel **WireGuard** e handshake con i peer, MTA **Stalwart** (porte 25 / 10026), endpoint delle metriche **Prometheus** e **disco / memoria**.

!!! tip
    Eseguire prima questo comando. Una singola riga `FAIL` di solito indica direttamente la sezione pertinente più sotto.

---

## 2. Dove si trovano i log

| Livello | Comando | Cosa mostra |
| ------- | --------- | --------------- |
| Avvio / prima installazione / avvio automatico | `sudo journalctl -u stargate -n 200 --no-pager` | Il servizio systemd che esegue `start.sh` all'avvio e l'installazione al primo avvio |
| Esecuzioni degli aggiornamenti | `cat /var/data/vereign/update.log` | Output dell'ultimo `update.sh` avviato dalla dashboard o dall'host |
| Un singolo servizio | `docker logs stargate-<service> --tail 100` | ad es. `stargate-dashboard`, `stargate-mxengine`, `stargate-keycloak` |
| Seguire un servizio in tempo reale | `docker logs -f stargate-mxengine` | In tempo reale |
| Tutti i container in tempo reale | `docker ps -a --format '{{.Names}}' \| xargs -I{} sh -c 'docker logs --timestamps -f {} 2>&1 \| sed "s/^/[{}] /"'` | Log unificati, con il nome del container come prefisso |
| Visualizzatore web dei log | Dozzle su `https://<SERVER_IP>:8190` (login Keycloak) | Consultare i log di tutti i container in un'interfaccia web |

Per inviare i log all'Assistenza HIN, utilizzare lo script di caricamento: raccoglie le ultime N righe di log di **ogni** servizio (insieme alle informazioni sull'host e sulle versioni), le carica e restituisce un link da condividere. Vedere **[Fornire log all'Assistenza](Docker-advanced.md#fornire-log-al-supporto)**:

```bash
/usr/share/stargate-deployment/docker-compose/scripts/send-logs-to-support.sh --tail 5000     # last 5000 lines from each service
# other options:  --since 1h   |   --until 5m   |   --all   (no argument = --tail 500)
```

Il caricamento è limitato a 20 MB, quindi su un'appliance molto carica è preferibile usare `--tail`/`--since` anziché `--all`.

---

## 3. Container non in esecuzione o in riavvio continuo

```bash
docker compose ps -a --format 'table {{.Service}}\t{{.Status}}'
```

Controllare la colonna `Status`:

| Stato | Significato | Azione |
| -------- | --------- | -------- |
| `Up ... (healthy)` | Funziona correttamente | - |
| `Up ...` (senza stato di salute) | In esecuzione; nessun healthcheck definito | Controllare i relativi `docker logs` se si sospetta un problema |
| `Restarting` | Riavvii in loop dopo un crash | `docker logs stargate-<svc>`: correggere la causa dell'errore (configurazione, secret, dipendenza) |
| `Exited (0)` | Inizializzazione una tantum completata correttamente (ad es. `*-init`, `vault-data-fixer`) | Normale |
| `Exited (1+)` | Non riuscito | `docker logs stargate-<svc>`: le ultime righe ne indicano il motivo |
| `Created` | Mai avviato, perché una dipendenza non si è avviata | Verificare da cosa dipende (`depends_on`, di solito Postgres/Vault) e risolvere prima quel problema |

Riavviare un singolo servizio (operazione sicura e non distruttiva):

```bash
docker compose up -d <service>          # recreate one service
docker compose restart <service>        # just restart it
```

!!! note "Ordine di avvio"
    I servizi attendono le proprie dipendenze (`depends_on` + healthcheck). Durante un riavvio completo, brevi righe `connection refused` / `database system is starting up` mentre Postgres e Vault si avviano sono **normali** e scompaiono entro un minuto.

---

## 4. Diagnosi in base ai sintomi

### La dashboard o Keycloak non si caricano / impossibile accedere

- Entrambi sono esposti tramite Caddy: la **dashboard** sulla porta `:443`, **Keycloak** sulla porta `:8180`.
- Controllare l'intera catena: `docker logs stargate-caddy`, `stargate-dashboard`, `stargate-keycloak`, `stargate-apisix`.
- Keycloak deve essere **healthy** prima che la dashboard funzioni: `docker compose ps keycloak`.
- Un avviso TLS nel browser è previsto (certificato autofirmato): accettarlo e proseguire.
- Se i reindirizzamenti durante il login non riescono, di solito l'URL pubblico non corrisponde all'indirizzo con cui si raggiunge l'appliance. Verificare che `KEYCLOAK_PUBLIC_URL` / `DASHBOARD_PUBLIC_URL` in `.env` puntino all'IP o all'host effettivamente utilizzato.

### Tunnel WireGuard inattivo / emissione dei certificati non riuscita

È il problema più frequente: **l'emissione dei certificati non riesce quando il tunnel è inattivo**, quindi occorre sempre risolvere prima il problema del tunnel.

```bash
/usr/share/stargate-deployment/docker-compose/scripts/health-check.sh -v      # shows WireGuard peer + handshake status
docker logs stargate-irisagent | grep -iE "handshake|peer|cert|wireguard"
```

- Verificare che il firewall consenta **`19818` (UDP *e* TCP)** in entrata e in uscita.
- Verificare che il peer sia registrato sul lato HIN (passaggio a cura dell'Assistenza). A tale scopo occorre fornire la chiave pubblica WG, `DEPLOYMENT_NAME`, `SERVER_STATIC_IP` e `WG_INTERFACE_PORT`.
- Non appena il tunnel mostra un handshake recente, riprovare l'emissione dei certificati dalla dashboard.

### Vault sigillato o inizializzazione non riuscita

```bash
docker compose exec vault vault status        # look for "Sealed: false"
docker logs stargate-vault-init
```

- Vault deve essere **dissigillato** affinché smimekeys, mxengine e policy funzionino. Le chiavi si trovano in `/var/data/vereign/secrets/vault-keys.json`.
- Se `vault-init` è terminato con un codice di uscita diverso da zero, il file delle chiavi potrebbe mancare o essere danneggiato. Controllarne i log; eseguendo di nuovo `/usr/share/stargate-deployment/docker-compose/scripts/init-vault.sh` si ritenta il dissigillamento.

!!! danger "Non eliminare `/var/data/vereign/secrets/vault-keys.json`"
    Perdere questo file significa perdere l'accesso a tutti i secret memorizzati. Conservarne un backup.

### PostgreSQL / connettività al database

```bash
docker compose exec postgres pg_isready -U postgres
docker logs stargate-postgres --tail 50
```

- Un messaggio temporaneo `the database system is starting up (57P03)` subito dopo un riavvio è normale: i servizi si riconnettono automaticamente.
- Errori di autenticazione persistenti indicano di solito che `POSTGRES_PASSWORD` in `.env` non corrisponde più al volume dei dati. Consultare le note su aggiornamenti e secret ed evitare di modificare questo valore a mano.

### La posta non viene recapitata

- La posta **in entrata** arriva sulla porta **`:25`** (Stalwart). Molti provider cloud **bloccano la porta 25** per impostazione predefinita:

    ```bash
    nc -zv <this-server-ip> 25          # from an external host
    docker logs stargate-stalwart --tail 100
    ```

    Se la porta `25` è bloccata, richiedere un'eccezione al proprio provider.
- La posta **in uscita e il sealing** passano da Stalwart → **mxengine** (`:8084` callback di sealing, SMTP `:1587`): `docker logs stargate-mxengine`.
- I **loop di posta** si manifestano con lo stesso messaggio che continua a circolare. Verificare che il record MX del proprio dominio non punti all'indirizzo IP di questa stessa appliance.
- Il routing previsto è descritto in **[Configurazione relay di posta](Mail-relay-setup.md)** e **[Configurazione DNS](DNS-setup.md)**.

### Aggiornamento non riuscito

```bash
docker logs stargate-ops-agent --tail 40      # the update orchestrator
cat /var/data/vereign/update.log              # the update script output
```

- L'ops-agent esegue il checkout del tag della release di destinazione (il cui `docker-compose.yml` fissa le versioni delle immagini), quindi esegue `update.sh` sull'host.
- Al termine, verificare che le versioni siano state applicate: `/usr/share/stargate-deployment/docker-compose/scripts/gather-app-versions.sh` (oppure controllare i tag delle immagini in `docker compose ps`).
- Se un servizio resta bloccato dopo un aggiornamento, ricrearlo con `docker compose up -d <service>`.

**L'aggiornamento si avvia ma non succede nulla (aggiornamento da una versione precedente).** Se il log dell'ops-agent si ferma a `pulling deployment repo ...` e l'aggiornamento non prosegue, molto probabilmente il repository sulla VM contiene **modifiche locali a un file tracciato** (di solito un `docker-compose.yml` modificato a mano). In questo caso il `git checkout` dell'ops-agent si rifiuta di procedere e l'aggiornamento si blocca. Forzare il ripristino del repository all'ultima revisione, quindi ripetere l'aggiornamento. Git è l'unica fonte di riferimento; questa operazione elimina solo le modifiche locali ai file **tracciati**. `customer-config.sh`, `.env` e `secrets/` si trovano in `/var/data/vereign/`, fuori dal checkout del repository, e vengono sempre preservati:

```bash
cd /usr/share/stargate-deployment
git fetch origin
git checkout -f main
git reset --hard origin/main
cd docker-compose
/usr/share/stargate-deployment/docker-compose/scripts/update.sh
```

`update.sh` rigenera `.env`, scarica le immagini e ricrea i servizi interessati: **non** è necessario riavviare Stargate manualmente. Al termine, ripetere l'aggiornamento dalla dashboard; ora procederà correttamente.

!!! warning
    Non utilizzare `git pull` in questo caso. Su un working tree con modifiche locali il comando si interrompe con il messaggio «local changes would be overwritten», costringendo a una deviazione tra `git stash`, conflitti di merge e ripristino manuale. La sequenza `git checkout -f` + `git reset --hard` riportata sopra evita del tutto questo problema ed è il metodo sicuro e ripetibile per aggiornare il repository.

### Dozzle (visualizzatore di log) non raggiungibile

- L'URL è `https://<SERVER_IP>:8190`; richiede un **login Keycloak** (stesso realm della dashboard) tramite oauth2-proxy.
- Dozzle è in esecuzione solo se `DOZZLE_ENABLED="true"`. Verifica: `docker compose ps dozzle oauth2-proxy`.
- Assicurarsi che il firewall consenta il traffico in entrata sulla porta **`:8190`**. Vedere **[Monitoraggio e Log](Monitoring.md)**.

### Onboarding: l'inserimento del codice di attivazione restituisce un errore

Se il codice di attivazione viene rifiutato, verificare nell'ordine:

- **Codice errato**: non è stato copiato per intero (copia-incolla troncato, uno spazio in più o un carattere mancante). Copiare di nuovo il codice completo e reinserirlo.
- **Codice già utilizzato**: è già stato consumato da un onboarding precedente. Richiedere un nuovo codice.
- **WireGuard / connettività verso HIN**: il tunnel `irisagent` non è attivo, quindi il codice non può essere convalidato presso HIN. Vedere *Tunnel WireGuard inattivo* sopra (`/usr/share/stargate-deployment/docker-compose/scripts/health-check.sh -v`, `docker logs stargate-irisagent`).
- **Nessun dominio associato alla registrazione**: alla registrazione HIN del cliente non è associato alcun dominio, quindi non c'è nulla da attivare. Il problema viene risolto sul lato HIN.

### Onboarding: codice di attivazione accettato, ma nessun dominio elencato

**Causa più probabile: il tunnel WireGuard non è stabilito**, di solito a causa di un **IP pubblico errato** o di una **porta del firewall non aperta**. Senza il tunnel l'appliance non può recuperare l'elenco dei domini da HIN.

- Verificare che `SERVER_STATIC_IP` in `customer-config.sh` corrisponda all'IP pubblico effettivo.
- Verificare che **`19818` (UDP *e* TCP)** sia aperta in entrata e in uscita.
- Verificare che il peer sia registrato sul lato HIN per questo IP (passaggio a cura dell'Assistenza).
- `docker logs stargate-irisagent` dovrebbe mostrare un handshake recente; in caso contrario, risolvere prima il problema del tunnel (vedere *Tunnel WireGuard inattivo* sopra).

### Modifica dell'indirizzo IP del server (solo configurazione iniziale)

Se al primo avvio l'IP del server era errato o non impostato, eseguire un reset pulito e reinstallare:

```bash
/usr/share/stargate-deployment/docker-compose/scripts/purge.sh                 # destroys ALL data - see warning below
nano /var/data/vereign/customer-config.sh    # set SERVER_STATIC_IP=<NEW IP>
/usr/share/stargate-deployment/docker-compose/scripts/install.sh
```

Il certificato TLS e diversi URL dei servizi vengono derivati dall'IP al primo avvio, quindi un purge seguito da una reinstallazione li rigenera per il nuovo indirizzo.

!!! danger "Solo prima dell'onboarding"
    `purge.sh` **elimina definitivamente tutti i dati**: database, Vault e chiavi S/MIME. L'operazione è sicura **solo su un'appliance nuova, non ancora sottoposta a onboarding**. **Non eseguire mai `purge.sh` per cambiare l'IP di un gateway in produzione o già sottoposto a onboarding**: causa la perdita di dati e rende la posta non più decifrabile. Per cambiare l'IP in produzione, contattare l'Assistenza.

---

## 5. Archiviazione e disco

```bash
df -h /                              # is the disk full?
docker system df                     # space used by images / containers / volumes
du -sh /var/lib/docker/volumes/*     # per-volume usage (Postgres, SeaweedFS, Loki, ...)
```

- I log dei container hanno un limite massimo (json-file, 100 MB × 5 per container), quindi non dovrebbero riempire il disco; immagini e volumi, invece, possono farlo.
- Per liberare spazio in sicurezza: `docker image prune -af` (rimuove solo le immagini non utilizzate). Evitare `docker system prune --volumes`, che elimina i volumi dei dati.
- L'archiviazione a oggetti è gestita da **SeaweedFS** (`stargate-seaweedfs`): `docker logs stargate-seaweedfs --tail 50`.

---

## 6. Risorse della VM

```bash
free -h                              # memory (min 8 GB)
nproc                                # CPUs (min 4)
docker stats --no-stream             # per-container CPU/RAM
uptime                               # load average
```

Le metriche dell'host vengono esportate anche per Prometheus su **`:9100/metrics`** (vedere [Monitoraggio](Monitoring.md#metriche-prometheus)). Se la macchina usa pesantemente lo swap o è al limite delle risorse, è prevedibile che gli healthcheck risultino instabili e gli aggiornamenti lenti.

---

## 7. Rete e porte

Verifica rapida della raggiungibilità delle principali porte in entrata:

```bash
for p in 25 443 8180 8190 19818; do nc -zv <this-server-ip> $p; done
```

| Porta | Servizio | Direzione |
| ------ | --------- | ----------- |
| `25` | Stalwart SMTP (posta in entrata) | in entrata |
| `443` | Dashboard (HTTPS) | in entrata |
| `8180` | Keycloak | in entrata |
| `8190` | Dozzle (opzionale) | in entrata |
| `19818` | WireGuard (UDP **e** TCP) | in entrata / in uscita |

È necessario l'accesso in uscita al registry dei container, all'autorità di certificazione S/MIME (tramite il tunnel WireGuard) e a qualsiasi istanza Loki remota configurata. La tabella completa delle porte si trova nella **[home page](index.md)** e nella **[panoramica delle applicazioni](Applications.md)**.

---

## 8. Azioni di ripristino

In ordine dal meno al più invasivo:

```bash
docker compose up -d <service>       # recreate one stuck service
sudo systemctl restart stargate      # restart the whole stack (via start.sh)
/usr/share/stargate-deployment/docker-compose/scripts/stop.sh  &&  /usr/share/stargate-deployment/docker-compose/scripts/start.sh
```

!!! warning "Backup e ripristino distruttivo"
    `/usr/share/stargate-deployment/docker-compose/scripts/backup.sh` e `/usr/share/stargate-deployment/docker-compose/scripts/restore.sh` gestiscono il backup e il ripristino dei dati. `/usr/share/stargate-deployment/docker-compose/scripts/purge.sh` **elimina tutti i dati** (database, Vault, archiviazione) per una reinstallazione pulita: utilizzarlo solo come ultima risorsa e solo disponendo di un backup aggiornato. Dettagli: [Configurazione avanzata di Docker](Docker-advanced.md).

---

## 9. Quando contattare l'Assistenza

Se, dopo i passaggi precedenti, il controllo dello stato segnala ancora errori, aprire un ticket tramite **[Assistenza / Contattaci](Support.md)** includendo:

- La **versione dell'appliance** (`/usr/share/stargate-deployment/docker-compose/scripts/gather-app-versions.sh`) e il **nome del cliente**.
- L'**output del controllo dello stato** (`/usr/share/stargate-deployment/docker-compose/scripts/health-check.sh -v`).
- Il link al **pacchetto di log** generato da `/usr/share/stargate-deployment/docker-compose/scripts/send-logs-to-support.sh` (vedere [Fornire log all'Assistenza](Docker-advanced.md#fornire-log-al-supporto)).
- Cosa si stava facendo quando si è verificato il problema, ed eventuali screenshot.

## Aggiornamento di un'istanza Verimesh

Le istruzioni seguenti descrivono come aggiornare un'istanza Verimesh dalla versione v0.5.1 alla versione v0.5.3.

*Nota:* è necessario accedere alla VM con l'account amministratore Linux.

### Procedura di aggiornamento

1. Modificare il file `.env` e aggiornare la versione dell'ops-agent a v0.0.3.
2. Modificare la configurazione del cliente e aggiornare anche lì la versione dell'ops-agent a v0.0.3.
3. Passare al branch main: `git checkout main`
4. Scaricare le ultime modifiche: `git pull`
5. Aggiornare il container ops-agent: `docker compose up -d ops-agent`
6. Accedere alla dashboard.
7. Aprire Settings.
8. Nella sezione Update in fondo alla pagina, inserire la versione di destinazione (v0.5.3) e avviare l'aggiornamento.

## Configurazione di Keycloak dopo l'aggiornamento

Nota: queste istruzioni valgono se si utilizzava l'immagine VM v0.5.1 e si è poi eseguito l'aggiornamento a una versione più recente.

Dopo l'ultimo aggiornamento di Keycloak, una modifica incompatibile (breaking change) fa sì che gli utenti autenticati vengano reindirizzati inaspettatamente alla pagina di login quando accedono a determinati percorsi dell'applicazione (ad es. Peers, Peer Certificates).

Per risolvere il problema, occorre completare la seguente configurazione manuale nell'*interfaccia di Keycloak*.

### Procedura di risoluzione

1. Aprire Keycloak nel browser all'indirizzo `https://<VM IP address>:8180/admin/master/console/`
    - La **porta `:8180` è obbligatoria**: Keycloak è servito sulla porta 8180. Aprendo l'IP senza porta si raggiunge invece la dashboard (`:443`), che reindirizza al login del realm **stargate**, in cui l'utente admin non esiste (è la causa abituale degli errori «invalid username or password» o «wrong realm» in questo punto).
    - Accedere al realm **master** (il percorso `/admin/master/console/` lo seleziona) con il nome utente `admin` (il valore di `KEYCLOAK_ADMIN_USER`, in minuscolo) e il valore di `KEYCLOAK_ADMIN_PASSWORD` contenuto nel file `/var/data/vereign/.env` della macchina (da leggere dalla console Linux).

2. Nella console di amministrazione, passare dal realm **master** al realm **stargate** tramite il selettore dei realm (in alto a sinistra).
3. Aprire Clients → dashboard.
4. Aprire la scheda Client scopes → fare clic su dashboard-dedicated.
5. Selezionare Configure a new mapper → Audience.
6. Impostare la configurazione seguente:
    - Name: apisix-audience
    - Included client audience: apisix (selezionare dal menu a tendina)
    - Included custom audience: (lasciare vuoto)
    - Add to access token: On
    - Add to token introspection: On
    - Add to ID token / lightweight token: Off

7. Fare clic su Save.

 <br> ![keycloak-console](assets/troubleshooting/keycloak-update.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }


# Reimpostare la password di un utente Stargate in Keycloak

Seguire i passaggi riportati di seguito per reimpostare la password di un utente Stargate tramite la console di amministrazione di Keycloak.

1. **Connettersi alla VM HIN Gateway**
    - Aprire la console della VM oppure connettersi alla VM HIN Gateway tramite SSH.

2. **Recuperare le credenziali dell'amministratore di Keycloak**
    - Aprire il file `/var/data/vereign/.env`.
    - Individuare le seguenti variabili:
        - `KEYCLOAK_ADMIN_USER`
        - `KEYCLOAK_ADMIN_PASSWORD`

3. **Aprire la console di amministrazione di Keycloak**
    - In un browser, aprire l'indirizzo: `http://<VM-IP>:8180/admin/master/console`
    - Sostituire `<VM-IP>` con l'indirizzo IP della VM HIN Gateway.

4. **Accedere a Keycloak**
    - Inserire il nome utente e la password dell'amministratore recuperati dal file `.env`.
    - Mantenere invariata la password dell'amministratore. Se la si modifica comunque, è necessario conservare la nuova password in modo sicuro.

5. **Selezionare il realm Stargate**
    - Nel selettore dei realm della console di amministrazione di Keycloak, selezionare **Stargate**.

6. **Trovare l'utente**
    - Aprire **Users**.
    - Cercare e selezionare l'utente Stargate di cui reimpostare la password.

7. **Reimpostare la password dell'utente**
    - Selezionare l'opzione per reimpostare la password dell'utente.
    - Inserire la nuova password e confermare la modifica.

**Non modificare né reimpostare la password dell'amministratore di Keycloak nell'ambito di questa procedura.**
Qualsiasi modifica della password dell'amministratore può bloccare Keycloak al punto che nessuno riesca più ad accedervi.


# Richiesta del codice di attivazione

Per installare o reinstallare un'istanza HIN Gateway è necessario un codice di attivazione, che può essere fornito dall'Assistenza HIN.


!!! warning "La reimpostazione del codice di attivazione interrompe la connessione con il peer"
    La reimpostazione del codice di attivazione di un'istanza attiva elimina la connessione peer WireGuard del cliente.

    Se si richiede la reimpostazione per l'istanza cliente sbagliata, la connessione di quell'istanza attiva verrà eliminata e interrotta. Prima di richiedere una reimpostazione, verificare con attenzione l'istanza esatta e confermare tutti i domini ospitati su di essa.
