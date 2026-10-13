# Autenticazione delle connessioni in uscita

Quando HIN Gateway inoltra i messaggi di un dominio all’hop successivo (ad esempio un relay di posta o un server di posta), quest’ultimo può richiedere che il mittente effettui l’accesso prima di accettare la posta. L’autenticazione delle connessioni in uscita consente a HIN Gateway di autenticarsi presso l’hop successivo con nome utente e password (SMTP AUTH).

Come funziona:

- Ogni dominio dispone di un proprio **Outbound relay** (host e porta) nella dashboard di HIN Gateway
- Quando **Require authentication** è attivo, HIN Gateway accede al relay in uscita con le credenziali inserite prima di inoltrare un messaggio

## Prima di iniziare

- È necessario l’accesso alla dashboard di HIN Gateway
- Il dominio deve essere già aggiunto in HIN Gateway e attivato (onboarded)
- Richiedere nome utente e password all’amministratore del lato ricevente (il relay o il server di posta che richiede l’autenticazione)

## Configurare le credenziali

1. Accedere alla dashboard di HIN Gateway.
2. Aprire **Domains** e selezionare il dominio.
3. Scorrere fino a **Mail routing** e individuare la sezione **Outbound**.

    ![Sezione Outbound con autenticazione inattiva](./assets/outbound-basic-auth-1.png)

    Verificare che **Outbound relay** indichi l’host e la porta corretti dell’hop successivo (ad esempio `relay.example.com:25`). Queste credenziali vengono utilizzate solo per questo relay.

4. Fare clic sull’interruttore **Require authentication** in modo che indichi **Active**. Compaiono i campi **Username** e **Password**.

    ![Sezione Outbound con autenticazione attiva](./assets/outbound-basic-auth-2.png)

5. Inserire **Username** e **Password** configurati sul lato ricevente. Fare clic sull’icona a forma di occhio per visualizzare la password e verificare che non contenga errori di battitura.
6. Scorrere verso il basso e fare clic su **Save**.

Da questo momento HIN Gateway si autentica presso il relay in uscita ogni volta che inoltra un messaggio per questo dominio.

## Verificare la configurazione

Inviare un messaggio di prova tramite HIN Gateway a un destinatario raggiungibile attraverso il relay in uscita e verificare che arrivi. In caso contrario, aprire **Logs** nella dashboard e cercare errori di autenticazione restituiti dal relay. Le cause più frequenti sono:

- Nome utente o password errati
- Il relay non supporta o non consente SMTP AUTH sulla porta configurata
- L’host o la porta dell’**Outbound relay** sono errati

## Modificare o rimuovere le credenziali

- **Cambiare la password:** quando il lato ricevente cambia la password, inserire quella nuova nel campo **Password** e fare clic su **Save**. Fino ad allora, l’autenticazione dei messaggi diretti al relay non riesce.
- **Disattivare l’autenticazione:** fare clic su **Require authentication** in modo che indichi **Inactive** e fare clic su **Save**. HIN Gateway si connette quindi al relay senza autenticazione.
