# Deployment Stargate su VMware ESXi tramite immagine

Distribuisci Stargate su VMware

## Ottenere il file immagine

- Scarica l'ultimo file immagine OVA (o OVF e VMDK se preferisci). Fare riferimento al [Catalogo VM](VM-Catalog.md?h=ova)

## Navigare all'interfaccia web di ESXi

- Fai clic su **Macchine virtuali**
- Fai clic su **Crea/Registra VM**
- Scegli "Distribuisci una macchina virtuale da un file OVF o OVA"
- Fai clic su **Avanti**
- Digita un nome per la VM
- Fai clic su **Avanti**
- Fai clic per selezionare i file e scegli il file immagine OVA (o OVF e VMDK se preferisci)
- Fai clic su **Avanti**
- Scegli uno storage da utilizzare
- Fai clic su **Avanti**
- Scegli Rete e Disco per il provisioning
- Fai clic su **Avanti**
- Fai clic su **Fine**

## Accedi e inizializza l'istanza Stargate

- Accedi alla console VM con l'utente `hinadmin` per configurare e installare i componenti Stargate.
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

    Per qualsiasi domanda o problema relativo al deployment e al funzionamento dell'appliance Stargate, contatta il supporto HIN.

    Includi informazioni rilevanti come il nome del cliente, la versione dell'appliance e screenshot/[log](../Docker-advanced.md#fornire-log-al-supporto) dove applicabile, per aiutarci a elaborare la tua richiesta in modo efficiente.
