# Deployment Windows 11 Pro tramite immagine

Distribuisci Stargate su Windows Pro (le versioni non-Pro non supportano Hyper-V)

## Installare Hyper-V

- Fai clic sul pulsante Start, quindi digita "Attiva o disattiva funzionalità di Windows"
- Fai clic su quel pulsante
- Seleziona Hyper-V e fai clic su "OK"
- Dopo il completamento dell'installazione, fai clic su "Riavvia ora" e attendi il riavvio di Windows

**Nota:** Si consiglia di distribuire la VM utilizzando Hyper-V Generazione 2

## Ottenere l'immagine

- Scarica il file immagine .vhdx. Fare riferimento al [Catalogo VM](VM-Catalog.md?h=vhdx)

## Importare il file immagine e creare una VM con esso

- Fai clic sul pulsante "Start" e digita "Creazione rapida Hyper-V"
- Fai clic su quell'icona
- Scegli "Sorgente di installazione locale"
- Deseleziona "Questo computer eseguirà Windows"
- Fai clic su "Cambia sorgente di installazione", naviga all'immagine .VHDX scaricata e fai clic su di essa
- Fai clic su "Crea macchina virtuale"
- Fai clic su "Modifica impostazioni"
- In "Memoria", scegli "RAM" 8192 MB. Fare riferimento ai [Requisiti del server](../index.md#requisiti-del-server).
- In "Processore", scegli "Numero di processori virtuali" 4. Fare riferimento ai [Requisiti del server](../index.md#requisiti-del-server).
- Fai clic su "OK"
- Fai clic su "Connetti"
- Fai clic su "Avvia"

!!! warning "Collega prima il disco dati"
    Prima del primo avvio, collega un secondo disco vuoto di almeno 30 GB. Al primo avvio l'appliance lo formatta come disco dati (`VEREIGN-DATA`, montato su `/var/data`) e vi conserva tutta la configurazione e i dati; senza di esso l'avvio fallisce ed esegue il rollback. Vedi [Guida all'installazione → Passo 4](../Installation-guide.md#passo-4-caricamento-dellimmagine-vm).

## Installare HIN Gateway

Dopo che la VM è stata creata con successo, procedi con i passaggi di installazione e onboarding come descritto nelle [istruzioni](../Installation-guide.md) fornite.

!!! tip "Supporto"

    Per qualsiasi domanda o problema relativo al deployment e al funzionamento dell'appliance Stargate, contatta il supporto HIN.

    Includi informazioni rilevanti come il nome del cliente, la versione dell'appliance e screenshot/[log](../Docker-advanced.md#fornire-log-al-supporto) dove applicabile, per aiutarci a elaborare la tua richiesta in modo efficiente.
