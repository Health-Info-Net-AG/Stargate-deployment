# Déploiement Proxmox à l'aide d'une image

Déployez Stargate sur Proxmox

## Obtenir l'URL du fichier image

- Veuillez vous référer au [Catalogue des VM](VM-Catalog.md?h=qcow2) pour une liste des images avec leurs URL.
- Copiez l'URL dans votre presse-papiers, par exemple `https://images.hin.ch/vm-images/hingateway_v0.0.0.x86_64.qcow2`

## Importer le fichier image dans Proxmox

- Dans l'interface Web de Proxmox, naviguez jusqu'au menu Stockage et cliquez sur Importer
- Cliquez sur **Télécharger depuis URL**, collez l'URL copiée et cliquez sur "Interroger l'URL".
- Cliquez sur Télécharger et attendez que "TASK OK" apparaisse à la fin du journal de sortie.
- Fermez la fenêtre de téléchargement du Visualiseur de tâches.

## Créer une VM

- Cliquez sur "Créer une VM"
- Saisissez un nom pour la VM
- Cliquez sur "Suivant"
- Choisissez "Ne pas utiliser de support"
- Cliquez sur "Suivant"
- Cliquez sur "Suivant"
- Cliquez sur "l'icône Corbeille" à côté de "scsi0" pour le supprimer.
- Cliquez sur "Importer" et sous "Sélectionner une image", choisissez le fichier image nouvellement importé.
- Cliquez sur "Suivant"
- Sélectionnez 4 cœurs CPU et choisissez votre type de CPU (ou utilisez "host"). Veuillez vous référer aux [Exigences du serveur](../index.md#exigences-du-serveur).
- Cliquez sur "Suivant"
- Sélectionnez 8192 MiB de mémoire. Veuillez vous référer aux [Exigences du serveur](../index.md#exigences-du-serveur).
- Cliquez sur "Suivant"
- Cliquez sur "Suivant"
- Attendez que le processus de création de la VM se termine, puis cliquez sur la nouvelle VM, cliquez sur "Console", cliquez sur "Démarrer maintenant"

## Installer HIN Gateway

Après la création réussie de la VM, procédez aux étapes d'installation et d'intégration comme décrit dans les [instructions](../Installation-guide.md) fournies.

!!! tip "Support"

    Pour toute question ou problème lié au déploiement et au fonctionnement de l'appliance Stargate, veuillez contacter le support HIN.

    Veuillez inclure des informations pertinentes telles que le nom du client, la version de l'appliance, et des captures d'écran/[logs](../Docker-advanced.md#fournir-les-logs-au-support) le cas échéant, pour nous aider à traiter votre demande efficacement.
