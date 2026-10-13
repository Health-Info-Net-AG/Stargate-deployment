# Autenticazione delle connessioni in entrata

L’autenticazione delle connessioni in entrata consente a un sistema esterno, come un relay di posta, un’applicazione o un client di posta, di inviare e-mail per uno dei vostri domini tramite HIN Gateway effettuando l’accesso con nome utente e password. È utile quando il mittente non può essere autorizzato soltanto in base al suo indirizzo IP.

Come funziona:

- Il mittente si connette a HIN Gateway sulla porta di submission **587** e si autentica con SMTP AUTH
- Le credenziali vengono create per ciascun dominio nella dashboard di HIN Gateway


## Prima di iniziare

- È necessario l’accesso alla dashboard di HIN Gateway
- Il dominio da cui si desidera inviare deve essere già aggiunto in HIN Gateway e attivato (onboarded)
- È necessario l’accesso alla configurazione del sistema di invio (MTA / applicazione), poiché vi si inseriranno le nuove credenziali

## Creare le credenziali

1. Accedere alla dashboard di HIN Gateway.
2. Aprire **Domains** e selezionare il dominio da cui si desidera inviare.
3. Scorrere fino alla sezione **SMTP authentication (port 587)**.

    ![Sezione SMTP authentication](./assets/inbound-basic-auth-1.png)

    Qui sono elencate le credenziali già esistenti per il dominio.

    L’interruttore **Verify a trusted network** stabilisce da dove possono essere utilizzate le credenziali. Quando è su **Off**, le credenziali funzionano da qualsiasi indirizzo IP. Attivarlo per limitare gli accessi ai soli `Trusted networks`.

4. Fare clic su **Add credential**. Si apre un modulo con due campi:

    ![Modulo Add credential](./assets/inbound-basic-auth-2.png)

    Scegliere una delle seguenti opzioni:

    - **Generare le credenziali automaticamente (consigliato):** lasciare vuoti **Username** e **Password**. HIN Gateway genera un nome utente e una password casuale robusta
    - **Impostare credenziali proprie:** inserire **Username** e **Password**. La password deve contenere almeno 16 caratteri.

5. Fare clic su **Create**.
6. Copiare nome utente e password.

    ![Copiare le nuove credenziali](./assets/inbound-basic-auth-3.png)

    !!! warning
        La password viene mostrata **una sola volta**. Fare clic su **Copy** e conservarla in un luogo sicuro (ad esempio in un password manager) prima di proseguire. Se la password va persa, utilizzare **Rotate password** per generarne una nuova.

7. Fare clic su **Done**. Le nuove credenziali compaiono ora nell’elenco.

## Configurare il sistema di invio

Inserire le credenziali nell’MTA o nell’applicazione di invio:

| Impostazione   | Valore                                  |
|----------------|-----------------------------------------|
| Server SMTP    | L’indirizzo IP del vostro HIN Gateway   |
| Porta          | `587`                                   |
| Crittografia   | STARTTLS                                |
| Autenticazione | Nome utente e password (SMTP AUTH)      |
| Nome utente    | Il nome utente del passaggio 6          |
| Password       | La password del passaggio 6             |

L’indirizzo del mittente (`MAIL FROM`) deve appartenere al dominio per cui sono state create le credenziali, altrimenti il messaggio viene rifiutato.

## Gestire le credenziali esistenti

Ogni credenziale nella sezione **SMTP authentication (port 587)** offre due azioni:

- **Rotate password:** genera una nuova password per la credenziale. La vecchia password smette di funzionare, quindi aggiornare subito il sistema di invio.
- **Delete:** elimina la credenziale. I sistemi che la utilizzano ancora non possono più inviare tramite HIN Gateway.


!!! tip
    Creare una credenziale separata per ogni sistema di invio. In questo modo è possibile rinnovare o revocare l’accesso di un sistema senza influire sugli altri.
