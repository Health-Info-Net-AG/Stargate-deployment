# Déploiement HIN Gateway sur VMware ESXi à l'aide d'une image

Déployez HIN Gateway sur VMware

## Obtenir le fichier image

- Téléchargez le dernier fichier image OVA (ou OVF et VMDK si vous préférez). Veuillez vous référer au [Catalogue des VM](VM-Catalog.md?h=ova)

## Accéder à l'interface Web d'ESXi

- Cliquez sur **Machines virtuelles**
- Cliquez sur **Créer/Enregistrer une VM**
- Choisissez "Déployer une machine virtuelle à partir d'un fichier OVF ou OVA"
- Cliquez sur **Suivant**
- Saisissez un nom pour la VM
- Cliquez sur **Suivant**
- Cliquez pour sélectionner les fichiers et choisissez le fichier image OVA (ou OVF et VMDK si vous préférez)
- Cliquez sur **Suivant**
- Choisissez un stockage à utiliser
- Cliquez sur **Suivant**
- Choisissez le réseau et le disque pour le provisionnement
- Cliquez sur **Suivant**
- Cliquez sur **Terminer**

!!! info "Disque de données inclus"
    L'OVA contient déjà le disque de données de l'appliance (`VEREIGN-DATA`, monté sur `/var/data`) — aucun disque supplémentaire à attacher. Voir [Guide d'installation → Étape 4](../Installation-guide.md#etape-4-charger-limage-de-machine-virtuelle).

## Installer HIN Gateway

Après la création réussie de la VM, procédez aux étapes d'installation et d'intégration comme décrit dans les [instructions](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/) fournies.

!!! tip "Support"

    Pour toute question ou problème lié au déploiement et au fonctionnement de l'appliance HIN Gateway, veuillez contacter le support HIN.

    Veuillez inclure des informations pertinentes telles que le nom du client, la version de l'appliance, et des captures d'écran/[logs](../Docker-advanced.md#fournir-les-logs-au-support) le cas échéant, pour nous aider à traiter votre demande efficacement.
