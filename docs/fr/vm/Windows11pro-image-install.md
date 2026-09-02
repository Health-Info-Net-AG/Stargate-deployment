# Déploiement Windows 11 Pro à l'aide d'une image

Déployez Stargate sur Windows Pro (les versions non-Pro ne prennent pas en charge Hyper-V)

## Installer Hyper-V

- Cliquez sur le bouton Démarrer, puis tapez "Activer ou désactiver des fonctionnalités Windows"
- Cliquez sur ce bouton
- Cochez Hyper-V et cliquez sur "OK"
- Une fois l'installation terminée, cliquez sur "Redémarrer maintenant" et attendez que Windows redémarre

**Remarque :** Nous recommandons de déployer la VM en utilisant Hyper-V Génération 2

## Obtenir l'image

- Téléchargez le fichier image .vhdx. Veuillez vous référer au [Catalogue des VM](VM-Catalog.md?h=vhdx)

## Importer le fichier image et créer une VM avec

- Cliquez sur le bouton "Démarrer" et tapez "Création rapide Hyper-V"
- Cliquez sur cette icône
- Choisissez "Source d'installation locale"
- Décochez "Cette machine exécutera Windows"
- Cliquez sur "Modifier la source d'installation", accédez à l'image .VHDX téléchargée et cliquez dessus
- Cliquez sur "Créer une machine virtuelle"
- Cliquez sur "Modifier les paramètres"
- Sous "Mémoire", choisissez "RAM" 8192 Mo. Veuillez vous référer aux [Exigences du serveur](../index.md#exigences-du-serveur).
- Sous "Processeur", choisissez "Nombre de processeurs virtuels" 4. Veuillez vous référer aux [Exigences du serveur](../index.md#exigences-du-serveur).
- Cliquez sur "OK"
- Cliquez sur "Connecter"
- Cliquez sur "Démarrer"

!!! warning "Attachez d'abord le disque de données"
    Avant le premier démarrage, attachez un second disque vierge d'au moins 30 Go. Au premier démarrage, l'appliance le formate comme disque de données (`VEREIGN-DATA`, monté sur `/var/data`) et y conserve toute la configuration et les données ; sans lui, le démarrage échoue et effectue un rollback. Voir [Guide d'installation → Étape 4](../Installation-guide.md#etape-4-charger-limage-de-machine-virtuelle).

## Installer HIN Gateway

Après la création réussie de la VM, procédez aux étapes d'installation et d'intégration comme décrit dans les [instructions](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/) fournies.

!!! tip "Support"

    Pour toute question ou problème lié au déploiement et au fonctionnement de l'appliance Stargate, veuillez contacter le support HIN.

    Veuillez inclure des informations pertinentes telles que le nom du client, la version de l'appliance, et des captures d'écran/[logs](../Docker-advanced.md#fournir-les-logs-au-support) le cas échéant, pour nous aider à traiter votre demande efficacement.
