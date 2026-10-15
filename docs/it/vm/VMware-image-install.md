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

!!! info "Disco dati incluso"
    L'OVA contiene già il disco dati dell'appliance (`VEREIGN-DATA`, montato su `/var/data`) — non c'è alcun disco aggiuntivo da collegare. Vedi [Guida all'installazione → Passo 4](../Installation-guide.md#passo-4-caricamento-dellimmagine-vm).

## Installare HIN Gateway

Dopo che la VM è stata creata con successo, procedi con i passaggi di installazione e onboarding come descritto nelle [istruzioni](../Installation-guide.md) fornite.

!!! tip "Supporto"

    Per qualsiasi domanda o problema relativo al deployment e al funzionamento dell'appliance Stargate, contatta il supporto HIN.

    Includi informazioni rilevanti come il nome del cliente, la versione dell'appliance e screenshot/[log](../Docker-advanced.md#fornire-log-al-supporto) dove applicabile, per aiutarci a elaborare la tua richiesta in modo efficiente.
