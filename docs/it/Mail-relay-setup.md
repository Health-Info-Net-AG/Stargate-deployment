# Configurazione del relay di posta Stargate

## Creare un relay Stargate per un dominio di posta ospitato in Microsoft Office 365

Per il relay, abbiamo bisogno di una VM o di un server con un indirizzo IP statico reale.

In questo esempio utilizzeremo una VM con indirizzo IP `128.140.117.200` e nome host `mail.vrgnservices.eu` per inoltrare la posta per il dominio `vrgnservices.eu`.

## Configurare i record DNS

Vedi la [Guida alla configurazione DNS](./DNS-setup.md) per istruzioni complete su tutti i record richiesti (A, MX, SPF, PTR, DMARC, DKIM).

Esempio rapido per il dominio `vrgnservices.eu` con IP Stargate `128.140.117.200`:

* **Record A**: `mail.vrgnservices.eu` → `128.140.117.200`
* **Record MX**: `MX @ 15 mail.vrgnservices.eu.` (priorità più alta rispetto all'Exchange MX esistente a 20)
* **Record SPF**: `v=spf1 ip4:128.140.117.200 include:spf.protection.outlook.com -all`

Verifica:

```shell
# host mail.vrgnservices.eu
mail.vrgnservices.eu ha indirizzo 128.140.117.200
```

```shell
# host -t mx vrgnservices.eu
vrgnservices.eu la posta è gestita da 20 vrgnservices-eu.mail.protection.outlook.com.
vrgnservices.eu la posta è gestita da 15 mail.vrgnservices.eu.
```

```shell
# host -t txt vrgnservices.eu|grep v=spf1
vrgnservices.eu testo descrittivo "v=spf1 ip4:128.140.117.200 include:spf.protection.outlook.com -all"
```

## Installare i container docker compose di Stargate

[Deployment Stargate](./Docker-deploy.md)

### Requisiti

* **2 core CPU** (minimo)
* **4 GB di RAM** (minimo)
* **20 GB di storage** (minimo)
* **Accesso root**: Deve essere eseguito come root o con `sudo`
* **Distribuzioni supportate**:
    * Distribuzioni compatibili con RHEL 8, 9 e 10 come Alma Linux, Rocky Linux, CentOS Stream
    * Ubuntu 22 e 24
    * Debian 11, 12 e 13
* **Indirizzo IPv4 reale**
* **Record DNS validi**: Il dominio deve avere:
    * Record MX che puntano ai server di posta
    * Record SPF che definisce le reti di invio consentite

Lo script installa tutti i componenti e li avvia. I domini di posta e il nome host di Stalwart vengono poi configurati in fase di esecuzione tramite la pagina `/mail` del dashboard (il demone mtaconf estrae le impostazioni di relay di posta necessarie dal DNS in base a quei domini).

## Configurare Exchange

Dobbiamo configurare connettori e una regola di trasporto in Exchange per inoltrare tutta la posta in uscita al relay Stargate e consentire la posta in entrata da esso.

Naviga su [https://admin.exchange.microsoft.com/#/connectors](https://admin.exchange.microsoft.com/#/connectors)

### Connettore in uscita

Crea un connettore di posta in uscita, fai clic su "Aggiungi":

Seleziona "Connessione da": "Office 365" "Connessione a": "server di posta della tua organizzazione", fai clic su "Avanti".

![screenshot](./assets/new_connector_outgoing1.png)

Dagli un nome come "From Office 365 to Stargate relay server" e seleziona "Mantieni intestazioni email interne di Exchange", fai clic su "Avanti".

![screenshot](./assets/new_connector_outgoing2.png)

Seleziona "Solo quando ho una regola di trasporto configurata che reindirizza i messaggi a questo connettore", fai clic su "Avanti".

![screenshot](./assets/new_connector_outgoing3.png)

Inserisci l'indirizzo IP del server relay Stargate, fai clic su "+", fai clic su "Avanti".

![screenshot](./assets/new_connector_outgoing4.png)

Seleziona "Qualsiasi certificato digitale, inclusi i certificati auto-firmati", fai clic su "Avanti".

![screenshot](./assets/new_connector_outgoing5.png)

Inserisci un indirizzo email valido per il tuo dominio, fai clic su "+", fai clic su "Convalida", fai clic su "Avanti".

![screenshot](./assets/new_connector_outgoing6.png)

Fai clic su "Crea connettore".

![screenshot](./assets/new_connector_outgoing7.png)

Fai clic su "Aggiungi un altro connettore".

![screenshot](./assets/new_connector_outgoing8.png)

### Connettore in entrata

Crea un connettore di posta in entrata, scegli "Connessione da": "Server di posta della tua organizzazione", fai clic su "Avanti".

![screenshot](./assets/new_connector_incoming1.png)

Dagli un nome come "Receive mail from Stargate relay server" e seleziona "Mantieni intestazioni email interne di Exchange", fai clic su "Avanti".

![screenshot](./assets/new_connector_incoming2.png)

Seleziona "Verificando che l'indirizzo IP del server di invio corrisponda a uno dei seguenti indirizzi IP", digita l'indirizzo IP del server Stargate, fai clic su "+", fai clic su "Avanti".

![screenshot](./assets/new_connector_incoming3.png)

Fai clic su "Crea connettore".

![screenshot](./assets/new_connector_incoming4.png)

Fai clic su "Fine".

![screenshot](./assets/new_connector_incoming5.png)

Ecco come appare quando è completato:

![screenshot](./assets/new_connector_incoming6.png)

### Regola di trasporto

Crea la regola di trasporto. Naviga su [https://admin.exchange.microsoft.com/#/transportrules](https://admin.exchange.microsoft.com/#/transportrules)

Fai clic su "+Aggiungi una regola" --> "Crea una nuova regola".

![screenshot](./assets/new_transport_rule1.png)

Dagli un nome come "Relay all mail to Stargate except mail coming from it", scegli "Applica questa regola se" "Il destinatario:" "è esterno/interno" "Fuori dall'organizzazione", fai clic su "Salva".  

![screenshot](./assets/new_transport_rule2.png)

Scegli "Fai quanto segue" "Reindirizza il messaggio al seguente connettore" "From Office 365 to Stargate relay server", fai clic su "Salva".

![screenshot](./assets/new_transport_rule3.png)

Scegli "Eccetto se L'indirizzo IP del mittente si trova in uno di questi intervalli" inserisci l'indirizzo IP del server Stargate, fai clic su "Aggiungi", controlla l'indirizzo IP e fai clic su "Salva".

Questo è necessario per prevenire loop di posta, poiché questa regola si applica anche ad altri domini ospitati in Office 365.  

![screenshot](./assets/new_transport_rule4.png)

Ora dovrebbe apparire così, fai clic su "Avanti":

![screenshot](./assets/new_transport_rule5.png)

Fai clic su "Avanti".

![screenshot](./assets/new_transport_rule6.png)

Fai clic su "Fine".

![screenshot](./assets/new_transport_rule7.png)

Fai clic su "Fine".

![screenshot](./assets/new_transport_rule8.png)

![screenshot](./assets/new_transport_rule9.png)

Fai clic sulla regola e imposta "Abilita o disabilita regola" su "Abilitato"  

![screenshot](./assets/new_transport_rule10.png)
