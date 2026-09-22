# Gestione dei domini instradati (Routed Domains) in HIN Gateway

HIN Gateway può anche gestire il traffico per domini che non sono domini HIN Secure. Si tratta di una configurazione comune per i clienti che gestiscono la propria infrastruttura di server di posta on-premises.
Questa funzionalità è integrata in HIN Gateway e offre ai clienti la flessibilità di adattare con precisione il proprio ambiente di comunicazione alle proprie esigenze.

In HIN Gateway, questi domini sono chiamati domini **Routed**.
Un dominio Routed è un dominio il cui traffico passa attraverso HIN Gateway senza essere elaborato per la messaggistica sicura - viene principalmente inoltrato al successivo relay host.


### Aggiungere un dominio Routed

Accedere alla pagina **Domains**, fare clic su **Add domain**, inserire il nome del dominio e quindi fare clic su **Save**.

<br> ![Screenshot](assets/routed-domains/add-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Configurare il dominio Routed

Attivare il dominio e configurarlo allo stesso modo di qualsiasi altro dominio HIN Secure. Per i passaggi di configurazione dettagliati, consultare la [guida alla configurazione del trasporto di posta](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/#step-14-configure-mail-transport).


<br> ![Screenshot](assets/routed-domains/activate-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
