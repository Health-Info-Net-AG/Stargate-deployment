# Deployment Stargate su Azure tramite immagine

Distribuisci Stargate su Azure

## Requisiti della porta 25 (SMTP) di Azure

!!! warning
    Prima di iniziare l'installazione su Microsoft Azure, esamina i seguenti requisiti relativi alla connettività SMTP in uscita sulla porta 25. Saltare questo passaggio potrebbe causare il fallimento della consegna delle email dopo l'installazione.

La disponibilità della porta 25 dipende dal tipo di abbonamento Azure:

- :white_check_mark: **Enterprise Agreement (EA) o MCA-E** - Lo SMTP in uscita sulla porta 25 non è bloccato. Nota che i domini esterni potrebbero comunque rifiutare le email - questo è al di fuori del controllo di Azure.
- :white_check_mark: **Enterprise Dev/Test** - Bloccato per impostazione predefinita, ma può essere rimosso. Per richiedere la rimozione, vai a *Diagnostica e risoluzione* > *Impossibile inviare email (SMTP-Port 25)* nella risorsa Rete virtuale di Azure nel portale Azure.
- :x: **Tutti gli altri tipi di abbonamento** - Bloccato e **non può essere sbloccato**.

Riferimento: [Risolvere i problemi di connettività SMTP in uscita in Azure](https://learn.microsoft.com/en-us/troubleshoot/azure/virtual-network/troubleshoot-outbound-smtp-connectivity)

## Ottenere il file immagine

- Scarica l'ultimo file immagine VHD. Fare riferimento al [Catalogo VM](VM-Catalog.md?h=vhd)

## Caricare il file immagine VHD di Azure

- Naviga su <https://portal.azure.com/#home>
- Fai clic su **Account di archiviazione**.
- Seleziona l'account di archiviazione da utilizzare o creane uno nuovo.
- Fai clic su **Servizio Bloc** e poi **Contenitori**.
- Seleziona il contenitore in cui caricare il file o creane uno nuovo se non hai un contenitore.
- Fai clic su **Carica** e scegli il file immagine VHD.
- Assicurati che il tipo di blob sia Page Blob.

## Creare l'immagine

- Naviga su <https://portal.azure.com/#home>
- Fai clic su **Immagini**.
- Fai clic su **Crea**.
- Scegli il gruppo di risorse da utilizzare o creane uno nuovo.
- Digita un nome per l'immagine.
- Scegli il tipo di sistema operativo **Linux** e **Generazione VM Gen 2**
- In Storage blob, fai clic su sfoglia e seleziona l'immagine VHD appena caricata.
- Fai clic su **Rivedi e crea**.
- Fai clic su **Crea**.

## Creare una VM

- Naviga su <https://portal.azure.com/#home>
- Fai clic su **Macchine virtuali**.
- Fai clic su **Crea** e scegli Macchina virtuale dal menu a tendina.
- Scegli il gruppo di risorse.
- Digita un nome per la VM.
- In Immagine, fai clic su "**Vedi tutte le immagini**", fai clic su "**Le mie immagini**" e scegli la nuova immagine creata.
- Scegli la dimensione della VM.
- Scegli il tipo di autenticazione.
- Fai clic su **Avanti: Dischi**
- Seleziona una dimensione del disco del sistema operativo di almeno 20 GiB. Fare riferimento ai [Requisiti del server](../index.md#requisiti-del-server).
- Fai clic su **Rivedi + crea**
- Fai clic su **Crea**

## Trovare l'indirizzo IP pubblico della nuova VM e aggiungere le regole del firewall in entrata

- Naviga su <https://portal.azure.com/#home>
- Fai clic su **Macchine virtuali**.
- Fai clic sulla nuova VM.
- Puoi vedere l'indirizzo IP pubblico sotto "IP pubblico della scheda di rete primaria"
- Scorri verso il basso fino a Rete e fai clic su di essa
- Fai clic su **+ Crea regola di porta**, Regola di porta in entrata, Intervalli di porte di destinazione 25, Protocollo TCP, chiamala SMTP, ripeti lo stesso passaggio con l'intervallo di porte di destinazione 1587 e chiamala mxengine

## Accedi e inizializza l'istanza Stargate

- Accedi alla VM con l'utente scelto durante la creazione della VM e l'indirizzo IP pubblico della nuova VM:
- Per ottenere la password `hinadmin`, invia un'email a <support@hin.ch> con oggetto: **"Password required for VM installation."**

[Clicca qui per inviare un'email](mailto:support@hin.ch?subject=Password%20required%20for%20VM%20installation.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20password%20for%20a%20VM%20installation.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

```shell
ssh hinadmin@11.22.33.44 
```

- Una volta effettuato l'accesso alla VM:

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

    Per qualsiasi domanda o problema relativo al deployment e al funzionamento dell'appliance Stargate, contatta il supporto HIN.

    Includi informazioni rilevanti come il nome del cliente, la versione dell'appliance e screenshot/[log](../Docker-advanced.md#fornire-log-al-supporto) dove applicabile, per aiutarci a elaborare la tua richiesta in modo efficiente.
