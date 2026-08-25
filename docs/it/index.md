# Istruzioni di deployment Stargate

**(DE) Hinweis zu Übersetzungen**
Für verlässliche Informationen nutzen Sie bitte die offiziellen Übersetzungen über den Sprachschalter ![web-icon](assets/web-icon.png){ width="16" } . Automatische Browser-Übersetzungen können Inhalte verfälschen.
{: style="font-size: 0.85em;" }

**(FR) Remarque concernant les traductions**
Pour obtenir des informations fiables, veuillez utiliser les traductions officielles accessibles via le sélecteur de langue ![web-icon](assets/web-icon.png){ width="16" } . Les traductions automatiques du navigateur peuvent déformer le contenu.
{: style="font-size: 0.85em;" }

**(IT) Avvertenza sulle traduzioni**
Per informazioni affidabili, utilizzare le traduzioni ufficiali accessibili tramite il selettore della lingua ![web-icon](assets/web-icon.png){ width="16" } . Le traduzioni automatiche del browser possono alterare i contenuti.
{: style="font-size: 0.85em;" }

**(EN) Translation notice**
For reliable information, please use the official translations available via the language selector ![web-icon](assets/web-icon.png){ width="16" } . Automatic browser translations may distort the content.
{: style="font-size: 0.85em;" }


![Logo](assets/stargate_visual.png)

[Cos'è Stargate?](https://www.hin.ch/de/services/hin-mail/hin-gateway.cfm){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

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

??? tip "Nota sul firewall"

    A seconda della configurazione del firewall o del NAT, potrebbe essere necessario consentire esplicitamente il traffico sulle porte richieste. Per maggiori dettagli, consultare la documentazione del firewall o della configurazione NAT.

    La VM deve poter **accettare connessioni in ingresso** sulle porte di servizio richieste e **inviare le risposte** al richiedente. Con un firewall stateful (ad esempio `iptables` con `conntrack`), il traffico di ritorno viene consentito automaticamente dalle regole `ESTABLISHED,RELATED`.

    Esempio di configurazione `iptables`:

    ```bash
    # Consenti il traffico di ritorno per le connessioni stabilite
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Consenti le connessioni TCP in ingresso verso le porte aperte
    iptables -A INPUT -p tcp -m multiport --dports 25,8084,19818 -j ACCEPT

    # Consenti le connessioni TCP in uscita verso le porte aperte
    iptables -A OUTPUT -p tcp -m multiport --dports 25,8084,19818 -j ACCEPT

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

| Porta | Protocollo | Scopo |
| :---- | :--------: | :---- |
| `25` | TCP | SMTP - ricezione di posta da server esterni |
| `8084` | TCP | HTTP - callback di sigillatura da servizio di sigillatura remoto |
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
| hub.docker.com | `443` | TCP | Registry delle immagini Docker |
| mxengine-dev.k8s.vereign-cdn.com | `443` | TCP | Servizio di sigillatura remoto |
| smimekeys-ca-dev.k8s.vereign-cdn.com | `443` | TCP | Servizio CA S/MIME |
| loki.example.com | `443` | TCP | Invio log (Alloy → Loki, opzionale) |
| Server di aggiornamento di Alpine, AlmaLinux, ecc. | `80` | TCP | Vari server di aggiornamento |
| Server di posta di destinazione | `25` | TCP | Consegna posta in uscita (tramite ricerca MX) |
| Server DNS | `53` | UDP+TCP | In uscita verso server DNS pubblici |
| Server NTP | `123` | UDP | NTP sincronizza gli orologi di computer, server, dispositivi di rete e macchine virtuali con fonti di tempo precise |

## Contattaci

!!! tip "Supporto"

    Per qualsiasi domanda o problema relativo al deployment e al funzionamento dell'appliance HIN Mail (Stargate), contatta il supporto HIN.

    Includi informazioni rilevanti come il nome del cliente, la versione dell'appliance e screenshot/[log](./Docker-advanced.md#fornire-log-al-supporto) dove applicabile, per aiutarci a elaborare la tua richiesta in modo efficiente.

---

[![documentation](https://img.shields.io/github/check-runs/Health-Info-Net-AG/Stargate-deployment/main?nameFilter=Build%20documentation&style=for-the-badge&label=Documentation%20Build)](https://github.com/Health-Info-Net-AG/Stargate-deployment/actions/workflows/documentation.yml)
[![commit](https://img.shields.io/endpoint?style=for-the-badge&url=https://health-info-net-ag.github.io/Stargate-deployment/badges/build.json)](https://github.com/Health-Info-Net-AG/Stargate-deployment)
