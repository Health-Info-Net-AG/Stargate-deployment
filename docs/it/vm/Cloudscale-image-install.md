# Deployment HIN Gateway su Cloudscale tramite immagine

## Ottenere l'URL del file immagine

- Fai riferimento al [Catalogo VM](VM-Catalog.md?h=qcow2) per le immagini disponibili con URL.
- Copia l'URL `qcow2` negli appunti.

## Importare il file immagine in Cloudscale

- Nell'interfaccia web di Cloudscale, naviga al menu "Immagini personalizzate" e fai clic su "Importa un'immagine personalizzata".
- Imposta un **Nome immagine** appropriato.
- Definisci uno **Slug**, ad esempio "stargate".
- Incolla l'URL dell'immagine HIN Gateway nel campo **URL di download**.
- Imposta **Formato sorgente** sul formato di caricamento, consigliato: `qcow2`.
- Configura eventuali impostazioni aggiuntive se necessario.
- Fai clic su **Importa**.

## Creare una VM

- Naviga su **Server** e fai clic su **Avvia un nuovo server**.
- Inserisci il tuo **FQDN** o nome host preferito.
- In **Sistema operativo**, seleziona **Immagini personalizzate** e scegli l'immagine importata.
- In **Flavor di calcolo**, seleziona **Flex-4-2** o **Flex-8-2** a seconda del carico previsto (può essere regolato in seguito). Vedi [Requisiti del server](../index.md#requisiti-del-server) per i dettagli.
- In **Capacità di archiviazione**, imposta almeno **30 GB**. Fare riferimento ai [Requisiti del server](../index.md#requisiti-del-server).
- In **Posizione del server**, seleziona la zona preferita.
- In **Gestione della rete**, abilita solo **IPv4** se l'istanza HIN Gateway deve essere accessibile via Internet (es., per Office 365).
- In **Sicurezza di accesso**, seleziona la tua chiave SSH (utilizzabile con l'utente `almalinux`).
- Nella sezione **Password**, imposta una password sicura a tua scelta.

!!! tip "Senza una password, l'autenticazione SSH tramite password è disabilitata"
    Per il primo accesso devi comunque utilizzare la password iniziale fornita da HIN. Tuttavia, se non imposti una nuova password, cloud-init disabiliterà l'autenticazione SSH tramite password per tutti gli utenti, consentendo l'accesso SSH solo tramite chiave pubblica.

- Fai clic su **Avvia**.

!!! warning "Collega prima il disco dati"
    Prima del primo avvio, collega un secondo disco vuoto di almeno 30 GB. Al primo avvio l'appliance lo formatta come disco dati (`VEREIGN-DATA`, montato su `/var/data`) e vi conserva tutta la configurazione e i dati; senza di esso l'avvio fallisce ed esegue il rollback. Vedi [Guida all'installazione → Passo 4](../Installation-guide.md#passo-4-caricamento-dellimmagine-vm).

## Accedi e inizializza l'istanza HIN Gateway

- Accedi alla console VM con l'utente `hinadmin` per configurare e installare i componenti HIN Gateway.
- Per ottenere la password `hinadmin`, invia un'email a <support@hin.ch> con oggetto: **"Password required for VM installation."**

[Clicca qui per inviare un'email](mailto:support@hin.ch?subject=Password%20required%20for%20VM%20installation.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20password%20for%20a%20VM%20installation.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

```shell
sudo su -
cd ~/stargate-deployment/docker-compose/
```

- Utilizza vi/nano per modificare `customer-config.sh`
- I dettagli di configurazione si trovano nel [README - Passo 1: Configurare le impostazioni cliente](../Docker-deploy.md#passo-1-configurare-le-impostazioni-cliente)
- Esegui lo script di installazione:

```shell
./scripts/install.sh
```

!!! tip "Supporto"

    Per qualsiasi domanda o problema relativo al deployment e al funzionamento dell'appliance HIN Gateway, contatta il supporto HIN.

    Includi informazioni rilevanti come il nome del cliente, la versione dell'appliance e screenshot/[log](../Docker-advanced.md#fornire-log-al-supporto) dove applicabile, per aiutarci a elaborare la tua richiesta in modo efficiente.
