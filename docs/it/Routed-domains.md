# Gestione dei domini instradati (Routed Domains) in HIN Gateway

HIN Gateway può gestire anche il traffico di posta per domini che non sono domini HIN Secure. Si tratta di una configurazione comune per i clienti che gestiscono la propria infrastruttura di server di posta on-premises.
Questa funzionalità è integrata in HIN Gateway e consente ai clienti di adattare la propria configurazione di posta alle proprie esigenze.

In HIN Gateway, questi domini sono chiamati domini **Routed**.
La posta di un dominio Routed transita attraverso HIN Gateway senza essere elaborata per la messaggistica sicura: viene semplicemente inoltrata al relay host successivo.


## Aggiungere un dominio Routed

Accedere alla pagina **Domains**, fare clic su **Add domain**, inserire il nome del dominio e fare clic su **Save**.

<br> ![Screenshot](assets/routed-domains/add-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Configurare il dominio Routed

Attivare il dominio e configurarlo allo stesso modo di un dominio HIN Secure. Per i passaggi dettagliati, consultare [Passo 14 - Configurazione trasporto posta](Installation-guide.md#passo-14-configurazione-trasporto-posta) nella guida all'installazione.


<br> ![Screenshot](assets/routed-domains/activate-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
