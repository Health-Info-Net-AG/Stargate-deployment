# HIN Mail Gateway - Processo di installazione tecnica

!!! tip
    Processo di installazione tecnica per architettura di posta a dominio singolo con Microsoft 365

## Introduzione

Questo documento fornisce una guida completa al processo di installazione tecnica e migrazione verso il nuovo [HIN Gateway](https://www.hin.ch/de/services/hin-mail/hin-gateway.cfm) ("Stargate Appliance"). Si applica alle architetture di posta Microsoft 365 che utilizzano un **singolo dominio fidato**.

La guida è destinata ai clienti HIN, amministratori IT e ingegneri di sistema responsabili del deployment e della configurazione del nuovo HIN Gateway, e della migrazione dal Mail Gateway (MGW) esistente alla nuova soluzione.

L'HIN Gateway è una soluzione di gateway email sicuro che consente una comunicazione affidabile, crittografata e basata su policy all'interno del HIN Trust Circle. Agisce come intermediario centrale tra le infrastrutture email interne e i partner di comunicazione esterni, garantendo che tutto il traffico email venga trasmesso in modo sicuro, sia conforme alle policy dell'organizzazione e soddisfi gli standard di sicurezza HIN.

## Panoramica del flusso di posta

- **Le email in entrata** vengono instradate tramite l'HIN Gateway, dove vengono validate, decriptate (se necessario) e verificate rispetto alle policy di fiducia e sicurezza prima di essere inoltrate al server di posta interno.
- **Le email in uscita** vengono inviate dai sistemi interni all'HIN Gateway, dove vengono applicate crittografia, routing e applicazione delle policy prima di essere trasmesse ai destinatari esterni.
- **La comunicazione tra gateway HIN** è protetta da certificati peer e tunnel WireGuard, garantendo una comunicazione affidabile tra domini.

## Processo di installazione e migrazione

La procedura strutturata passo-passo descritta in questo documento copre i seguenti punti:

1. Preparazione e pianificazione del fallback
2. Installazione e configurazione dell'HIN Gateway
3. Attivazione del dominio e validazione del certificato
4. Integrazione del server di posta e configurazione del routing
5. Test, transizione alla produzione e validazione post-migrazione
6. Disattivazione del MGW esistente

L'obiettivo di HIN in questo processo è garantire una migrazione sicura, fluida e completamente validata che causi il minimo disturbo alle operazioni e garantisca la continuità ininterrotta dei servizi email.

## Domande frequenti

!!! question "Posso eseguire l'installazione e la migrazione autonomamente?"
    Sì, l'installazione e la migrazione possono essere completate interamente dal cliente, **ad eccezione del "Passo 1.3 - Esportazione delle chiavi private"**.

    Per motivi di sicurezza e per mantenere al sicuro la tua chiave privata, devi contattare il Supporto HIN o partecipare alla chiamata di migrazione pianificata per ricevere il codice necessario per esportare la chiave privata dal Mail Gateway attualmente in funzione.

    Se l'installazione e la migrazione non possono essere completate con successo, partecipa alla chiamata di supporto pianificata con i nostri ingegneri.

!!! question "Ci saranno interruzioni nella consegna delle email durante la migrazione?"
    Tra **"Passo 1.5 - Spegnimento del MGW VM esistente"** e **"Passo 18 - Configurazione del server di posta"**, tutte le email saranno in coda sul server di posta. Una volta completato il "Passo 18 - Configurazione del server di posta", le email in coda verranno inviate o consegnate alla cassetta postale.

!!! question "Verranno perse email durante l'installazione e la migrazione?"
    No, nessuna email andrà persa durante l'installazione e la migrazione.

## Panoramica dei passaggi di installazione

| Passo | Argomento | Responsabilità |
| :--: | :---- | :------------: |
| 0 | Verifica prerequisiti | Cliente |
| 1.1 | Smoke test | Cliente |
| 1.2 | Backup del MGW esistente | Cliente |
| 1.3 | Esportazione delle chiavi private | Cliente / HIN |
| 1.4 | Piano di contingenza / scenario di fallback | Cliente |
| 1.5 | Spegnimento del MGW VM esistente | Cliente |
| 2 | WireGuard | Cliente |
| 3 | Selezione VM di destinazione | Cliente |
| 4 | Caricamento dell'immagine VM | Cliente |
| 5 | Connessione di rete alla VM | Cliente |
| 6 | Accesso tramite browser | Cliente |
| 7 | Inserimento codice di attivazione | Cliente |
| 8 | Configurazione rete mesh | Cliente |
| 9 | Creazione rete mesh sicura | Cliente |
| 10 | Accesso a Keycloak | Cliente |
| 11 | Aggiornamento password | Cliente |
| 12 | Aggiornamento informazioni account | Cliente |
| 13 | Configurazione iniziale e setup domini | Cliente |
| 14 | Configurazione trasporto posta | Cliente |
| 15 | Configurazione intestazioni whitelist | Cliente |
| 16 | Certificati peer | HIN |
| 17 | Validazione certificati peer | Cliente |
| 18 | Configurazione server di posta | Cliente |
| 19 | Test prima del passaggio | Cliente |
| 20 | Validazione dopo il passaggio | Cliente |
| 21 | Disattivazione del MGW esistente | Cliente |
| 22 | Modifica della password della VM | Cliente |
| Allegato 1 | Backup e ripristino delle impostazioni dell'appliance | Cliente |

## Passaggi dettagliati

### Passo 0 - Verifica prerequisiti

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Si prega di rivedere le "Istruzioni di deployment Stargate" e assicurarsi che tutti i passaggi preparatori necessari siano stati completati prima dell'inizio delle attività di migrazione dell'HIN Gateway.

I seguenti elementi devono essere disponibili o confermati prima della migrazione:

- **Le credenziali ti saranno fornite da HIN**
    - Credenziale VM
    - Credenziale Keycloak
    - Codice di attivazione
- **Esportazione della chiave privata**
    - Se stai lavorando su una macchina Windows che ha accesso alla VM del Mail Gateway tramite la porta 22, possiamo supportarti durante la chiamata nell'abilitare l'esportazione della chiave privata dal MGW.
    - Se non hai accesso a tale macchina, contatta il Supporto HIN via email o telefono (<support@hin.ch> / 0848 830 740) per aiutarti a stabilire una connessione di supporto tramite Amministrazione sistema → Connessione di supporto → Connetti.
- **Scarica l'ultima** versione dell'[immagine VM](vm/VM-Catalog.md)
- **Requisiti firewall** per WireGuard.
  Configura la porta WireGuard 19818 (TCP/UDP) nel tuo firewall:
    - Traffico in entrata e in uscita
    - Consenti traffico: any-to-HIN Gateway e HIN Gateway-to-any
- **L'accesso DHCP** dovrebbe essere disponibile per il "Passo 5 - Connessione di rete alla VM" (raccomandato).
- **Requisiti di backup** - vedere "Allegato 1 - Backup e ripristino delle impostazioni dell'appliance".
- Conferma che il MGW esistente **non** verrà eliminato fino al completamento dell'accettazione.
- Accesso a DNS, connettori del server di posta, regole di trasporto e impostazioni di relay.

!!! info "Perché WireGuard?"
    La porta WireGuard assolve due importanti funzioni:

    1. L'HIN Gateway utilizza questa porta per ottenere certificati peer dalla CA HIN.
    2. Utilizza questa porta per stabilire un tunnel sicuro verso altri HIN Gateway, attraverso il quale avviene lo scambio sicuro di dati (es. traffico email).

!!! tip "Esportazione della chiave privata"
    Se stai lavorando su una macchina Windows che ha accesso alla VM del Mail Gateway tramite la porta 22, possiamo supportarti durante la chiamata nell'abilitare l'esportazione della chiave privata dal MGW.

    Se non hai accesso a tale macchina, contatta il Supporto HIN via email o telefono (**support@hin.ch** / **0848 830 740**) per aiutarti a stabilire una connessione di supporto tramite **Amministrazione sistema → Connessione di supporto → Connetti**.

### Passo 1.1 - Smoke test

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Invia una email di test ai seguenti destinatari, dove hai accesso alla cassetta postale per verificare la corretta ricezione:

- Un indirizzo email HIN o un dominio della comunità HIN di tua proprietà, ad esempio: `user@hin.ch`
- Un indirizzo email al di fuori della comunità HIN, ad esempio: `user@bluewin.ch`

Verifica che entrambe le email vengano consegnate con successo, inclusi oggetto, contenuto e allegato (se inviato).

### Passo 1.2 - Backup del MGW esistente

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Crea un backup dell'appliance MGW esistente e assicurati che la VM venga conservata fino al completamento e all'accettazione formale della migrazione. Per maggiori informazioni, vedere "Allegato 1 - Backup e ripristino delle impostazioni dell'appliance".

### Passo 1.3 - Esportazione delle chiavi private

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)
:heavy_plus_sign:
![Responsabilità HIN](https://img.shields.io/badge/Responsabilita-HIN-orange)

!!! warning "Assistenza HIN richiesta"
    Questo passaggio richiede un codice di sblocco fornito da un ingegnere del supporto HIN durante la chiamata pianificata. Contatta il Supporto HIN o partecipa alla chiamata di migrazione pianificata prima di iniziare.

<!-- !!! info
    Scarica lo strumento `HIN_Migration-Tool_v*.exe` al link: [link](https://link) -->

1. Accedi alla webGUI del MGW esistente.
2. Apri **"Mail System"**.
3. Esegui l'applicazione **`HIN_Migration-Tool_v*.exe`** fornita dall'ingegnere del supporto durante la chiamata.
4. Inserisci il codice di sblocco che l'ingegnere del supporto ti fornisce.
5. Seleziona **"Enable export"**.
6. Inserisci l'indirizzo IP del MGW.
7. Attendi la conferma.
8. Seleziona il dominio fidato nella webGUI del MGW.
9. Scorri verso il basso e seleziona l'impronta gestita.
10. Scorri verso il basso fino alla categoria **"PKCS12 download"** (puoi facoltativamente inserire una password per crittografare la chiave). Premi **"Download PKCS12"** e salva il file `*.p12` sul computer.
11. Torna all'applicazione `HIN_Migration-Tool_v*.exe` e disabilita il pulsante **Export**.

### Passo 1.4 - Piano di contingenza / scenario di fallback

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

**Scenario di rollback** - se è richiesto un rollback:

1. Arresta il nuovo HIN Gateway.
2. Accendi il MGW esistente.
3. Verifica che il traffico email in entrata e in uscita funzioni correttamente tramite il MGW esistente.

### Passo 1.5 - Spegnimento del MGW VM esistente

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

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
2. Usa i tasti freccia per navigare, quindi premi "Invio" per selezionare la "Connessione Ethernet" per la quale desideri modificare l'indirizzo IP. <br> ![Aggiungi IP Addr](assets/ip_addr_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
3. Naviga a "Configurazione IPv4" e modifica l'impostazione da "Automatico" a "Manuale". <br> ![Aggiungi IP Addr](assets/ip_addr_2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
4. Usa i tasti freccia per navigare ai campi dove puoi inserire l'indirizzo IP, il gateway e il server DNS. Quindi seleziona "OK". <br> ![Aggiungi IP Addr](assets/ip_addr_3.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
5. Dopo aver salvato la configurazione dell'indirizzo IP, esegui il seguente comando nella console:

    ```bash
    sudo systemctl restart NetworkManager
    ```

??? warning "La rete deve essere configurata prima del primo avvio"
    L'immagine VM esegue un'installazione automatica al primo avvio. Se la rete non è ancora configurata (nessun indirizzo IP assegnato tramite DHCP o config statico), l'installazione fallirà perché l'IP del server non può essere rilevato.

    Se ciò accade, configura la rete manualmente, quindi esegui:

    ```bash
    cd /root/stargate-deployment/docker-compose
    ./scripts/purge.sh
    # Update configuration with a new ip, by editing it with nano
    # SERVER_STATIC_IP=<NEW IP>
    nano customer-config.sh
    # OR use sed
    # sed -i 's/old IP/new IP/g' customer-config.sh
    ./scripts/install.sh
    ```

    Lo script di installazione rileverà automaticamente l'IP del server dalla route predefinita. Qualsiasi IP raggiungibile (pubblico o privato) è sufficiente - l'endpoint pubblico effettivo viene configurato successivamente tramite il dashboard.

!!! tip
    Se hai utilizzato l'Opzione C e configurato la rete manualmente, devi eseguire i seguenti comandi:

    ```bash
    cd /root/stargate-deployment/docker-compose
    ./scripts/purge.sh
    # Update configuration with a new ip, by editing it with nano
    # SERVER_STATIC_IP=<NEW IP>
    nano customer-config.sh
    # OR use sed
    # sed -i 's/old IP/new IP/g' customer-config.sh
    ./scripts/install.sh
    ```

    Lo script di installazione rileverà automaticamente l'indirizzo IP del server dalla route predefinita. Qualsiasi indirizzo IP raggiungibile, pubblico o privato, è sufficiente. L'endpoint pubblico effettivo viene configurato successivamente tramite il dashboard.
    
    Dopo il completamento con successo degli script, procedi al "Passo 6 – Accesso tramite browser"
    
    !!! question
        Se non disponi delle credenziali di amministratore HIN, contatta il Supporto HIN via email o telefono (**support@hin.ch** / **0848 830 740**). Fare riferimento alla [Sezione Supporto](./Support.md).

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
    Se non disponi del codice di attivazione, contatta il Supporto HIN via email o telefono (**<support@hin.ch>** / **0848 830 740**). Fare riferimento alla [Sezione Supporto](./Support.md).

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

Il sistema ora stabilirà la connessione di rete mesh sicura. Questo passaggio collega l'HIN Gateway all'Iris Agent e sincronizza i certificati.

Attendi il completamento del processo. Gli indicatori di stato mostreranno "Up" quando la connessione è stabilita con successo. Fai clic su "Finish".

![Creazione rete mesh sicura](assets/installation-guide/step9-mesh-connecting.png)

!!! failure "Se la connessione fallisce"
    Se lo stato di Iris Agent o di sincronizzazione dei certificati rimane "Down":

    - Verifica che la porta `19818` (TCP/UDP) sia aperta nel tuo firewall (vedere "Passo 2 - WireGuard").
    - Verifica che l'indirizzo IP nel "Passo 8 - Configurazione rete mesh" sia corretto e raggiungibile da Internet.
    - Riavvia il processo o contatta il Supporto HIN via email o telefono (**support@hin.ch** / **0848 830 740**).

### Passo 10 - Accesso a Keycloak

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Una volta stabilita la rete mesh, verrai reindirizzato alla pagina di accesso di Keycloak. Inserisci il nome utente e la password ricevuti da HIN.

![Pagina di accesso Keycloak](assets/installation-guide/step10-keycloak-login.png)

!!! question
    Se non disponi di questi dati di accesso, contatta il Supporto HIN via email o telefono (**<support@hin.ch>** / **0848 830 740**). Fare riferimento alla [Sezione Supporto](./Support.md).

    [Clicca qui per inviare un'email](mailto:support@hin.ch?subject=Keycloak%20login%20required.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20Keycloak%20login%20details%20for%20my%20HIN%20Gateway.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Passo 11 - Aggiornamento password

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Al primo accesso, ti verrà richiesto di cambiare la password. Inserisci una nuova password sicura e confermala.

![Schermata di aggiornamento password](assets/installation-guide/step11-update-password.png)

### Passo 12 - Aggiornamento informazioni account

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Completa il tuo profilo account inserendo nome e cognome. L'indirizzo email è precompilato. Fai clic su "Submit" per continuare.

![Schermata di aggiornamento informazioni account](assets/installation-guide/step12-account-info.png)

### Passo 13 - Configurazione iniziale e setup domini

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

In questa schermata, configura le tue impostazioni iniziali:

- Verifica che tutti i tuoi domini fidati attuali all'interno della Comunità HIN siano visualizzati correttamente.
- Seleziona quali domini fidati devono essere **Abilitati** per ottenere certificati peer dalla HIN Certification Authority (HIN CA).
- Indica per quale/i dominio/i il prefisso `sec.<domain>` è già configurato ("Use sec-prefix").

??? tip "Come verificare se il mio dominio è configurato con un Security Prefix?"
    Apri il nostro strumento online nel browser: https://trust.hin.ls-infra.me/, inserisci `sec.<domain>` e fai clic sul pulsante **Check**. Se viene visualizzato il messaggio:

    ✅ Questo dominio è crittografato.

    Allora il tuo dominio è configurato con un Security Prefix e devi abilitare l'opzione **Use sec-prefix**.

- Verifica che il nome dell'organizzazione e i proprietari del dominio siano corretti. <br> ![Screenshot](assets/step_13_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" } <br> ![Screenshot](assets/step_13_2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
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
    Se **non** importi la chiave privata dal tuo MGW esistente, verrà emessa una nuova chiave. Ciò potrebbe comportare l'impossibilità di decriptare i messaggi per un massimo di **6 ore**, il che potrebbe portare a **perdita di dati**.

### Passo 14 - Configurazione trasporto posta

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

In questa schermata, configura le impostazioni di trasporto della posta per il setup del relay di posta sicuro.

![Schermata di configurazione trasporto posta](assets/installation-guide/step14-mail-transport.png)

Sono disponibili le seguenti impostazioni:

| Impostazione | Descrizione |
|---------|-------------|
| **Mail server host name** | Il FQDN di questa istanza del gateway di posta (es. `mail.example.com`). |
| **Mail server IP addresses** | Gli indirizzi IP pubblici di questo server. Aggiungi IP aggiuntivi se il server è raggiungibile su più indirizzi. |
| **Domains** | Ogni dominio gestito da questo gateway, insieme al suo host di relay (il server di posta interno a cui viene consegnata la posta in entrata). |
| **Default relay host** | Il relay SMTP predefinito per la consegna in uscita. |

Nella sezione **Advanced**, puoi facoltativamente configurare:

| Impostazione | Descrizione |
|---------|-------------|
| **Configure TLS** | Impostazioni del certificato TLS per le connessioni SMTP. |
| **Content filter** | L'endpoint del filtro contenuti interno (predefinito: `mxengine:1587`). |
| **Trusted networks** | Reti aggiuntive autorizzate a fare relay attraverso questo gateway. |

Azioni aggiuntive:

- Aggiungi domini aggiuntivi facendo clic su "Add domain", se necessario.
- Espandi la sezione Advanced per ottimizzare i parametri di trasporto della posta.

!!! note
    Assicurati che tutte le configurazioni dell'host di relay e dei domini siano corrette prima di procedere.

Una volta che la configurazione è stata rivista e completata, fai clic su "Apply configuration" per continuare.

### Passo 15 - Configurazione intestazioni whitelist

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Fai clic su **"Domains"**, quindi seleziona **"Whitelist headers"**.

Inserisci la chiave esattamente come configurata nel server di posta.

![Screenshot](assets/step_15_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Passo 16 - Certificati peer

![Responsabilità HIN](https://img.shields.io/badge/Responsabilita-HIN-orange)

I certificati peer vengono emessi dalla HIN Certification Authority (HIN CA) per i domini abilitati.

Una volta completato l'onboarding, naviga alla sezione **Peer certificates** nel dashboard e fai clic sul pulsante **"Sync certificates"** per sincronizzare i tuoi certificati peer dalla HIN CA.

![Schermata certificati peer](assets/installation-guide/step15-peer-certificates.png)

### Passo 17 - Validazione certificati peer

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Assicurati che il tuo dominio abbia ricevuto il suo certificato peer basato su policy in **"Domains"**. Lo stato di ciascun dominio deve essere **"Good"**.

![Screenshot](assets/step_17_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

!!! question
    Contatta il Supporto HIN via email o telefono (**<support@hin.ch>** / **0848 830 740**) se riscontri problemi.

### Passo 18 - Configurazione server di posta

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Se hai seguito l'approccio raccomandato esportando la chiave privata, importandola nell'HIN Gateway e mantenendo **lo stesso indirizzo IP** del MGW esistente, non sono richieste modifiche sul server di posta.

In caso contrario, configura il server di posta o i componenti associati in modo che il traffico venga instradato tramite il nuovo HIN Gateway. Controlla e aggiorna le seguenti impostazioni, se necessario:

- Relay SMTP / smart host
- Connettori
- Regole di trasporto
- Domini di routing

Vedere [Integrazione Exchange](Exchange-integration.md) per istruzioni dettagliate.

### Passo 19 - Test prima del passaggio

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Ripeti il "Passo 1.1 - Smoke test". In aggiunta allo smoke test, testa e conferma quanto segue:

**In uscita:**

- Verifica che il server di posta sia configurato per inviare email all'HIN Gateway utilizzando un relay SMTP o un connettore Exchange.
- Verifica che l'HIN Gateway possa inviare email a destinatari al di fuori della Comunità HIN.
- Verifica che l'HIN Gateway possa inviare email a destinatari all'interno della Comunità HIN tramite WireGuard.

**In entrata:**

- Verifica che le email crittografate possano essere ricevute dalla Comunità HIN tramite WireGuard. Un mittente del dominio `hin.ch` è il percorso di test più semplice.
- Verifica che le email crittografate possano essere ricevute dalla Comunità HIN tramite SMTP utilizzando S/MIME.
- Verifica che le risposte da mittenti al di fuori della Comunità HIN a una email sicura iniziale (HIN Mail-SEAL) possano raggiungere l'HIN Gateway.
- Verifica che le email in testo semplice possano essere ricevute da mittenti esterni al di fuori della Comunità HIN.

### Passo 20 - Validazione dopo il passaggio

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Conferma:

- Email consegnate
- Crittografia applicata
- Nessun ritardo o rimbalzo
- Logging riuscito

Compila il [**"Acceptance Report"**](https://www.hin.ch/files/pdf1/gateway-acceptance-en.pdf) e consegnalo al tuo rappresentante HIN.

### Passo 21 - Disattivazione del MGW esistente

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

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

### Passo 22 - Modifica della password della VM

![Responsabilità Cliente](https://img.shields.io/badge/Responsabilita-Cliente-success)

Assicurati che le credenziali della VM che ti sono state fornite inizialmente vengano modificate con la tua password definita e conservale in un luogo sicuro e protetto.

## Allegato 1 - Backup e ripristino delle impostazioni dell'appliance

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
