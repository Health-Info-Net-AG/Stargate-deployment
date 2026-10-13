# Update HIN Gateway

This document explains:

* How to update a HIN Gateway instance to a newer version.
* How to roll back to a previous version.

!!! warning Applicable versions
    This procedure applies only to versions 0.6.x and later.

## How to Update

1. Go to the `Settings` page and scroll to the `System version` section.

   <br> ![system-version](assets/configuration/step1-update-vm.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

2. Click `Other versions`.

3. From the list of available versions, select the target version.

   * Newer versions use incremental numbering, so the target version will have a higher number than the current one.

4. Click the `Download` button. This only starts the download; it does not install the update yet.

   <br> ![system-version](assets/configuration/step2-update-vm.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

   <br> ![system-version](assets/configuration/step4-update-vm-downloading.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

5. Once the download completes, a confirmation dialog appears with two options:

   * `Restart now`: restarts the machine immediately and installs the new version.
   * `Later`: postpones the update. The new version is installed the next time the machine restarts.

   <br> ![system-version](assets/configuration/step5-update-vm-confir-restart.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

   <br> ![system-version](assets/configuration/step5-updatevm-later-restart.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

!!! warning "Major release update"
    Updating from 0.6.x to 1.1.7 is a major release update. You must take a snapshot backup of the VM before you start the update.

    This release includes a required security update, which upgrades Keycloak to 26.8.0. During this upgrade Keycloak [changes the database schema](https://github.com/keycloak/keycloak/blob/main/model/jpa/src/main/resources/META-INF/jpa-changelog-26.8.0.xml#L348) and removes a column and indexes that the previous Keycloak version (26.7.4) depends on. Because of this, the `Roll back` button cannot restore a working 0.6.x version. The VM snapshot is the only way to return to the previous version.

## How to Roll Back

1. Go to the `Settings` page and scroll to the `System version` section.

   <br> ![system-version](assets/configuration/step1-update-vm.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

2. Click the `Roll back to vX.X.X` button.

3. Confirm the action on the confirmation screen. The system will restart and install the previous stable version.

   <br> ![system-version](assets/configuration/step1-rollback.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }