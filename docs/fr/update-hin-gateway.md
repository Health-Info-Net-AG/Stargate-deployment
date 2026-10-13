# Mettre à jour HIN Gateway

Ce document explique:

* Comment mettre à jour une instance HIN Gateway vers une version plus récente.
* Comment revenir à une version précédente.

!!! warning "Versions concernées"
    Cette procédure s'applique uniquement aux versions 0.6.x et ultérieures.

## Comment effectuer une mise à jour

1. Accédez à la page `Settings` et faites défiler jusqu'à la section `System version`.

   <br> ![system-version](assets/configuration/step1-update-vm.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

2. Cliquez sur `Other versions`.

3. Dans la liste des versions disponibles, sélectionnez la version cible.

   * Les versions plus récentes utilisent une numérotation incrémentale, la version cible aura donc un numéro supérieur à la version actuelle.

4. Cliquez sur le bouton `Download`. Cela ne fait que démarrer le téléchargement, la mise à jour n'est pas encore installée.

   <br> ![system-version](assets/configuration/step2-update-vm.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

   <br> ![system-version](assets/configuration/step4-update-vm-downloading.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

5. Une fois le téléchargement terminé, une boîte de dialogue de confirmation apparaît avec deux options:

   * `Restart now`: redémarre immédiatement la machine et installe la nouvelle version.
   * `Later`: reporte la mise à jour. La nouvelle version est installée au prochain redémarrage de la machine.

   <br> ![system-version](assets/configuration/step5-update-vm-confir-restart.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

   <br> ![system-version](assets/configuration/step5-updatevm-later-restart.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

!!! warning "Mise à jour majeure"
    La mise à jour de 0.6.x vers 1.1.7 est une mise à jour majeure. Vous devez créer un snapshot de sauvegarde de la VM avant de lancer la mise à jour.

    Cette version inclut une mise à jour de sécurité obligatoire qui fait passer Keycloak à la version 26.8.0. Lors de cette mise à niveau, Keycloak [modifie le schéma de la base de données](https://github.com/keycloak/keycloak/blob/main/model/jpa/src/main/resources/META-INF/jpa-changelog-26.8.0.xml#L348) et supprime une colonne et des index dont la version précédente de Keycloak (26.7.4) a besoin. Par conséquent, le bouton `Roll back` ne permet pas de restaurer une version 0.6.x fonctionnelle. Le snapshot de la VM est le seul moyen de revenir à la version précédente.

## Comment revenir à une version précédente

1. Accédez à la page `Settings` et faites défiler jusqu'à la section `System version`.

   <br> ![system-version](assets/configuration/step1-update-vm.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

2. Cliquez sur le bouton `Roll back to vX.X.X`.

3. Confirmez l'action sur l'écran de confirmation. Le système redémarre et installe la version stable précédente.

   <br> ![system-version](assets/configuration/step1-rollback.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
