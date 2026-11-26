# Rinnovare e revocare i certificati di dominio

Ogni dominio in HIN Gateway ha un certificato di dominio. HIN Gateway lo utilizza per firmare e crittografare i messaggi del dominio. Nella dashboard è possibile far rinnovare automaticamente il certificato da HIN Gateway, revocare un certificato ed emetterne uno nuovo.

## Visualizzare i certificati di dominio

1. Accedere alla dashboard di HIN Gateway
2. Aprire **Domains** e selezionare il dominio
3. Aprire la sezione **Domain certificates**

    ![Sezione Domain certificates con un certificato nello stato Good](./assets/domain-certs-1.png)

    Per ogni certificato la sezione mostra il **Serial Number**, il periodo di validità (**Valid from** e **Valid until**) e lo **Status**.
    Un certificato in scadenza è contrassegnato con **Expiring soon** e la sua data **Valid until** è mostrata in rosso.

## Filtrare i certificati per stato

Utilizzare il filtro **Status** in alto a destra nella sezione per scegliere quali certificati visualizzare:

- **Good:** certificati validi attualmente in uso
- **Revoked:** certificati revocati
- **Expired:** certificati il cui periodo di validità è terminato

![Certificati di dominio filtrati per stato Revoked](./assets/domain-certs-4.png)

## Attivare o disattivare il rinnovo automatico

L'interruttore **Auto renew** determina se HIN Gateway rinnova automaticamente il certificato:

- **Attivato:** HIN Gateway rinnova automaticamente il certificato quando sta per scadere. Questa impostazione è consigliata
- **Disattivato:** il certificato non viene rinnovato. Alla scadenza occorre emettere manualmente un nuovo certificato

Fare clic sull'interruttore per modificare l'impostazione.

!!! warning
    Se il rinnovo automatico è disattivato e il certificato scade, HIN Gateway non può più firmare e crittografare i messaggi con esso finché non viene emesso un nuovo certificato.

## Revocare un certificato

Revocare un certificato se non si desidera più che venga utilizzato, ad esempio se si sospetta che la chiave sia compromessa.

1. Nella sezione **Domain certificates**, individuare il certificato da revocare
2. Fare clic sull'icona rossa **Revoke** (cerchio barrato). Si apre una finestra di conferma

    ![Conferma della revoca del certificato](./assets/domain-certs-2.png)

3. Fare clic su **Revoke** per confermare oppure su **Cancel** per mantenere il certificato.

!!! warning
    La revoca di un certificato non può essere annullata. Il certificato ha quindi lo stato **Revoked** e compare nel filtro di stato **Revoked**.

## Emettere un nuovo certificato

È possibile emettere un nuovo certificato a partire da un certificato scaduto o revocato.

1. Nel filtro **Status**, selezionare **Expired** o **Revoked**.
2. Individuare il certificato e fare clic sull'icona **Renew** (orologio con freccia). Si apre una finestra di conferma.

    ![Conferma del rinnovo del certificato](./assets/domain-certs-3.png)

3. Fare clic su **Renew** per confermare oppure su **Cancel** per annullare.

HIN Gateway genera nuove chiavi pubblica e privata ed emette il nuovo certificato. Se il vecchio certificato era ancora valido, viene revocato.

!!! note
    Possono essere necessarie alcune ore prima che il nuovo certificato raggiunga tutti gli altri partecipanti. Nel frattempo è comunque possibile decrittografare i messaggi con la chiave privata attuale.

## Verificare il nuovo certificato

Selezionare **Good** nel filtro **Status**. Il nuovo certificato è elencato con lo stato **Good**, un nuovo **Serial Number** e un nuovo periodo di validità.
