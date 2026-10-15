## v1.1.7

*Rilasciata il 14 ottobre 2026.*

### Novità e miglioramenti

- I relay in uscita possono ora autenticarsi con nome utente e password per ogni dominio.
- I relay in entrata possono ora autenticarsi con nome utente e password per ogni dominio.
- Etichetta di riservatezza di Outlook: le e-mail contrassegnate come riservate nel campo dell'etichetta di riservatezza di Microsoft vengono ora recapitate tramite HIN Mail con crittografia ai destinatari che non sono membri HIN.
- Sincronizzazione dell'ora: HIN Gateway utilizza ora NTP per mantenere l'orologio sincronizzato con server di riferimento orario affidabili. NTP può essere configurato nella dashboard.
- Inoltro dei log: i log possono ora essere inviati a Loki tramite un token API.
- Migrazione da v0.5.x: uno script di migrazione esporta la chiave e il certificato S/MIME nel passaggio da v0.5.x a v0.6.x o successive.
- Impostazioni di rete predefinite: il server DNS predefinito è ora 8.8.8.8 (in precedenza 1.1.1.1). Il server DNS può essere modificato durante la configurazione.

### Correzioni

- Corretti i riavvii ripetuti (fino a tre di seguito) dopo la modifica delle impostazioni di rete.
- Corretto un errore durante l'onboarding quando l'importazione del certificato iniziava prima che la sincronizzazione dell'Iris Agent fosse completata.
- Al momento dell'aggiunta, i domini vengono ora ripuliti dagli spazi superflui e convertiti in minuscolo.
- Corretto il messaggio di conferma dopo l'aggiornamento di un peer.
- La notifica di nuova versione è ora tradotta in tutte le lingue supportate.

## v0.6.2

*Rilasciata il 24 settembre 2026.*

Questa release correttiva rafforza la sicurezza di HIN Gateway, corregge la versione di Stalwart e disattiva il filtro antispam.

### Novità e miglioramenti

- Include Stalwart v0.16.23, compatibile con il set di regole più recente per il filtro antispam.
- Il set di regole antispam e lo SpamFilter sono disattivati, in modo che una nuova release upstream del set di regole non possa compromettere una versione bloccata.

### Correzioni

- Aggiornata la gestione del filtro antispam nello script di provisioning e migliorata la registrazione degli errori.
- Aggiornata l'immagine di Stalwart alla versione v0.16.23 e aggiunta una funzione per la rimozione dei server DNSBL.

## v0.6.1

*Rilasciata il 4 settembre 2026.*

Questa release di manutenzione rafforza la sicurezza di HIN Gateway, corregge la gestione delle intestazioni e-mail e migliora le istruzioni per aggiornamenti e migrazioni.

### Novità e miglioramenti

- **Sicurezza:** l'accesso esterno alle porte dei servizi interni è stato limitato e sono state rafforzate le impostazioni di autenticazione e le autorizzazioni.
- **Aggiornamenti e rollback:** aggiunte le istruzioni per aggiornare HIN Gateway e per tornare a una versione precedente, disponibili in inglese, tedesco, francese e italiano.
- **Istruzioni di migrazione:** aggiornati i controlli delle e-mail prima e dopo la migrazione e aggiunte le traduzioni della guida multidominio.

### Correzioni

- Corretta la gestione delle intestazioni e-mail specifiche di HIN.
- Aggiunta ai download della v0.6.0 l'immagine del disco dati VMware mancante.

## v0.6.0

*Rilasciata il 31 agosto 2026.*

Questa release introduce il supporto per le migrazioni multidominio, la configurazione dei relay a livello di dominio, l'autenticazione delle e-mail (ad esempio DKIM e ARC) e miglioramenti a installazione, sicurezza e stabilità.

### Novità e miglioramenti

