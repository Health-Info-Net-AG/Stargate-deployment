# Scenario di migrazione multidominio

*MGW → HIN Gateway – architettura del flusso di posta, implementazione graduale e piano di rollback*


## Fase 1: Avvio – situazione iniziale (tutti i domini su MGW)

**Stato iniziale**

- Tutti i domini sono instradati attraverso **MGW**. Esempio: domain1.ch, domain2.ch, domain3.ch, un-domain1.ch, un-domain2.ch
- Preparazione del deployment di HIN Gateway – nessun traffico reale ancora attivo
- I record DNS MX/SPF continuano a puntare all’**IP pubblico A** (MGW) – nel caso in cui il MGW sia il gateway esposto verso Internet oppure l’ultimo MTA

!!! info "Checklist preliminare"
    - Definire i parametri di riferimento della capacità attuale MGW e dei log del flusso di posta
    - Verificare la connettività di Stargate lab verso Online Protect / Exchange Online / server di posta elettronica on-premise
    - Allineare gli stakeholder sul calendario di migrazione e sul piano di comunicazione
    - Esaminare la documentazione relativa a firewall/porte prima dell’assegnazione dell’IP pubblico B (fase 2, passaggio 1)

 <br> ![Start-Baseline](assets/multi-domain-scenario/Phase1-start-baseline.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Fase 2: Migrazione – esempio di migrazione graduale, dominio per dominio

**Procedura di migrazione**

1. **Abilitazione** di HIN Gateway – assegnare `Public IP B` e aggiornare le regole del firewall (si veda la documentazione di rete per le porte richieste)
2. **Creare due connettori** su Exchange Online – uno in entrata e uno in uscita – che puntino a Stargate
3. **Aggiungere una regola del flusso di posta** che instradi in base al dominio: domain1.ch → HIN Gateway, tutti gli altri domini rimangono su MGW
4. **Ripetere gradualmente** – spostare un dominio alla volta fino a quando tutti i domini non saranno su HIN Gateway

!!! danger "Rollback (per dominio)"
    - Reindirizzare la regola del flusso di posta del dominio interessato verso MGW
    - Lasciare attivi i connettori di Stargate in vista del tentativo successivo
    - Tenere un **log delle modifiche** per ogni variazione apportata a connettori/regole, in ordine cronologico – il rollback dovrà riprodurlo in ordine inverso

!!! warning "Prestare attenzione alle intestazioni specifiche del cliente"
    Alcuni domini utilizzano X-header personalizzati (instradamento, liste di autorizzazione antispam, tag di compliance). Verificare che i connettori di Stargate conservino/replichino queste intestazioni prima di spostare un dominio – l’assenza di intestazioni può causare un instradamento errato o il rifiuto della posta.

![Phase 2 Migration - gradual, domain-by-domain](assets/multi-domain-scenario/Phase2-migration-domain-by-domain.png)

## Fase 3: Conclusione – migrazione completa a HIN Gateway

!!! success "Stato finale"
    - Tutti i domini passano attraverso HIN Gateway
    - **MGW** non trasporta traffico di produzione
    - DNS / SPF puntano all’**IP pubblico B** (nel caso in cui HIN Gateway sia il gateway esposto verso Internet oppure l’ultimo MTA)

!!! note "Checklist per operazioni di pulizia"
    - Rimuovere i vecchi connettori MGW e le regole del flusso di posta
    - Disattivare la VM di MGW una volta confermata dal monitoraggio l’assenza di traffico e verificato il corretto funzionamento del flusso della posta elettronica
    - Procedere al rilascio dell’**IP pubblico A** qualora non sia più necessario
    - Aggiornare i runbook e la documentazione del DNS

![Phase 3 Final - fully migrated to HIN Gateway](assets/multi-domain-scenario/Phase3-final-fully-migrated.png)

## Confronto tra strategie di migrazione

!!! tip "Consigliata – trasferire tutti i domini in una sola volta"
    - Non è richiesto alcun indirizzo IP pubblico aggiuntivo
    - Nessuna modifica temporanea al connettore o alle regole del flusso di posta
    - Rollback semplice: spegnere Stargate e riaccendere la vecchia VM di MGW
    - Finestra di cutover più breve – minima probabilità di scostamenti nella configurazione

!!! note "Alternativa – graduale, dominio per dominio"
    - Raggio d’azione ridotto per ogni passaggio – solo un dominio alla volta è a rischio
    - Richiede un secondo indirizzo IP pubblico e regole/connettori temporanei di split
    - È necessario gestire le intestazioni specifiche del cliente per ciascun dominio
    - Il rollback richiede la riproduzione in ordine inverso dell’esatta sequenza delle modifiche

---

!!! warning
    Prima di eseguire qualsiasi procedura di installazione verificare che le porte del firewall e le impostazioni del connettore corrispondano esattamente a quanto indicato nell’aggiornata documentazione di rete.

!!! note
    Consultare le indicazioni specifiche riportate nella [Guida all’installazione del dominio](Installation-guide.md) relative alla migrazione multidominio.
