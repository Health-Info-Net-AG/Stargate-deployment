# Configurare NTP

HIN Gateway mantiene l’orologio preciso tramite NTP (Network Time Protocol). Un orologio preciso è indispensabile: la convalida dei certificati, la firma dei messaggi e le sessioni di accesso non funzionano se l’orologio si discosta dall’ora esatta.

Come funziona:

- Per impostazione predefinita, HIN Gateway sincronizza l’ora con `ntp.metas.ch`
- Se la rete non consente il traffico NTP in uscita verso Internet, o se l’organizzazione gestisce propri server di riferimento orario, è possibile sostituire il server predefinito con uno o più server personalizzati
- È possibile aggiungere più server di riferimento orario. Se uno non è raggiungibile, HIN Gateway utilizza il successivo

## Prima di iniziare

- È necessario l’accesso alla dashboard di HIN Gateway
- Richiedere all’amministratore di rete il nome host del server (o dei server) di riferimento orario
- Verificare che HIN Gateway possa raggiungere il server (o i server) sulla porta UDP 123

## Controllare la sincronizzazione attuale

1. Accedere alla dashboard di HIN Gateway.
2. Aprire **Settings** e scorrere fino alla sezione **Time synchronisation**.

    ![Sezione Time synchronisation con il server predefinito](./assets/ntp-config-1.png)

    La riga di stato indica se l’orologio è sincronizzato (**In sync**), insieme all’indirizzo IP del server in uso, allo scostamento (offset) e allo stratum. **Time servers** mostra i server configurati. Se non sono presenti server personalizzati, viene visualizzato **Using the default time server (ntp.metas.ch)**.

## Aggiungere server personalizzati

1. Nella sezione **Time synchronisation**, fare clic su **Edit**. Compare un campo vuoto per il primo server.

    ![Sezione Time synchronisation in modalità di modifica](./assets/ntp-config-2.png)

2. Inserire il nome host del server (ad esempio `ntp.example.com`).
3. Con l’interruttore accanto al campo, scegliere il tipo di voce:
    - **Server**: un singolo server NTP
    - **Pool**: un pool NTP, ossia un nome host che si risolve in più server (ad esempio `ch.pool.ntp.org`). HIN Gateway utilizza più server del pool
4. Per aggiungere un altro server, fare clic su **Add server** e ripetere i passaggi 2 e 3. È possibile combinare pool e server.

    ![Sezione Time synchronisation con un pool e un server](./assets/ntp-config-3.png)

    Per rimuovere una voce, fare clic sull’icona meno accanto a essa.

5. Fare clic su **Save**.

HIN Gateway ora sincronizza l’ora con i server configurati anziché con quello predefinito.

## Verificare la configurazione

Controllare la riga di stato nella sezione **Time synchronisation**. Dovrebbe indicare **In sync** e l’indirizzo IP di uno dei server configurati. Per forzare una sincronizzazione immediata, fare clic su **Sync now**.

## Tornare al server predefinito

Fare clic su **Edit**, rimuovere tutte le voci con l’icona meno e fare clic su **Save**. HIN Gateway utilizzerà di nuovo `ntp.metas.ch`.