- **Configurazioni multidominio:** è ora possibile configurare o migrare più domini su un unico HIN Gateway. La guida aggiornata copre migrazioni complete e graduali, compresi gli scenari di rollback.
- **Configurazione per dominio:** la configurazione dei relay è ora disponibile per ogni dominio.
- **Autenticazione delle e-mail:** la firma DKIM e ARC e la verifica DKIM, ARC, SPF e DMARC possono ora essere configurate per ogni dominio. I record DNS necessari vengono mostrati direttamente in HIN Gateway.
- **Installazione e migrazione:** le istruzioni aggiornate coprono ora nuove installazioni, migrazioni a dominio singolo e multidominio, integrazione con Exchange, instradamento della posta, rete e test TLS.
- **Migrazione all'appliance:** è disponibile una procedura documentata per spostare un'installazione Docker Compose esistente sull'appliance HIN Gateway basata su immagine.
- **Backup e ripristino:** i dati persistenti si trovano ora in una posizione uniforme, il ripristino è più sicuro e vengono mostrati avvisi quando le versioni del backup e della destinazione differiscono.
- **Diagnostica e sicurezza:** sono stati migliorati i controlli di stato, la registrazione dei log e la raccolta dei dati diagnostici. Gli script di installazione e di ripristino proteggono ora meglio le credenziali e i dati di backup.

### Correzioni

- Migliorata l'inizializzazione iniziale delle impostazioni di Vault e WireGuard.
- Migliorato l'avvio dei servizi su macchine virtuali più lente.
- Corretti casi limite relativi alle operazioni di backup e ripristino.
- Corretti risultati imprecisi dei controlli di stato e la gestione dei valori di fallback della configurazione.

### Informazioni importanti per le migrazioni all'appliance

Per spostare un'installazione Docker Compose esistente sull'appliance basata su immagine, seguire la guida alla migrazione dedicata. Il ripristino di un backup sostituisce tutti i dati sull'appliance di destinazione. Se il suo indirizzo IP pubblico cambia, HIN deve aggiornare la registrazione WireGuard centrale.

## v0.5.3

*Rilasciata il 29 luglio 2026. Hotfix applicato il 5 agosto 2026.*

Questa release migliora il recapito delle e-mail, la gestione dei certificati, la dashboard e la risoluzione dei problemi. SEAL non subisce modifiche.

### Hotfix del 5 agosto 2026

Corretto un problema nel processo di importazione dei certificati, per cui il dominio non veniva collegato correttamente al peer HIN Gateway corrispondente.

La correzione è stata applicata ai servizi centrali. Le installazioni locali su macchina virtuale non erano interessate e non hanno richiesto alcun aggiornamento.

### Novità e miglioramenti

- È ora possibile configurare relay separati per mittenti e destinatari.
- Le e-mail a destinatari esterni alla rete HIN possono essere inviate tramite il relay SMTP configurato.
- È stato rimosso il precedente limite orario di elaborazione delle e-mail.
- È stata migliorata la corrispondenza di mittenti e destinatari per le e-mail in entrata e in uscita.
- Prima dell'emissione di un certificato S/MIME viene ora verificata la proprietà del dominio.
- I certificati dei peer possono ora essere cercati e ordinati.
- I certificati TLS possono essere generati direttamente dalla dashboard.
- Alla panoramica dei peer sono state aggiunte la ricerca e la paginazione.
- La ricerca nei log è ora più semplice.
- Viene mostrato un avviso quando la chiave privata non è stata importata.
- Sono stati migliorati i messaggi di errore e le informazioni diagnostiche.

### Correzioni

- Migliorata la selezione del certificato durante l'invio di e-mail crittografate.
- Corretta la gestione dei messaggi crittografati firmati con certificati revocati o non attendibili.
- Corretto un problema con i token di aggiornamento della sessione.
- Corretti diversi errori nei moduli di configurazione e di gestione dei domini.
- Corretti la selezione del prefisso internazionale e la convalida dei campi.
- Corretto un problema durante la rigenerazione di un codice di attivazione.
- Corretta l'elaborazione di alcune informazioni sul firmatario S/MIME.
- Aggiunte le informazioni di connessione mancanti nei log di recapito del tunnel.
- Le impostazioni di rete vengono ora reimpostate correttamente dopo la modifica dell'indirizzo IP della macchina virtuale.

## v0.5.1

La nostra prima release.
