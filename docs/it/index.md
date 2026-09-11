# Istruzioni di deployment Stargate

--8<-- "docs/assets/Translation_notice.md"

![Logo](assets/stargate_visual.png)

[Cos'è Stargate?](https://www.hin.ch/de/services/hin-mail/hin-gateway.cfm){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Prerequisiti

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Assicurati che tutti i passaggi preparatori necessari siano stati completati prima dell'inizio delle attività di migrazione o di nuova installazione dell'HIN Gateway.

I seguenti elementi devono essere disponibili o confermati prima dell'installazione:

- **Le credenziali ti verranno fornite da HIN**
    - Credenziali VM
    - Credenziali Keycloak
    - Codice di attivazione

- **Esportazione della/e chiave/i privata/e**

!!! info
    L'esportazione delle chiavi private è prevista solo per i clienti che passano da un MGW esistente a un nuovo HIN Gateway

    - Se stai lavorando su una macchina Windows che ha accesso alla VM del Mail Gateway tramite la porta 22, possiamo assisterti durante la chiamata per abilitare l'esportazione della chiave privata dal MGW.
    - Se non disponi di una macchina di questo tipo, contatta il Supporto HIN via e-mail o telefono (support@hin.ch / 0848 830 740) per aiutarti a stabilire una connessione di supporto tramite System Administration → Support Connection → Connect.

!!! danger "Per i clienti con più domini"

    **Nota:** applicabile a tutti gli scenari di migrazione multi-dominio! 

    Per ridurre il tempo necessario a eseguire la migrazione, incoraggiamo i clienti a completare i seguenti passaggi prima della data e della sessione di migrazione pianificate: 
    
    * Esporta la chiave privata per ciascun dominio.
    * Identifica e documenta il flusso di posta in entrata e in uscita per ciascun dominio.
    
    Contatta il Supporto HIN per ottenere il codice di sblocco necessario per esportare le chiavi private.
    


- **Scarica l'ultima versione** dell'[immagine VM](vm/VM-Catalog.md)
- Requisiti **firewall** per WireGuard.
  Configura la porta WireGuard 19818 (TCP/UDP) nel tuo firewall:
    - Traffico in entrata e in uscita
    - Consenti il traffico: any-to-HIN Gateway e HIN Gateway-to-any
- L'**accesso DHCP** dovrebbe essere disponibile. Per maggiori informazioni consulta le "Installation Guidelines".

- **Requisiti di backup** - vedi "Allegato 1 - Backup e ripristino delle impostazioni dell'appliance".

!!! info
    I requisiti di backup sono previsti solo per i clienti che passano da un MGW esistente a un nuovo HIN Gateway

- Conferma che l'MGW esistente **non** verrà eliminato fino al completamento dell'accettazione.

!!! info
    Mantenere disponibile l'MGW esistente fino al completamento del report di accettazione è previsto solo per i clienti che passano da un MGW esistente a un nuovo HIN Gateway

- Accesso a DNS, connettori del server di posta, regole di trasporto e impostazioni di relay.

## Guida rapida

### Opzioni di installazione

* Installazione tramite immagine VM:
    * [Installazione tramite immagine VM Azure](vm/Azure-image-install.md)
    * [Installazione tramite immagine VM Windows 11 Pro (Hyper-V)](vm/Windows11pro-image-install.md)
    * [Installazione tramite immagine VM VMware](vm/VMware-image-install.md)
    * [Installazione tramite immagine VM Proxmox](vm/Proxmox-image-install.md)
    * [Cloudscale.ch](vm/Cloudscale-image-install.md)

!!! tip "🖨️"
    Puoi ottenere questa documentazione stampata o salvata come PDF, visita la nostra [Visualizzazione pagina stampa](print_page).

### Integrazione con Exchange

* [Integrazione con Exchange](Exchange-integration.md) - Configura i connettori e le regole di trasporto di Microsoft Exchange (Online e On-Premises) per instradare la posta attraverso Stargate

### Requisiti del server

|      | Minimo | Consigliato |
| :--- | :-----: | :--------: |
| CPU, Core | 4 | 6 |
| RAM, GB | 8 | 12 |
| SSD, GB | 60 | 60 |

#### Requisiti comuni

* **Accesso root**: Deve essere eseguito come root o con `sudo`
* Distribuzioni supportate:
    * Distribuzioni compatibili con RHEL 8, 9 e 10 come Alma Linux, Rocky Linux, CentOS Stream
    * Ubuntu 22 e 24
    * Debian 11, 12 e 13
* **Indirizzo IPv4 reale**
* **Record DNS validi**. Il dominio deve avere:
    * Record MX che puntano ai server di posta
    * Record SPF che definisce le reti di invio consentite
    * Il server deve essere in grado di risolvere il DNS (record MX, SPF, A)
    * Utilizzato per il routing della posta e l'inserimento nella whitelist delle reti basato su SPF

#### Accesso di rete in entrata (il firewall deve consentire)

| Porta | Protocollo | Scopo |
| :---- | :--------: | :---- |
| `25` | TCP | SMTP - ricezione di posta da server esterni |
| `19818` | UDP+TCP | WireGuard - tunnel crittografato per la comunicazione agente-agente. Leggi la nostra [Valutazione di sicurezza WireGuard](https://www.hin.ch/files/pdf1/wireguard-tunnel-en.pdf) |

#### Accesso in ingresso alla VM (dal computer di amministrazione alla VM HIN Gateway)

!!! info
    Queste regole del firewall devono essere applicate solo tra il computer di amministrazione e la VM HIN Gateway. Non è necessario esporre queste porte a Internet.

| Porta | Protocollo | Scopo |
| :---- | :--------: | :---- |
| `80` | TCP | Reindirizza il traffico HTTP a HTTPS |
| `443` | TCP | Utilizzata per gestire HIN Gateway tramite il dashboard web |
| `8180` | TCP | Utilizzata da Keycloak per autenticare gli utenti del dashboard di HIN Gateway |
| `8190` | TCP | Opzionale. Necessaria per la risoluzione dei problemi e la visualizzazione dei log |
| `22` | TCP | Opzionale. Necessaria per la risoluzione dei problemi e la modifica della configurazione |

#### Accesso di rete in uscita (il server deve raggiungere)

| Destinazione | Porta | Protocollo | Scopo |
| :----------- | :---: | :--------: | :---- |
| `registry-1.docker.io`, `auth.docker.io`, `production.cloudflare.docker.com` | `443` | TCP | Registry delle immagini Docker Hub |
| `quay.io` | `443` | TCP | Registry dei container (Keycloak, oauth2-proxy) |
| `github.com` | `443` | TCP | Repository delle policy (policy-sync) |
| Il proprio endpoint Loki (es. `loki.example.com`) | `443` | TCP | Opzionale. Necessario solo se si fornisce una propria istanza Loki a cui lo stack deve inviare i log (Alloy → Loki) |
| Server di aggiornamento di Alpine, AlmaLinux, ecc. | `80` | TCP | Vari server di aggiornamento |
| Server di posta di destinazione | `25` | TCP | Consegna posta in uscita (tramite ricerca MX) |
| Server DNS | `53` | UDP+TCP | In uscita verso server DNS pubblici |
| Server NTP | `123` | UDP | NTP sincronizza gli orologi di computer, server, dispositivi di rete e macchine virtuali con fonti di tempo precise |
| Peer WireGuard (rete HIN) | `19818` | UDP+TCP | WireGuard - tunnel crittografato per la comunicazione agente-agente |
| `witness-{1,2,3}.verify-mail.hin-infra.ch` | `443` | TCP | Pool di witness KERI di HIN - richiesto per la verifica delle identità degli agenti (idagent / watcher) |
| `app.hin.ch` | `443` | TCP | Elenco membri / domini di posta HIN (mxengine) |
| `apisix.verify-mail.hin-infra.ch` | `443` | TCP | Registrazione del gateway HIN durante l'onboarding (dashboard) |


??? note "Avviso importante per l'esercizio su Microsoft Azure"

    **Esercizio su Microsoft Azure**
     
     Per il collegamento SMTP Relay dell'HIN Gateway a Exchange Online, deve essere possibile il traffico in uscita tramite la porta TCP 25. 
     
     Microsoft Azure blocca le connessioni in uscita tramite la porta 25 nella maggior parte dei modelli di abbonamento. HIN non può influire sulla disponibilità o sull'attivazione di questa porta da parte di Microsoft. L'esercizio dell'HIN Gateway su Azure non è quindi uno scenario di implementazione supportato come standard. Esistono eccezioni, in particolare per [alcuni abbonamenti Enterprise di Microsoft](https://learn.microsoft.com/en-us/troubleshoot/azure/virtual-network/troubleshoot-outbound-smtp-connectivity). Verificate quindi, prima di procedere all'installazione su Azure, se il vostro abbonamento consente il traffico SMTP in uscita tramite la porta TCP 25.
     
     In caso di domande sulla variante operativa più adatta, si prega di contattare tempestivamente il vostro contatto presso HIN..


??? tip "Nota sul firewall"

    A seconda della configurazione del firewall o del NAT, potrebbe essere necessario consentire esplicitamente il traffico sulle porte richieste. Per maggiori dettagli, consultare la documentazione del firewall o della configurazione NAT.

    La VM deve poter **accettare connessioni in ingresso** sulle porte di servizio richieste e **inviare le risposte** al richiedente. Con un firewall stateful (ad esempio `iptables` con `conntrack`), il traffico di ritorno viene consentito automaticamente dalle regole `ESTABLISHED,RELATED`.

    Esempio di configurazione `iptables`:

    ```bash
    # Consenti il traffico di ritorno per le connessioni stabilite
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Consenti le connessioni TCP in ingresso verso le porte aperte
    iptables -A INPUT -p tcp -m multiport --dports 25,19818 -j ACCEPT

    # Consenti le connessioni TCP in uscita verso le porte aperte
    iptables -A OUTPUT -p tcp -m multiport --dports 25,19818 -j ACCEPT

    # Consenti la porta UDP 19818 in ingresso per WireGuard
    iptables -A INPUT -p udp --dport 19818 -j ACCEPT

    # Consenti la porta UDP 19818 in uscita per WireGuard
    iptables -A OUTPUT -p udp --dport 19818 -j ACCEPT

    # Servizi aggiuntivi che la VM deve poter raggiungere
    # DNS
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

    # NTP
    iptables -A OUTPUT -p udp --dport 123 -j ACCEPT

    # HTTP
    iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT

    # HTTPS
    iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
    ```

## Contattaci

!!! tip "Supporto"

    Per qualsiasi domanda o problema relativo al deployment e al funzionamento dell'appliance HIN Mail (Stargate), contatta il supporto HIN.

    Includi informazioni rilevanti come il nome del cliente, la versione dell'appliance e screenshot/[log](./Docker-advanced.md#fornire-log-al-supporto) dove applicabile, per aiutarci a elaborare la tua richiesta in modo efficiente.

---

[![documentation](https://img.shields.io/github/check-runs/Health-Info-Net-AG/Stargate-deployment/main?nameFilter=Build%20documentation&style=for-the-badge&label=Documentation%20Build)](https://github.com/Health-Info-Net-AG/Stargate-deployment/actions/workflows/documentation.yml)
[![commit](https://img.shields.io/endpoint?style=for-the-badge&url=https://health-info-net-ag.github.io/Stargate-deployment/badges/build.json)](https://github.com/Health-Info-Net-AG/Stargate-deployment)
