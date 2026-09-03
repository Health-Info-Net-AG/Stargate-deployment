# Troubleshooting e diagnostica

Una guida strutturata alla diagnosi di un'appliance HIN Gateway via riga di comando: aspetti da verificare, posizione dei log e misure di ripristino sicuro.

!!! info "Dove eseguire questi comandi"
    Eseguire tutto ciò che segue dalla **directory di deployment** - la cartella contenente `docker-compose.yml` e `scripts/` (nelle immagini VM si tratta generalmente di `/usr/share/stargate-deployment/docker-compose`, oppure la directory in cui è stata effettuata l'installazione). Tutti i comandi `docker compose` e `./scripts/*` presuppongono questa directory di lavoro.

    ```bash
    cd /usr/share/stargate-deployment/docker-compose   # adjust to your install path
    ```

---

## 1. Per iniziare: controllo dell'integrità

Un unico comando riassume l'intera appliance:

=== "Quick"

    ```bash
    ./scripts/health-check.sh
    ```

=== "Verbose"

    ```bash
    ./scripts/health-check.sh -v
    ```

Segnala «superato / non superato» per: **container** (in esecuzione / integri), **liveness** endpoint (smimekeys, policy, irisagent, mxengine), stato di blocco **Vault**, connettività e database **PostgreSQL**, **SeaweedFS**, tunnel **WireGuard** e handshake tra peer, **Stalwart** MTA (porte 25 / 10026), endpoint metriche **Prometheus** e **disco/memoria**.

!!! tip
    Eseguire questo comando per primo. Una singola riga `FAIL` di solito rimanda direttamente alla sezione sottostante.

---

## 2. Posizione dei log

| Livello | Comando | Visualizzazione |
| ------- | --------- | --------------- |
| Avvio / prima installazione / avvio automatico | `sudo journalctl -u stargate -n 200 --no-pager` | Il servizio systemd che esegue `start.sh` all'avvio e durante l'installazione al primo avvio |
| Aggiornamenti | `cat ../update.log` (cartella root di deployment, un livello sopra `docker-compose/`) | Output dell'ultimo `update.sh` avviato da dashboard/host |
| Un unico servizio | `docker logs stargate-<service> --tail 100` | ad es. `stargate-dashboard`, `stargate-mxengine`, `stargate-keycloak` |
| Seguire un servizio live | `docker logs -f stargate-mxengine` | In tempo reale |
| Tutti i container live | `docker ps -a --format '{{.Names}}' \| xargs -I{} sh -c 'docker logs --timestamps -f {} 2>&1 \| sed "s/^/[{}] /"'` | Accorpati, con il nome del container come prefisso |
| Visualizzatore log web | Dozzle su `https://<SERVER_IP>:8190` (login Keycloak) | Consente di consultare tutti i log dei container in un'interfaccia utente |

Per inviare i log all'Assistenza HIN, utilizzare lo script di caricamento e condividere il link generato - si veda **[Fornire log all'Assistenza](Docker-advanced.md#fornire-log-al-supporto)**:

```bash
./scripts/send-logs-to-support.sh --all          # or --since 1h  / --tail 500
```

---

## 3. Container che non si avviano o si riavviano

```bash
docker compose ps -a --format 'table {{.Service}}\t{{.Status}}'
```

Leggere la colonna `Status`:

| Status | Significato | Azione |
| -------- | --------- | -------- |
| `Up ... (healthy)` | In esecuzione, correttamente | - |
| `Up ...` (senza controllo dell'integrità) | In esecuzione; nessun controllo dell'integrità definito | Verificare i `docker logs` se si sospetta un problema |
| `Restarting` | Crash-looping | `docker logs stargate-<svc>` - correggere l'errore alla radice (config, secret, dipendenza) |
| `Exited (0)` | Inizializzazione one-shot conclusa correttamente (ad es. `*-init`, `vault-data-fixer`) | Normale |
| `Exited (1+)` | Fallito | `docker logs stargate-<svc>` - le ultime righe indicano il motivo |
| `Created` | Mai avviato - una dipendenza non è disponibile | Verificare da cosa dipende (`depends_on`, di solito Postgres/Vault); risolvere prima quello |

Riavviare un singolo servizio (in modo sicuro e non distruttivo):

```bash
docker compose up -d <service>          # recreate one service
docker compose restart <service>        # just restart it
```

!!! note "Ordine di avvio"
    I servizi attendono le proprie dipendenze (`depends_on` + controlli dell'integrità). Durante un riavvio completo, brevi righe come `connection refused` / `database system is starting up` mentre Postgres/Vault si avviano sono **normali** e scompaiono entro un minuto.

---

## 4. Diagnosi in base ai sintomi

### Dashboard o Keycloak non si caricano / non è possibile effettuare l'accesso

- Entrambi sono esposti tramite Caddy: la **Dashboard** sulla porta `:443`, **Keycloak** sulla porta `:8180`.
- Controllare l'intera catena: `docker logs stargate-caddy`, `stargate-dashboard`, `stargate-keycloak`, `stargate-apisix`.
- Keycloak deve essere **integro** affinché la dashboard funzioni: `docker compose ps keycloak`.
- È normale che nel browser compaia un avviso TLS (self-signed cert) - accettare e proseguire.
- Gli errori nei reindirizzamenti durante l'accesso indicano generalmente che l'URL pubblico non corrisponde alla modalità con cui si raggiunge l'appliance - verificare che `KEYCLOAK_PUBLIC_URL` / `DASHBOARD_PUBLIC_URL` in `.env` puntino effettivamente all'IP o all'host realmente utilizzato.

### Tunnel WireGuard inattivo / errore nell'emissione del certificato

È il problema più comune - **i certificati non vengono emessi quando il tunnel è inattivo**, pertanto occorre sempre risolvere prima il problema del tunnel.

```bash
./scripts/health-check.sh -v      # shows WireGuard peer + handshake status
docker logs stargate-irisagent | grep -iE "handshake|peer|cert|wireguard"
```

- Verificare che il firewall consenta **`19818` (UDP *e* TCP)** in entrata e in uscita.
- Verificare che il peer sia registrato sul lato HIN (passaggio a carico dell'Assistenza) - occorre fornire la chiave pubblica WG, `DEPLOYMENT_NAME`, `SERVER_STATIC_IP`, `WG_INTERFACE_PORT`.
- Non appena il tunnel mostra un handshake recente, riprovare a emettere il certificato dalla dashboard.

### Vault bloccato o inizializzazione fallita

```bash
docker compose exec vault vault status        # look for "Sealed: false"
docker logs stargate-vault-init
```

- Il **Vault** deve essere **sbloccato** affinché smimekeys/mxengine/policy funzionino. Le chiavi si trovano in `secrets/vault-keys.json`.
- Se `vault-init` è terminato con un codice di uscita diverso da zero, il file delle chiavi potrebbe mancare o essere danneggiato - controllare i relativi log; rilanciando `./scripts/init-vault.sh` si tenta un nuovo sblocco.

!!! danger "Non eliminare `secrets/vault-keys.json`"
    Perdere il file significherebbe perdere l'accesso a tutti i secret memorizzati. Eseguire un backup.

### PostgreSQL / connettività al database

```bash
docker compose exec postgres pg_isready -U postgres
docker logs stargate-postgres --tail 50
```

- È normale che `the database system is starting up (57P03)` si verifichi subito dopo un riavvio - i servizi si riconnettono automaticamente.
- Gli errori di autenticazione ricorrenti indicano solitamente che `POSTGRES_PASSWORD` nel file `.env` non corrisponde più a quello memorizzato nel volume dati - consultare le note relative agli aggiornamenti e ai secret, ed evitare di modificarlo manualmente.

### La posta non viene recapitata

- La **posta in entrata** arriva sulla porta `:25` (Stalwart). Molti fornitori di servizi cloud **bloccano la porta 25** per impostazione predefinita:

    ```bash
    nc -zv <this-server-ip> 25          # from an external host
    docker logs stargate-stalwart --tail 100
    ```

    Se la porta `25` è bloccata, bisogna richiedere un'eccezione al proprio provider.
- **Posta in uscita / sealing**: segue il percorso Stalwart → **mxengine** (`:8084` callback di blocco, SMTP `:1587`): `docker logs stargate-mxengine`.
- **I loop di posta** si manifestano con la ripetizione dello stesso messaggio - verificare che il record MX del proprio dominio non venga risolto nell'indirizzo IP di questa stessa appliance.
- Vedere **[Configurazione relay di posta](Mail-relay-setup.md)** e **[Configurazione DNS](DNS-setup.md)** per il routing previsto.

### Aggiornamento fallito

```bash
docker logs stargate-ops-agent --tail 40      # the update orchestrator
cat ../update.log                             # the update script output
```

- L'ops-agent recupera il manifesto di release, scrive le versioni nel file `customer-config.sh`, quindi esegue lo script `update.sh` sull'host.
- Al termine, confermare le versioni applicate: `./scripts/gather-app-versions.sh` (oppure verificare i tag delle immagini con `docker compose ps`).
- Se un servizio si blocca dopo un aggiornamento, eseguire `docker compose up -d <service>` per ricrearlo.

**L'aggiornamento si avvia ma non succede nulla (aggiornamento da una versione precedente).** Se il log dell'ops-agent si blocca su `pulling deployment repo ...` e l'aggiornamento non procede, il repository sulla VM molto probabilmente presenta **modifiche locali a un file monitorato** (solitamente un `docker-compose.yml` modificato manualmente). Questo fa sì che il `git checkout` dell'ops-agent si rifiuti di essere eseguito, e l'aggiornamento resta bloccato. Forzare il ripristino del repository all'ultima revisione, quindi ripetere l'aggiornamento. Git è l'unica fonte affidabile; questa operazione elimina esclusivamente le modifiche locali ai file **monitorati** - `customer-config.sh`, `.env` e `secrets/` sono esclusi tramite `.gitignore` e vengono preservati:

```bash
cd /usr/share/stargate-deployment
git fetch origin
git checkout -f main
git reset --hard origin/main
sed -i 's/^OPS_AGENT_VERSION=.*/OPS_AGENT_VERSION="v0.0.3"/' docker-compose/customer-config.sh   # v0.0.3 or newer
cd docker-compose
./scripts/update.sh
```

`update.sh` rigenera il file `.env`, scarica le immagini e ricrea i servizi interessati - **non** è necessario riavviare HIN Gateway manualmente. Al termine, ripetere l'aggiornamento dalla dashboard: a questo punto procederà correttamente.

!!! warning
    Non utilizzare `git pull` in questo caso. Su un working tree con modifiche locali il comando si interrompe con l'errore "local changes would be overwritten", il che costringe a un percorso alternativo con `git stash`, conflitti di merge o un ripristino manuale. La sequenza `git checkout -f` + `git reset --hard` riportata sopra evita completamente questo problema ed è il metodo sicuro e ripetibile per riportare il repository allo stato aggiornato.

### Dozzle (log viewer) non raggiungibile

- L'URL è `https://<SERVER_IP>:8190`; richiede il **login a Keycloak** (stesso realm della dashboard) tramite oauth2-proxy.
- Funziona solo quando `DOZZLE_ENABLED="true"`. Verificare con: `docker compose ps dozzle oauth2-proxy`.
- Assicurarsi che il firewall consenta il traffico in entrata sulla porta **`:8190`**. Vedere **[Monitoraggio e Log](Monitoring.md)**.

---

## 5. Archiviazione e disco

```bash
df -h /                              # is the disk full?
docker system df                     # space used by images / containers / volumes
du -sh /var/lib/docker/volumes/*     # per-volume usage (Postgres, SeaweedFS, Loki, ...)
```

- I log dei container sono soggetti a un limite massimo (file json, 100 MB × 5 per container), quindi non dovrebbero saturare il disco - a differenza di immagini e volumi.
- Per liberare spazio in sicurezza: `docker image prune -af` (rimuove solo le immagini non utilizzate). Evitare `docker system prune --volumes` - elimina i volumi con i dati.
- L'archiviazione a oggetti è **SeaweedFS** (`stargate-seaweedfs`): `docker logs stargate-seaweedfs --tail 50`.

---

## 6. Risorse VM

```bash
free -h                              # memory (min 8 GB)
nproc                                # CPUs (min 4)
docker stats --no-stream             # per-container CPU/RAM
uptime                               # load average
```

Le metriche dell'host vengono esportate anche per Prometheus sulla porta **`:9100/metrics`** (vedere [Monitoraggio](Monitoring.md#metriche-prometheus)). Se l'appliance è in swap o al limite delle risorse, è probabile che i controlli dell'integrità presentino fluttuazioni e che gli aggiornamenti risultino lenti.

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

È necessario l'accesso in uscita al registro dei container, all'autorità di certificazione S/MIME (tramite il tunnel WireGuard) e a qualsiasi istanza remota di Loki configurata. Per la tabella completa delle porte, vedere la **[home page](index.md)** e la **[panoramica delle applicazioni](Applications.md)**.

---

## 8. Misure di ripristino

In ordine crescente di impatto:

```bash
docker compose up -d <service>       # recreate one stuck service
sudo systemctl restart stargate      # restart the whole stack (via start.sh)
./scripts/stop.sh  &&  ./scripts/start.sh
```

!!! warning "Backup e ripristino distruttivo"
    `./scripts/backup.sh` e `./scripts/restore.sh` gestiscono il backup e il ripristino dei dati. Lo script `./scripts/purge.sh` **elimina tutti i dati** (database, Vault, archiviazione) per consentire una reinstallazione pulita - utilizzare solo come ultima risorsa e solo se si dispone di un backup recente. Dettagli: [Configurazione avanzata di Docker](Docker-advanced.md).

---

## 9. Quando contattare l'Assistenza

Se, dopo aver seguito i passaggi sopra indicati, il controllo dell'integrità continua a segnalare errori, aprire un ticket tramite **[Assistenza / Contattaci](Support.md)** e includere:

- La **versione dell'appliance** (`./scripts/gather-app-versions.sh`) e il **nome del cliente**.
- L'**output del controllo dell'integrità** (`./scripts/health-check.sh -v`).
- Un **link al pacchetto di log** generato da `./scripts/send-logs-to-support.sh` (vedere [Fornire log all'Assistenza](Docker-advanced.md#fornire-log-al-supporto)).
- Cosa si stava facendo quando si è verificato il problema, ed eventuali screenshot.

## Aggiornamento dell'istanza Verimesh

Le seguenti istruzioni descrivono come aggiornare un'istanza Verimesh dalla versione v0.5.1 alla versione v0.5.3.

*Nota:* è necessario effettuare l'accesso alla VM utilizzando l'account amministratore Linux.

### Procedura di aggiornamento

1. Modificare il file .env e aggiornare la versione di ops-agent a v0.0.3.
2. Modificare la configurazione del cliente e aggiornare anche lì la versione di ops-agent a v0.0.3.
3. Passare al branch main: `git checkout main`
4. Scaricare le ultime modifiche: `git pull`
5. Aggiornare il container ops-agent: `docker compose up -d ops-agent`
6. Accedere alla Dashboard.
7. Accedere alle Impostazioni.
8. Nella sezione Update in fondo alla pagina, inserire la versione di destinazione (v0.5.3) e avviare la procedura di aggiornamento.

## Configurazione aggiornata di Keycloak

Nota: le presenti istruzioni sono valide se si utilizza l'immagine VM v0.5.1 e si è successivamente eseguito l'aggiornamento a una versione più recente.

In seguito all'ultimo aggiornamento di Keycloak, un breaking change fa sì che gli utenti autenticati vengano reindirizzati in modo imprevisto alla pagina di login quando accedono a determinati percorsi dell'applicazione (ad es. Peers, Peer Certificates).

Per risolvere il problema, occorre completare la seguente configurazione manuale nella *interfaccia utente di Keycloak*.

### Procedura di risoluzione

1. Aprire Keycloak nell'ambiente e inserire l'URL - `<VM IP address>/admin/master/console/`
    Nome utente: Admin
    Password: recuperare la password amministratore dal file .env della macchina (è necessario effettuare l'accesso alla console Linux)

2. Console Admin - modificare il realm in → realm stargate:
3. Selezionare Clients → dashboard
4. Accedere alla scheda Client scopes → cliccare su dashboard-dedicated
5. Selezionare Configure a new mapper → Audience
6. Impostare le seguenti configurazioni:
    - Name: apisix-audience
    - Included client audience: apisix (selezionare dal menu a tendina)
    - Included custom audience: (lasciare vuoto)
    - Add to access token: On
    - Add to token introspection: On
    - Add to ID token / lightweight token: Off

7. Cliccare su Save

 <br> ![keycloak-console](assets/troubleshooting/keycloak-update.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
