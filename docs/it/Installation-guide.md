# HIN Gateway: Guida tecnica per la nuova installazione e la migrazione

## Introduzione

Questo documento fornisce una guida completa al processo di installazione tecnica e di migrazione verso il nuovo HIN Gateway ("HIN Gateway Appliance").

La guida è destinata ai clienti HIN, agli amministratori IT e agli ingegneri di sistema responsabili del deployment e della configurazione del nuovo HIN Gateway e, ove applicabile, della migrazione dal Mail Gateway (MGW) esistente alla nuova soluzione.

L'HIN Gateway è una soluzione di gateway email sicuro che consente una comunicazione affidabile, crittografata e basata su policy all'interno del HIN Trust Circle. Agisce come intermediario centrale tra le infrastrutture email interne e i partner di comunicazione esterni, garantendo che tutto il traffico email venga trasmesso in modo sicuro, sia conforme alle policy dell'organizzazione e soddisfi gli standard di sicurezza HIN.

## Panoramica del flusso di posta

- **Le email in entrata** vengono instradate tramite l'HIN Gateway, dove vengono validate, decriptate (se necessario) e verificate rispetto alle policy di fiducia e sicurezza prima di essere inoltrate al server di posta interno.
- **Le email in uscita** vengono inviate dai sistemi interni all'HIN Gateway, dove vengono applicati crittografia, routing e applicazione delle policy prima di essere trasmesse ai destinatari esterni.
- **La comunicazione tra gateway HIN** è protetta da certificati peer e tunnel WireGuard, garantendo una comunicazione affidabile tra i domini.

## Processo di installazione e migrazione

La procedura strutturata e passo-passo descritta in questo documento copre sia le nuove installazioni dell'HIN Gateway sia le migrazioni da un HIN Mail Gateway (MGW) esistente. A seconda dello scenario di deployment, alcuni passaggi potrebbero applicarsi solo alle migrazioni.

1. Preparazione e pianificazione del deployment, incluso il piano di fallback ove applicabile
2. Installazione e configurazione dell'HIN Gateway
3. Attivazione del dominio e validazione del certificato
4. Integrazione nell'ambiente di posta esistente e configurazione del routing
5. Test, transizione in produzione e validazione post-deployment
6. Per le migrazioni: disattivazione del MGW esistente dopo una validazione riuscita

!!! info "Migrazione"
    L'obiettivo di HIN è garantire un deployment sicuro, fluido e completamente validato, con un impatto minimo sulle operazioni e una continuità ininterrotta dei servizi email.
     Negli scenari di migrazione, il MGW esistente dovrebbe rimanere disponibile come opzione di fallback finché l'HIN Gateway non sia stato validato con successo in produzione. Dovrebbe essere dismesso solo una volta completata la migrazione e confermato un funzionamento stabile.

## Domande frequenti

!!! question "Posso eseguire l'installazione o la migrazione autonomamente?"
    Sì, l'installazione o la migrazione possono essere completate interamente dal cliente.

    Per lo scenario di migrazione, l'unica eccezione è il **"Passo 1.3 - Esportazione delle chiavi private"**. Per motivi di sicurezza e per mantenere al sicuro la tua chiave privata, devi contattare il Supporto HIN o partecipare alla chiamata di migrazione pianificata per ricevere il codice necessario a esportare la chiave privata dal Mail Gateway attualmente in funzione.


    Se l'installazione o la migrazione non possono essere completate con successo, partecipa alla chiamata di supporto pianificata con i nostri ingegneri.

!!! question "Ci sarà un'interruzione nella consegna delle email durante il processo di configurazione?"
    **Migrazione:** tra il **"Passo 1.5 - Spegnimento del MGW VM esistente"** e il **"Passo 18 - Configurazione del server di posta"**, tutte le email verranno messe in coda sul server di posta. Una volta completato il "Passo 18 - Configurazione del server di posta", le email in coda verranno inviate o consegnate alla cassetta postale.

    **Nuova installazione:** durante la configurazione delle regole del flusso email, tutte le email verranno messe in coda sul server di posta. Una volta completato il "Passo 18 - Configurazione del server di posta", le email in coda verranno inviate o consegnate alla cassetta postale.

!!! question "Verranno perse email durante l'installazione e la migrazione?"
    No, nessuna email andrà persa durante l'installazione e la migrazione. Alcune email potrebbero subire un ritardo.

## Panoramica dei passaggi di installazione

| Passo | Argomento | Responsabilità | Migrazione | Nuova installazione |
| :--: | :---- | :------------: | :--: | :---- |
| 0 | Verifica prerequisiti | Cliente | Sì | Sì |
| 1.1 | Smoke test | Cliente | Sì | N/A |
| 1.2 | Backup del MGW esistente | Cliente | Sì | N/A |
| 1.3 | Esportazione delle chiavi private | Cliente / HIN | Sì | N/A |
| 1.4 | Piano di contingenza / scenario di fallback | Cliente | Sì | N/A |
| 1.5 | Spegnimento del MGW VM esistente | Cliente | Sì | N/A |
| 2 | WireGuard | Cliente | Sì | Sì |
| 3 | Selezione VM di destinazione | Cliente | Sì | Sì |
| 4 | Caricamento dell'immagine VM | Cliente | Sì | Sì |
| 5 | Connessione di rete alla VM | Cliente | Sì | Sì |
| 6 | Accesso tramite browser | Cliente | Sì | Sì |
| 7 | Inserimento codice di attivazione | Cliente | Sì | Sì |
| 8 | Configurazione rete mesh | Cliente | Sì | Sì |
| 9 | Creazione rete mesh sicura | Cliente | Sì | Sì |
| 10 | Accesso a Keycloak | Cliente | Sì | Sì |
| 11 | Aggiornamento password | Cliente | Sì | Sì |
| 12 | Aggiornamento informazioni account | Cliente | Sì | Sì |
| 13 | Configurazione iniziale e setup domini | Cliente | Sì | Sì |
| 14 | Configurazione trasporto posta | Cliente | Sì | Sì |
| 15 | Configurazione intestazioni whitelist | Cliente | Sì | Sì |
| 16 | Certificati peer | HIN | Sì | Sì |
| 17 | Validazione certificati peer | Cliente | Sì | Sì |
| 18 | Configurazione server di posta | Cliente | Sì | Sì |
| 19 | Test e validazione | Cliente | Sì | Sì |
| 20 | Modifica della password della VM | Cliente | Sì | Sì |
| 21 | Disattivazione del MGW esistente | Cliente | Sì | N/A |
| Allegato 1 | Backup e ripristino delle impostazioni dell'appliance | Cliente | Sì | N/A |

