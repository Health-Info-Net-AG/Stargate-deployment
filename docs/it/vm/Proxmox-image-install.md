# Deployment Proxmox tramite immagine

Distribuisci Stargate su Proxmox

## Ottenere l'URL del file immagine

- Fai riferimento al [Catalogo VM](VM-Catalog.md?h=qcow2) per un elenco di immagini con URL.
- Copia l'URL negli appunti, ad esempio `https://images.hin.ch/vm-images/hingateway_v0.0.0.x86_64.qcow2`

## Importare il file immagine in Proxmox

- Nell'interfaccia web di Proxmox, naviga al menu Storage e fai clic su Importa
- Fai clic su **Scarica da URL**, incolla l'URL copiato e fai clic su "Interroga URL".
- Fai clic su Scarica e attendi che "TASK OK" appaia alla fine del log di output.
- Chiudi la finestra di download del Visualizzatore attività.

## Creare una VM

- Fai clic su "Crea VM"
- Digita un nome per la VM
- Fai clic su "Avanti"
- Scegli "Non utilizzare alcun supporto"
- Fai clic su "Avanti"
- Fai clic su "Avanti"
- Fai clic sull'"icona del cestino" accanto a "scsi0" per rimuoverla.
- Fai clic su "Importa" e in "Seleziona immagine", scegli il file immagine appena importato.
- Fai clic su "Avanti"
- Seleziona 4 core CPU e scegli il tipo di CPU (o usa "host"). Fare riferimento ai [Requisiti del server](../index.md#requisiti-del-server).
- Fai clic su "Avanti"
- Seleziona 8192 MiB di memoria. Fare riferimento ai [Requisiti del server](../index.md#requisiti-del-server).
- Fai clic su "Avanti"
- Fai clic su "Avanti"
- Attendi fino al termine del processo di creazione della VM, quindi fai clic sulla nuova VM, fai clic su "Console", fai clic su "Avvia ora"

## Installare HIN Gateway

Dopo che la VM è stata creata con successo, procedi con i passaggi di installazione e onboarding come descritto nelle [istruzioni](../Installation-guide.md) fornite.

!!! tip "Supporto"

    Per qualsiasi domanda o problema relativo al deployment e al funzionamento dell'appliance Stargate, contatta il supporto HIN.

    Includi informazioni rilevanti come il nome del cliente, la versione dell'appliance e screenshot/[log](../Docker-advanced.md#fornire-log-al-supporto) dove applicabile, per aiutarci a elaborare la tua richiesta in modo efficiente.
