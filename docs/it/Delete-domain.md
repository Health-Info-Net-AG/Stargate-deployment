# Eliminare un dominio

È possibile eliminare un dominio da HIN Gateway quando non deve più inviare né ricevere e-mail tramite il gateway, ad esempio dopo che il dominio è stato dismesso o trasferito a un altro sistema.

Questi passaggi valgono per entrambi i tipi di dominio elencati nella pagina **Domains**: i domini **Secure** (domini HIN Secure) e i domini **Routed**. Per maggiori informazioni sui domini Routed, consultare [Gestione dei domini instradati (Routed Domains) in HIN Gateway](Routed-domains.md).

## Prima dell'eliminazione

- Verificare che nessun sistema invii ancora e-mail per il dominio tramite HIN Gateway. Dopo l'eliminazione del dominio, HIN Gateway non elabora più i messaggi che lo riguardano
- Decidere se il certificato del dominio deve essere revocato. La revoca non può essere annullata

## Eliminare il dominio

1. Accedere alla dashboard di HIN Gateway.
2. Aprire **Domains** e selezionare il dominio da eliminare. Si apre la pagina **Domain details**.
3. Fare clic sull'icona rossa **Delete** (cestino) accanto allo stato del dominio.

    ![Pagina Domain details con l'icona di eliminazione](./assets/delete-domain-1.png)

    Si apre una finestra di conferma.

    ![Conferma dell'eliminazione del dominio](./assets/delete-domain-2.png)

4. Scegliere se revocare il certificato del dominio:

    - **Revoke domain's certificate** selezionato: anche il certificato del dominio viene revocato quando il dominio viene eliminato
    - **Revoke domain's certificate** non selezionato: il dominio viene eliminato, ma il suo certificato non viene revocato

5. Fare clic su **Yes** per eliminare il dominio oppure su **No** per annullare.

Il dominio viene rimosso dall'elenco **Domains**.

!!! warning
    Se si seleziona **Revoke domain's certificate**, il certificato viene revocato e non può più essere utilizzato. La revoca non può essere annullata.