## Passaggi dettagliati

### Passo 0 - Verifica prerequisiti

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Assicurati che tutti i passaggi preparatori necessari siano stati completati prima dell'inizio delle attività di migrazione dell'HIN Gateway.

I seguenti elementi devono essere disponibili o confermati prima dell'installazione:

- **Le credenziali ti saranno fornite da HIN**
    - Credenziale VM
    - Credenziale Keycloak
    - Codice di attivazione

- **Esportazione della chiave privata**
    **Nota:** applicabile solo in caso di migrazione
    - Se stai lavorando su una macchina Windows che ha accesso alla VM del Mail Gateway tramite la porta 22, possiamo supportarti durante la chiamata nell'abilitare l'esportazione della chiave privata dal MGW.
    - Se non hai accesso a tale macchina, contatta il Supporto HIN via email o telefono (<support@hin.ch> / 0848 830 740) per aiutarti a stabilire una connessione di supporto tramite Amministrazione sistema → Connessione di supporto → Connetti.
- **Scarica l'ultima** versione dell'[immagine VM](vm/VM-Catalog.md)
- **Firewall**:
    - Consentire il traffico: da qualsiasi origine a HIN Gateway e da HIN Gateway a qualsiasi destinazione
        - WireGuard: fare riferimento a [Requisiti del server - Accesso alla rete in ingresso](./index.md#accesso-di-rete-in-entrata-il-firewall-deve-consentire):
            - Configurare la porta WireGuard `19818` (TCP/UDP) nel firewall
                - Traffico in ingresso e in uscita
    - Consentire il traffico: macchina amministrativa → VM HIN Gateway
        - Requisiti per l'installazione:
            - Porta HTTPS `443`
                - Traffico in ingresso e in uscita
            - Porta Keycloak `8180`
                - Traffico in ingresso e in uscita
        - Requisiti per la risoluzione dei problemi (opzionale, necessario per visualizzare i log e modificare tutti i parametri):
            - Porta SSH `22`
                - Traffico in ingresso e in uscita
            - Porta Dozzle `8190`
                - Traffico in ingresso e in uscita
- **L'accesso DHCP** dovrebbe essere disponibile per il "[Passo 5 - Connessione di rete alla VM](#passo-5-connessione-di-rete-alla-vm)" (raccomandato).
- **Requisiti di backup**: vedere "Allegato 1 - Backup e ripristino delle impostazioni dell'appliance". **Nota:** applicabile solo in caso di migrazione
- Nota: applicabile solo in caso di migrazione. Conferma che il MGW esistente **non** verrà eliminato fino al completamento dell'accettazione.
- Accesso a DNS, connettori del server di posta, regole di trasporto e impostazioni di relay.

!!! info "Perché WireGuard?"
    La porta WireGuard assolve due importanti funzioni:

    1. L'HIN Gateway utilizza questa porta per ottenere certificati peer dalla CA HIN.
    2. Utilizza questa porta per stabilire un tunnel sicuro verso altri HIN Gateway, attraverso il quale avviene lo scambio sicuro di dati (es. traffico email).

!!! tip "Esportazione della chiave privata" - Applicabile solo in caso di migrazione
    Se stai lavorando su una macchina Windows che ha accesso alla VM del Mail Gateway tramite la porta 22, possiamo supportarti durante la chiamata nell'abilitare l'esportazione della chiave privata dal MGW.

    Se non hai accesso a tale macchina, contatta il Supporto HIN via email o telefono (**support@hin.ch** / **0848 830 740**) per aiutarti a stabilire una connessione di supporto tramite **Amministrazione sistema → Connessione di supporto → Connetti**.

### Passo 1.1 - Smoke test

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

!!! info Applicabile solo in caso di migrazione
    Questo passaggio si applica solo alle migrazioni a dominio singolo e multiplo

Invia email di test ai seguenti destinatari, utilizzando cassette postali a cui hai accesso in modo da poter verificare che la consegna avvenga con successo:

- Un indirizzo email HIN o un indirizzo email all'interno del tuo dominio della Comunità HIN, ad esempio: `user@hin.ch`
- Un indirizzo email esterno al di fuori della Comunità HIN, ad esempio: Bluewin, Gmail, Yahoo o GMX

Per il destinatario esterno, invia una email dalla Comunità HIN con **(confidenziale) inserito nell'oggetto**.

Testa il flusso di posta in entrambe le direzioni:

- Dal dominio HIN affidabile all'indirizzo email esterno
- Dall'indirizzo email esterno alla Comunità HIN

Verifica che tutte le email di test vengano consegnate con successo e che oggetto, contenuto del messaggio e allegati (se presenti) vengano ricevuti correttamente.

### Passo 1.2 - Backup del MGW esistente

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

!!! info Applicabile solo in caso di migrazione
    Questo passaggio si applica solo alle migrazioni a dominio singolo e multiplo

Crea un backup dell'appliance MGW esistente e assicurati che la VM venga conservata fino al completamento e all'accettazione formale della migrazione. Per maggiori informazioni, vedere "Allegato 1 - Backup e ripristino delle impostazioni dell'appliance".

!!! info "Verifica della configurazione di routing attuale del MGW"
    Prima di spegnere il MGW esistente, verifica i seguenti valori di configurazione e annotali. Probabilmente ti serviranno in seguito per configurare l'HIN Gateway:

    1. Accedi al MGW e vai su **"Mail System → Outgoing server"** e verifica se è configurato qualcosa.
    2. Per ogni dominio ospitato sul MGW, vai su `Mail System → <dominio> → Forwarding server` e `Mail System → <dominio> → Send ALL outgoing mails from this domain to the following SMTP server`, e registra i valori attuali.
    <br> ![domain-relay-host](assets/installation-guide/step1.2-domain-relay-host.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

!!! tip "Verifica dell'header check del MGW"
    Se utilizzi l'opzione `Header check` nel MGW, annota anche il valore configurato. Potrai impostare lo stesso header check in seguito nell'HIN Gateway.

### Passo 1.3 - Esportazione delle chiavi private

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)
:heavy_plus_sign:
![Responsabilità HIN](https://img.shields.io/badge/Responsabilita-HIN-orange)

!!! info Applicabile solo in caso di migrazione
    Questo passaggio si applica solo alle migrazioni a dominio singolo e multiplo

    Per le migrazioni multi-dominio, esegui l'operazione per ciascun dominio

!!! warning "Assistenza HIN richiesta"
    Per questo passaggio è necessario un codice di sblocco. Il codice viene fornito da un HIN Support Engineer.

Se desideri continuare l'installazione autonomamente, contatta il Supporto HIN per richiedere il codice di sblocco. In caso contrario, il codice di sblocco ti sarà fornito durante la chiamata di migrazione pianificata.

<!-- !!! info
    Scarica lo strumento `HIN_Migration-Tool_v*.exe` al link: [link](https://link) -->

1. Accedi alla webGUI del MGW esistente.
2. Aprire **"Mail System"**. <br> ![Aprire Mail System](assets/installation-guide/step1.3-2-open-mail-system.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
3. Avviare l'applicazione cliccando su [**`HIN_Migration-Tool_v*.exe`**](https://images.hin.ch/mgw/HIN_MigrationTool-v3.0.exe) se si desidera eseguire l'installazione autonomamente. In alternativa, è possibile attendere la chiamata di migrazione, durante la quale il support engineer assisterà l'utente durante l'installazione. <br> ![HIN Migration Tool](assets/installation-guide/step1.3-3-migration-tool.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
4. Inserire il codice di sblocco fornito dal tecnico dell'assistenza. <br> ![Inserire il codice di sblocco](assets/installation-guide/step1.3-4-unlock-code.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
5. Selezionare **"Enable export"**. <br> ![Abilitare l'esportazione](assets/installation-guide/step1.3-5-enable-export.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
6. Inserire l'indirizzo IP dell'MGW. <br> ![Inserire l'indirizzo IP dell'MGW](assets/installation-guide/step1.3-6-mgw-ip.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
7. Attendere la conferma. <br> ![Attendere la conferma](assets/installation-guide/step1.3-7-confirmation.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
8. Selezionare il dominio attendibile nella webGUI dell'MGW. <br> ![Selezionare il dominio attendibile](assets/installation-guide/step1.3-8-trusted-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
9. Scorrere verso il basso e selezionare l'impronta digitale gestita. <br> ![Selezionare l'impronta digitale gestita](assets/installation-guide/step1.3-9-managed-fingerprint.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
10. Scorrere fino alla sezione **"PKCS12 download"** (facoltativamente è possibile inserire una password per crittografare la chiave). Fare clic su **"Download PKCS12"** e salvare il file `*.p12` sul computer. <br> ![Download PKCS12](assets/installation-guide/step1.3-10-pkcs12-download.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
11. Tornare all'applicazione `HIN_Migration-Tool_v*.exe` e disattivare il pulsante **Export**. <br> ![Disabilitare l'esportazione](assets/installation-guide/step1.3-11-disable-export.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Passo 1.4 - Piano di contingenza / scenario di fallback

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

!!! info Applicabile solo in caso di migrazione
    Questo passaggio si applica solo alle migrazioni a dominio singolo e multiplo

**Scenario di rollback** - se è richiesto un rollback:

1. Arresta il nuovo HIN Gateway.
2. Accendi il MGW esistente.
3. Verifica che il traffico email in entrata e in uscita funzioni correttamente tramite il MGW esistente.
    - Per le migrazioni multi-dominio, esegui l'operazione di verifica per ciascun dominio

### Passo 1.5 - Spegnimento del MGW VM esistente

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

!!! info Applicabile solo in caso di migrazione
    Questo passaggio si applica solo alle migrazioni a dominio singolo e multiplo

Spegni il MGW VM esistente.

!!! warning
    Questo passaggio interromperà il flusso di posta. Durante l'interruzione, le email verranno messe in coda sul server di posta e consegnate dopo il completamento dell'installazione (vedere "Passo 18 - Configurazione del server di posta").

### Passo 2 - WireGuard

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Assicurati di aver configurato la porta WireGuard `19818` (TCP/UDP) nel tuo firewall:

- Traffico in entrata e in uscita
- Consenti traffico: any-to-HIN Gateway e HIN Gateway-to-any

### Passo 3 - Selezione VM di destinazione

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Seleziona una delle immagini virtuali disponibili e forniscila come descritto nella guida all'installazione nella pagina del servizio HIN Gateway:

!!! info
    Per motivi di sicurezza e supportabilità, assicurati che il tuo hypervisor non stia eseguendo una versione end-of-life. L'appliance HIN Gateway è supportata sull'ultima versione dell'hypervisor e sulla versione maggiore immediatamente precedente.

- Installazione immagine VM:
    - [Immagine VM Azure](vm/Azure-image-install.md)
    - [Immagine Windows 11 Pro (Hyper-V)](vm/Windows11pro-image-install.md)
    - [Immagine VMware](vm/VMware-image-install.md)
    - [Immagine Proxmox](vm/Proxmox-image-install.md)
    - [Cloudscale](vm/Cloudscale-image-install.md)
- [Configurazione di Microsoft Exchange](Exchange-integration.md)

### Passo 4 - Caricamento dell'immagine VM

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Carica l'immagine VM selezionata sul tuo hypervisor.

!!! warning "Secondo disco richiesto: il disco dati"
    L'appliance usa due dischi: il disco del sistema operativo dall'immagine e un **disco dati** separato che contiene tutta la configurazione, i secret, la posta e i database. Questa separazione consente a un aggiornamento dell'immagine di sostituire il sistema operativo senza toccare i tuoi dati.

    L'**OVA VMware include già** questo disco. Su tutte le altre piattaforme (Proxmox, Hyper-V, Azure, Cloudscale) l'immagine è un unico disco di sistema: collega quindi un secondo disco vuoto di almeno 30 GB prima del primo avvio.

    Non formattarlo né partizionarlo manualmente. Al primo avvio l'appliance formatta il disco vuoto (etichetta `VEREIGN-DATA`) e lo monta su `/var/data`. Senza di esso, il primo avvio fallisce il controllo di integrità ed esegue il rollback.

### Passo 5 - Connessione di rete alla VM

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Assicurati che la VM abbia una connessione di rete e che le sia stato assegnato un indirizzo IP statico.

**Opzione A:** Configura l'indirizzo IP della macchina virtuale direttamente nell'hypervisor che stai utilizzando.

**Opzione B:** Puoi configurare il server DHCP del tuo router per assegnare sempre lo stesso indirizzo IP in base all'indirizzo MAC della VM.

**Opzione C:** Accedi localmente tramite la console VM e configura manualmente un indirizzo IP statico.
NOTA: L'immagine VM esegue un'installazione automatica durante il primo avvio. Se la rete non è configurata in questa fase, l'installazione fallirà perché l'indirizzo IP del server non può essere determinato.

Aggiungere un indirizzo IP su Linux:

1. Esegui il comando "nmtui" nella console

    ```bash
    nmtui
    ```

2. Usa i tasti freccia per navigare, quindi premi "Enter" per selezionare la "Ethernet connection" per la quale desideri modificare l'indirizzo IP. <br> ![Add IP Addr](assets/ip_addr_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
3. Naviga a "IPv4 Configuration" e modifica l'impostazione da "Automatic" a "Manual". <br> ![Add IP Addr](assets/ip_addr_2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
4. Usa i tasti freccia per navigare ai campi dove puoi inserire l'indirizzo IP, il gateway e il server DNS. Quindi seleziona "OK". <br> ![Add IP Addr](assets/ip_addr_3.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
5. Dopo aver salvato la configurazione dell'indirizzo IP, esegui il seguente comando nella console:

    ```bash
    sudo systemctl restart NetworkManager
    ```

??? tip "Cloud-init sovrascrive le impostazioni di rete della VM dopo il riavvio"

    **Questo riguarda solo l'immagine legacy.** L'appliance bootc, ora l'impostazione predefinita, non usa cloud-init per gestire la rete, quindi non è interessata e non include gli alias `cloud-init-net-*` usati di seguito.

    Sull'immagine legacy (tipicamente su VMware/ESXi), cloud-init non ha un'origine dati, ripiega su "DHCP sulla prima NIC" e rigenera la configurazione di rete a ogni avvio, quindi un indirizzo statico impostato con `nmtui` viene ripristinato dopo un riavvio. Un alias risolve la cosa in un solo passaggio disabilitando solo il rendering di rete di cloud-init, così un indirizzo impostato successivamente sul profilo esistente persiste:

    1. Impedire a cloud-init di rigenerare la rete a ogni avvio:
    ```bash
    cloud-init-net-disable
    ```
    2. Esegui `nmtui`, modifica la connessione esistente **`cloud-init <iface>`** e imposta lì l'IP statico, il gateway e il DNS. Non aggiungere un secondo profilo per la stessa interfaccia: quello di cloud-init ha una priorità di autoconnessione più alta e prevarrebbe.
    ```bash
    nmtui
    ```
    3. Riavvia e verifica che l'indirizzo persista:
    ```bash
    sudo reboot
    # dopo il riavvio:
    nmcli device status; ip -4 addr
    ```

    `cloud-init-net-enable` ripristina la rete predefinita gestita da cloud-init. Senza l'alias, il passaggio 1 è lo stesso file drop-in a mano:
    ```bash
    echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    ```

!!! tip
    Se hai utilizzato l'Opzione C e configurato la rete manualmente, devi eseguire i seguenti comandi:

    ```bash
    cd /usr/share/stargate-deployment/docker-compose
    ./scripts/purge.sh
    ./scripts/install.sh
    ```

    Lo script di installazione rileva automaticamente l'indirizzo IP del server dalla route predefinita a ogni esecuzione: non è necessario modificare manualmente `customer-config.sh`. È sufficiente qualsiasi indirizzo IP raggiungibile, pubblico o privato. L'endpoint pubblico effettivo viene configurato successivamente tramite il dashboard.

    !!! note "Dietro NAT o un IP flottante?"
        Se il tuo server viene raggiunto su un IP pubblico o flottante *diverso* da quello della sua interfaccia di rete (comune con il NAT), imposta `SERVER_STATIC_IP` su quell'indirizzo raggiungibile in `customer-config.sh` prima di eseguire `install.sh`. In caso contrario lascialo vuoto in modo che venga rilevato automaticamente.

    Dopo il completamento con successo degli script, procedi al "Passo 6 - Accesso tramite browser"

    !!! question
        Se non disponi delle credenziali di amministratore HIN, contatta il Supporto HIN via email o telefono (**support@hin.ch** / **0848 830 740**). Fai riferimento alla [Sezione Supporto](./Support.md).

        [Clicca qui per inviare un'email](mailto:support@hin.ch?subject=Password%20required%20for%20VM%20installation.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20password%20for%20a%20VM%20installation.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Passo 6 - Accesso tramite browser

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Apri un browser e inserisci l'indirizzo IP configurato per la VM. Dovresti vedere la schermata di configurazione iniziale.

```plain
https://<VM IP address>
```

### Passo 7 - Inserimento codice di attivazione

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Seleziona la lingua preferita e inserisci il codice di attivazione che hai ricevuto via email da HIN. Fai clic su "Next".

![Schermata di inserimento codice di attivazione](assets/installation-guide/step7-activation-code.png)

!!! question "Non ho un codice di attivazione"
    Se non disponi del codice di attivazione, contatta il Supporto HIN via email o telefono (**<support@hin.ch>** / **0848 830 740**). Fai riferimento alla [Sezione Supporto](./Support.md).

    [Clicca qui per inviare un'email](mailto:support@hin.ch?subject=Activation%20code%20required.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20activation%20code%20for%20my%20HIN%20Gateway%20installation.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Passo 8 - Configurazione rete mesh

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Verifica la configurazione della rete mesh:

- **Indirizzo IP** - L'IP pubblico del traffico in uscita (rilevato automaticamente).
- **Trasporto** - Il protocollo di trasporto (predefinito: `tcp`).
- **Porta** - La porta WireGuard (predefinita: `19818`).

??? question "Cos'è un IP pubblico?"
    Questo è l'indirizzo IP che la macchina utilizzerà per essere accessibile tramite Internet.
    **Non** si tratta dell'indirizzo IP interno della macchina dietro firewall o NAT, ad esempio `10.0.0.0/8`, `172.16.0.0/12` o `192.168.0.0/16`.

Conferma che i valori siano corretti e fai clic su "Next".

![Schermata di configurazione rete mesh](assets/installation-guide/step8-mesh-network.png)

### Passo 9 - Creazione rete mesh sicura

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Il sistema stabilirà ora la connessione alla rete mesh sicura. Questo passaggio collega l'HIN Gateway alla rete mesh e sincronizza i certificati.

Attendi il completamento del processo. Gli indicatori di stato mostreranno "Up" quando la connessione sarà stabilita con successo. Fai clic su "Finish".

![Creazione rete mesh sicura](assets/installation-guide/step9-mesh-connecting.png)

!!! failure "Se la connessione fallisce"
    Se lo stato dell'`Iris Agent` o della sincronizzazione dei certificati rimane "Down":

    - Verifica che la porta `19818` (TCP/UDP) sia aperta nel tuo firewall (vedere "Passo 2 - WireGuard").
    - Verifica che l'indirizzo IP nel "Passo 8 - Configurazione rete mesh" sia corretto e raggiungibile da Internet.
    - Riavvia il processo o contatta il Supporto HIN via email o telefono (**support@hin.ch** / **0848 830 740**).

### Passo 10 - Accesso a Keycloak

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

!!! warning
    La porta `8180` deve essere aperta per Keycloak. Non è necessario che sia accessibile da Internet a livello globale. Deve invece essere accessibile tra **il tuo computer di amministrazione** e la VM che stai installando. In caso contrario, non potrai connetterti a Keycloak e proseguire con l'installazione.

    ??? tip "Cosa fare se viene visualizzato un errore di connessione"
        Verifica che la porta `8180` sia accessibile dal tuo computer verso la VM. Non appena aggiorni la configurazione, torna all'interfaccia utente all'indirizzo `https://<VM IP address>` e fai clic sul pulsante "Login".

Una volta stabilita la rete mesh, verrai reindirizzato alla pagina di accesso di Keycloak. Inserisci il nome utente e la password ricevuti da HIN.

![Pagina di accesso Keycloak](assets/installation-guide/step10-keycloak-login.png)

!!! question
    Se non disponi di questi dati di accesso, contatta il Supporto HIN via email o telefono (**<support@hin.ch>** / **0848 830 740**). Fai riferimento alla [Sezione Supporto](./Support.md).

    [Clicca qui per inviare un'email](mailto:support@hin.ch?subject=Keycloak%20login%20required.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20Keycloak%20login%20details%20for%20my%20HIN%20Gateway.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Passo 11 - Aggiornamento password

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Al primo accesso, ti verrà richiesto di cambiare la password. Inserisci una nuova password sicura e confermala.

Assicurati di ricordare la password!

![Schermata di aggiornamento password](assets/installation-guide/step11-update-password.png)

### Passo 12 - Aggiornamento informazioni account

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Completa il tuo profilo account inserendo nome e cognome. L'indirizzo email è precompilato. Fai clic su "Submit" per continuare.

![Schermata di aggiornamento informazioni account](assets/installation-guide/step12-account-info.png)

### Passo 13 - Configurazione iniziale e setup domini

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

!!! info Nota sulla migrazione multi-dominio
    Per le migrazioni multi-dominio, esegui l'operazione per ogni dominio che stai attivando in quel momento.

In questa schermata, configura le tue impostazioni iniziali:

- Verifica che tutti i tuoi domini fidati attuali all'interno della Comunità HIN siano visualizzati correttamente.
- Seleziona quali domini fidati devono essere **Abilitati** per ottenere certificati peer dalla HIN Certification Authority (HIN CA).
- Indica per quale/i dominio/i il prefisso `sec.<domain>` è già configurato ("Use sec-prefix").

??? tip "Come verificare se il mio dominio è configurato con un Security Prefix?"
    Apri il nostro strumento online nel browser: <https://trust.hin.ls-infra.me/>, inserisci `sec.<domain>` e fai clic sul pulsante **Check**. Se viene visualizzato il messaggio:

    ✅ Questo dominio è crittografato.

    Allora il tuo dominio è configurato con un Security Prefix e devi abilitare l'opzione **Use sec-prefix**.

- Verifica che il nome dell'organizzazione e i proprietari del dominio siano corretti. <br> ![Screenshot](assets/installation-guide/step13-1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" } <br> ![Screenshot](assets/step_13_2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
- Importa il file del certificato S/MIME esistente (`.p12`/`.pfx`) dal MGW esistente:
    1. Espandi il dominio e seleziona l'opzione **P12/PFX File**.
    2. Se non è stata impostata una password per il file del certificato, lascia vuoto il campo password.
    3. Fai clic su **"Import Certificate"**.
    4. Dopo l'importazione del certificato, viene visualizzato il messaggio *Certificate imported successfully*.
- Fai clic su **"Save Configuration"** alla fine della pagina per salvare le modifiche.

![Schermata di configurazione iniziale](assets/installation-guide/step13-initial-setup.png)

!!! warning
    - Almeno un dominio deve essere **Abilitato** per continuare con il processo di onboarding. Il pulsante "Save configuration" diventerà attivo solo una volta soddisfatto questo requisito.
    - Se noti che non tutti i domini fidati sono visualizzati o che le informazioni organizzative non sono corrette, contatta il Supporto HIN via email o telefono (**<support@hin.ch>** / **0848 830 740**).

!!! danger "Importa la tua chiave privata esistente"
    Nota: applicabile per lo scenario di migrazione!

    Se **non** importi la chiave privata dal tuo MGW esistente, verrà emessa una nuova chiave. Ciò potrebbe comportare l'impossibilità di decriptare i messaggi per un massimo di **6 ore**, il che potrebbe portare a **perdita di dati**.

![Schermata di configurazione](assets/installation-guide/step13-initial-setup2.png)

| Impostazione | Descrizione |
| --------- | ------------- |
| **Mail server host name** | Il FQDN di questa istanza del gateway di posta (es. `mail.example.com`). |
| **Mail server IP addresses** | Gli indirizzi IP pubblici di questo server. Aggiungi IP aggiuntivi se il server è raggiungibile su più indirizzi. |
| **DNS** | Il DNS dell'host che verrà utilizzato per risolvere i record MX e altri record DNS |

### Passo 14 - Configurazione trasporto posta

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Accederai alla dashboard dell'HIN Gateway nella pagina `Domains`

 <br> ![Screenshot](assets/installation-guide/step14-dashboard-domains.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

#### Pagina Domains

!!! info Nota sulla migrazione multi-dominio
    Per le migrazioni multi-dominio, esegui l'operazione per ogni dominio attivo.

Nel menu **Domains**, per ogni dominio disponibile puoi configurare una rotta di trasporto specifica:

![Domain transport configuration screen](assets/installation-guide/step14-domain-mail-transport.png)

| Impostazione | Descrizione |
| --------- | ------------- |
| **Inbound relay** | Il relay SMTP per la consegna in entrata per il dominio selezionato |
| **Outbound relay** | Il relay SMTP per la consegna in uscita per il dominio selezionato. Questa impostazione corrisponde all'impostazione `Forwarding server` del vecchio MGW |
| **Trusted networks** | Reti aggiuntive autorizzate a fare relay tramite questo gateway. Per maggiori informazioni consulta il "Passo 18 - Configurazione del server di posta" |
| **Configure TLS** | Impostazioni del certificato TLS per le connessioni SMTP; dal pulsante `Generate TLS certificate` puoi generare un certificato TLS |
| **Email authentication** | Per tutte le impostazioni della sezione `Email authentication` fai riferimento alla sezione [Email authentication (DKIM ARC SPF DMARC)](Email-authentication-DKIM-ARC-SPF-DMARC.md) |

??? tip "Come testare una connessione TLS?"
    È sempre possibile verificare se il certificato TLS configurato è stato applicato alla connessione al HIN Gateway. Eseguire il seguente comando direttamente nel terminale del HIN Gateway:

    ```bash
    openssl s_client -connect 127.0.0.1:25 -starttls smtp -servername mail.<YOUR_DOMAIN>
    ```

    Oppure direttamente dal proprio computer locale:

    ```bash
    openssl s_client -connect <HIN Gateway IP>:25 -starttls smtp -servername mail.<YOUR_DOMAIN>
    ```

    Nell'output saranno visualizzati tutti i dati relativi alla connessione TLS e al certificato utilizzato.

??? question "Come convertire un certificato TLS da `pfx` a `pem`?"
    Utilizzare il seguente comando openssl:

    ```bash
    openssl pkcs12 -in <Certificate>.pfx -out <Certificate>.pem -nodes
    ```

    Ad esempio:

    ```bash
    openssl pkcs12 -in certificate.pfx -out keyStore.pem -nodes
    # A volte è necessario aggiungere l'argomento -legacy sui sistemi con generatori di certificati meno recenti
    openssl pkcs12 -in certificate.pfx -out keyStore.pem -nodes -legacy
    ```

Azioni aggiuntive:

- Aggiungi domini aggiuntivi facendo clic su "Add domain", se necessario.
    - se il dominio non è protetto da HIN, apparirà nell'elenco `Domains` come Type: Routed, il che significa che può essere gestito solo localmente

!!! note
    Assicurati che tutte le configurazioni dell'host di relay e dei domini siano corrette prima di procedere.

Una volta rivista e completata la configurazione, fai clic su "Save" per continuare.

#### Pagina Settings

In questa pagina, nel menu `Settings`, configura le impostazioni globali di trasporto della posta per il setup del relay di posta sicuro, comuni all'intera istanza. La configurazione dettagliata per ogni dominio può essere effettuata in `Domains` -> `$domain`

![Mail transport configuration screen](assets/installation-guide/step14-mail-transport2.png)

Nel menu `Settings` sono disponibili le seguenti impostazioni:

| Impostazione | Descrizione |
| --------- | ------------- |
| **Mail server host name** | Il FQDN di questa istanza del gateway di posta (es. `mail.example.com`). |
| **Mail server IP addresses** | Gli indirizzi IP pubblici di questo server. Aggiungi IP aggiuntivi se il server è raggiungibile su più indirizzi. |
| **DNS** | Il DNS dell'host che verrà utilizzato per risolvere i record MX e altri record DNS |
| **Default inbound relay** | Il relay SMTP predefinito per la consegna in entrata |
| **Default outbound relay** | Il relay SMTP predefinito per la consegna in uscita |

### Passo 15 - Configurazione intestazioni whitelist

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

!!! info Nota multi-dominio
    Per il multi-dominio, esegui l'operazione per ogni dominio attivo.

Fai clic su **"Domains"** -> "Seleziona dominio", quindi seleziona **"Whitelist headers"**.

Inserisci la chiave esattamente come configurata nel server di posta.

![Screenshot](assets/step_15_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Passo 16 - Certificati peer

![Responsabilità HIN](https://img.shields.io/badge/Responsabilita-HIN-orange)

I certificati peer vengono emessi dalla HIN Certification Authority (HIN CA) per i domini abilitati.

Una volta completato l'onboarding, naviga alla sezione **Peer certificates** nel dashboard e fai clic sul pulsante **"Sync certificates"** per sincronizzare i tuoi certificati peer dalla HIN CA.

![Schermata certificati peer](assets/installation-guide/step15-peer-certificates.png)

### Passo 17 - Validazione certificati peer

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Assicurati che il tuo dominio abbia ricevuto il suo certificato peer basato su policy, in fondo a **"Domains"** -> "nomeDominio". Lo stato di ciascun dominio deve essere **"Good"**.

![Screenshot](assets/step_17_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

!!! question
    Contatta il Supporto HIN via email o telefono (**<support@hin.ch>** / **0848 830 740**) se riscontri problemi.

### Passo 18 - Configurazione del server di posta e dell'HIN Gateway

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Se hai seguito l'approccio consigliato esportando la chiave privata, importandola nell'HIN Gateway e mantenendo lo **stesso indirizzo IP** del MGW esistente, non è necessario apportare alcuna modifica al server di posta elettronica.

In caso contrario, configura il tuo server di posta o i componenti associati in modo che il traffico venga instradato tramite il nuovo HIN Gateway. Verifica e aggiorna le seguenti impostazioni, se necessario:

#### Server di posta elettronica

- Relay SMTP / smart host
- Connettori
- Regole di trasporto
- Domini di routing

Consulta [Integrazione con Exchange](Exchange-integration.md) per istruzioni dettagliate.

#### Configurazione dell'HIN Gateway

#### Pagina Domains

!!! info Nota sulla migrazione multi-dominio
    Per le migrazioni multi-dominio, esegui l'operazione per ogni dominio attivo.

Nel menu **Domains**, per ogni dominio disponibile puoi configurare una rotta di trasporto specifica:

| Impostazione | Descrizione |
| --------- | ------------- |
| **Inbound relay** | Il relay SMTP per la consegna in entrata per il dominio selezionato |
| **Outbound relay** | Il relay SMTP per la consegna in uscita per il dominio selezionato. Questa impostazione corrisponde all'impostazione `Forwarding server` del vecchio MGW |
| **Trusted networks** | Reti aggiuntive autorizzate a fare relay tramite questo gateway. Per maggiori informazioni consulta il "Passo 18 - Configurazione del server di posta" |
| **Configure TLS** | Impostazioni del certificato TLS per le connessioni SMTP; dal pulsante `Generate TLS certificate` puoi generare un certificato TLS |
| **Email authentication** | Per tutte le impostazioni della sezione `Email authentication` fai riferimento alla sezione [Email authentication (DKIM ARC SPF DMARC)](Email-authentication-DKIM-ARC-SPF-DMARC.md) |

- **Nota per lo scenario di migrazione:** vai alla pagina di ogni dominio e aggiungi un **Outbound host** utilizzando il valore registrato dal campo `Forwarding server` del MGW nel "Passo 1.2 - Backup del MGW esistente".

  <br> ![domain-relay-host](assets/installation-guide/step18-add-domain-relay.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

- Se utilizzi Microsoft 365 / Exchange Online, aggiungi i relativi intervalli di IP in uscita pubblicati a **`Trusted networks`** affinché l'HIN Gateway consideri attendibile e inoltri la posta proveniente da Exchange Online:

    ```text
    40.92.0.0/15
    40.107.0.0/16
    51.4.72.0/24
    51.4.80.0/27
    51.5.72.0/24
    51.5.80.0/27
    52.100.0.0/14
    104.47.0.0/17
    2a01:111:f400::/48
    2a01:111:f403::/48
    2a01:4180:4050:400::/64
    2a01:4180:4050:800::/64
    2a01:4180:4051:400::/64
    2a01:4180:4051:800::/64
    ```

  <br> ![domain-relay-host](assets/installation-guide/step14-domain-mail-transport.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

#### Pagina Settings

In questa pagina, nel menu `Settings`, configura le impostazioni globali di trasporto della posta per il setup del relay di posta sicuro, comuni all'intera istanza. La configurazione dettagliata per ogni dominio può essere effettuata in `Domains` -> `$domain`

![Mail transport configuration screen](assets/installation-guide/step14-mail-transport2.png)

Nel menu `Settings` sono disponibili le seguenti impostazioni:

| Impostazione | Descrizione |
| --------- | ------------- |
| **Mail server host name** | Il FQDN di questa istanza del gateway di posta (es. `mail.example.com`). |
| **Mail server IP addresses** | Gli indirizzi IP pubblici di questo server. Aggiungi IP aggiuntivi se il server è raggiungibile su più indirizzi. |
| **DNS** | Il DNS dell'host che verrà utilizzato per risolvere i record MX e altri record DNS |
| **Default inbound relay** | Il relay SMTP predefinito per la consegna in entrata |
| **Default outbound relay** | Il relay SMTP predefinito per la consegna in uscita |

<br> ![domain-relay-host](assets/installation-guide/step14-mail-transport2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Passo 19 - Test e validazione

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

**In uscita:**

- Verifica che il server di posta sia configurato per inviare email all'HIN Gateway utilizzando un relay SMTP o un connettore Exchange.
- Verifica che l'HIN Gateway possa inviare email a destinatari al di fuori della Comunità HIN.
- Verifica che l'HIN Gateway possa inviare email a destinatari all'interno della Comunità HIN tramite WireGuard.
- Invia una email dalla Comunità HIN a un indirizzo email esterno (ad esempio Bluewin, Gmail, Yahoo o GMX) con (confidenziale) inserito nell'oggetto, e verifica che venga consegnata con successo.

**In entrata:**

- Verifica che le email crittografate possano essere ricevute dalla Comunità HIN tramite WireGuard. Un mittente del dominio `hin.ch` è il percorso di test più semplice.
- Verifica che le email crittografate possano essere ricevute dalla Comunità HIN tramite SMTP utilizzando S/MIME.
- Verifica che le risposte da mittenti al di fuori della Comunità HIN a una email sicura iniziale (HIN Mail-SEAL) possano raggiungere l'HIN Gateway.
- Verifica che le email in testo semplice possano essere ricevute da mittenti esterni al di fuori della Comunità HIN.
- Invia una email da un indirizzo email esterno alla Comunità HIN e verifica che venga ricevuta con successo.

Conferma:

- Le email vengono consegnate con successo in entrambe le direzioni tra il dominio HIN affidabile e gli indirizzi email esterni.
- La crittografia viene applicata dove richiesto.
- Nessun ritardo o rimbalzo inatteso.
- Il logging funziona correttamente.

Compila l'[**Acceptance Report**](https://www.hin.ch/files/pdf1/gateway-acceptance-en.pdf) e consegnalo al tuo rappresentante HIN.

### Passo 20 - Modifica della password della VM

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Assicurati che le credenziali della VM che ti sono state fornite inizialmente vengano modificate con una password definita da te, e conservale in un luogo sicuro e protetto.

### Passo 21 - Disattivazione del MGW esistente

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

!!! info Applicabile solo in caso di migrazione
    Questo passaggio si applica solo alle migrazioni a dominio singolo e multiplo

!!! warning
    Non eliminare immediatamente il MGW VM esistente - tienilo al sicuro fino a quando tutto non è in funzione.

1. **Assicurati che non ci sia traffico attivo** - controlla:
    - Nessun dominio punta al MGW (DNS, SMTP, connettori).
    - Nessuna email viene inoltrata tramite la vecchia appliance.
2. **Archivia i log** - esporta e salva:
    - Log delle email
    - Log di sicurezza/audit
    - Richiesti per conformità e risoluzione dei problemi
3. **Pulizia (opzionale)** - rimuovi:
    - Regole del firewall
    - Voci DNS
    - Configurazioni di routing che fanno riferimento al MGW esistente

## Allegato 1 - Backup e ripristino delle impostazioni dell'appliance

!!! info Applicabile solo in caso di migrazione
    Questo passaggio si applica solo alle migrazioni a dominio singolo e multiplo

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Per eseguire il backup o il ripristino delle impostazioni della tua appliance HIN, fai clic sul menu **"Administration"** nel portale di amministrazione web.

![Screenshot](assets/annex_1_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Backup delle impostazioni

Prima di creare un backup delle impostazioni correnti dell'appliance HIN, devi impostare una password di backup. Questa password è richiesta se devi ripristinare il backup in seguito.

- Per impostare o modificare la password di backup, fai clic su **"Change Password"**.
- Per creare e scaricare un file di backup, fai clic su **"Download"**.

### Modifica della password di backup

Per modificare la password per i backup futuri, fai clic su **"Change Password"**.

!!! note
    La nuova password si applica solo ai backup creati **dopo** che la password è stata modificata. I file di backup esistenti rimangono protetti dalla password impostata al momento della loro creazione.

### Ripristino delle impostazioni

Per ripristinare le impostazioni dell'appliance da un file di backup, fai clic su **"Import Backup File..."**.

Nella finestra di dialogo, seleziona il file di backup richiesto e inserisci la password associata a quel backup. Le impostazioni dell'appliance verranno quindi ripristinate dal file di backup selezionato.

### Backup tramite SCP

Il MGW supporta il backup dell'appliance tramite SCP.

Per utilizzare questa opzione, la chiave pubblica del sistema che accederà al MGW deve essere memorizzata in **"Backup using SCP"**. Il backup viene generato automaticamente ogni giorno a mezzanotte e viene memorizzato sul MGW come `backup.tgz`.

Utilizzando la chiave pubblica configurata, il file di backup può essere recuperato tramite SCP con l'utente del sistema operativo `backup`. Un tipico comando SCP per recuperare il file di backup è:

```bash
scp backup@192.168.1.60:/backup.tgz .
```

Questo comando scarica il file `backup.tgz` dal MGW alla directory locale corrente.

!!! note
    Se inserisci una nuova chiave pubblica, la chiave esistente verrà sostituita.
