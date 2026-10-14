# Aggiornare HIN Gateway

Questo documento spiega:

* Come aggiornare un'istanza HIN Gateway a una versione più recente.
* Come eseguire il rollback a una versione precedente.

!!! warning "Versioni applicabili"
    Questa procedura si applica solo alle versioni 0.6.x e successive.

## Come aggiornare

1. Andare alla pagina `Settings` e scorrere fino alla sezione `System version`.

   <br> ![system-version](assets/configuration/step1-update-vm.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

2. Fare clic su `Other versions`.

3. Dall'elenco delle versioni disponibili, selezionare la versione di destinazione.

   * Le versioni più recenti utilizzano una numerazione incrementale, quindi la versione di destinazione avrà un numero superiore a quella attuale.

4. Fare clic sul pulsante `Download`. Questa azione avvia solo il download, l'aggiornamento non viene ancora installato.

   <br> ![system-version](assets/configuration/step2-update-vm.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

   <br> ![system-version](assets/configuration/step4-update-vm-downloading.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

5. Al termine del download, viene visualizzata una finestra di conferma con due opzioni:

   * `Restart now`: riavvia immediatamente la macchina e installa la nuova versione.
   * `Later`: rimanda l'aggiornamento. La nuova versione viene installata al successivo riavvio della macchina.

   <br> ![system-version](assets/configuration/step5-update-vm-confir-restart.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

   <br> ![system-version](assets/configuration/step5-updatevm-later-restart.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

!!! warning "Aggiornamento a una major release"
    L'aggiornamento da 0.6.x a 1.1.7 è un aggiornamento a una major release. È obbligatorio creare uno snapshot di backup della VM prima di avviare l'aggiornamento.

    Questa release include un aggiornamento di sicurezza obbligatorio che aggiorna Keycloak alla versione 26.8.0. Durante questo aggiornamento Keycloak [modifica lo schema del database](https://github.com/keycloak/keycloak/blob/main/model/jpa/src/main/resources/META-INF/jpa-changelog-26.8.0.xml#L348) e rimuove una colonna e degli indici necessari alla versione precedente di Keycloak (26.7.4). Per questo motivo, il pulsante `Roll back` non consente di ripristinare una versione 0.6.x funzionante. Lo snapshot della VM è l'unico modo per tornare alla versione precedente.

## Come eseguire il rollback

1. Andare alla pagina `Settings` e scorrere fino alla sezione `System version`.

   <br> ![system-version](assets/configuration/step1-update-vm.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

2. Fare clic sul pulsante `Roll back to vX.X.X`.

3. Confermare l'azione nella schermata di conferma. Il sistema si riavvia e installa la versione stabile precedente.

   <br> ![system-version](assets/configuration/step1-rollback.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
