# Déploiement Stargate sur Azure à l'aide d'une image

Déployez Stargate sur Azure

## Exigences du port 25 (SMTP) d'Azure

!!! warning
    Avant de commencer l'installation sur Microsoft Azure, examinez les exigences suivantes relatives à la connectivité SMTP sortante sur le port 25. Ignorer cette étape peut entraîner des échecs de livraison des courriels après l'installation.

La disponibilité du port 25 dépend de votre type d'abonnement Azure :

- :white_check_mark: **Contrat Entreprise (EA) ou MCA-E** - Le SMTP sortant sur le port 25 n'est pas bloqué. Notez que les domaines externes peuvent toujours rejeter les courriels - cela échappe au contrôle d'Azure.
- :white_check_mark: **Enterprise Dev/Test** - Bloqué par défaut, mais peut être débloqué. Pour demander le déblocage, allez dans *Diagnostiquer et résoudre* > *Impossible d'envoyer un courriel (SMTP-Port 25)* dans la ressource Réseau virtuel Azure du portail Azure.
- :x: **Tous les autres types d'abonnement** - Bloqué et **ne peut pas être débloqué**.

Référence : [Résoudre les problèmes de connectivité SMTP sortant dans Azure](https://learn.microsoft.com/en-us/troubleshoot/azure/virtual-network/troubleshoot-outbound-smtp-connectivity)

## Obtenir le fichier image

- Téléchargez le dernier fichier image VHD. Veuillez vous référer au [Catalogue des VM](VM-Catalog.md?h=vhd)

## Télécharger le fichier image VHD Azure

- Accédez à <https://portal.azure.com/#home>
- Cliquez sur **Comptes de stockage**.
- Sélectionnez le compte de stockage à utiliser ou créez-en un nouveau.
- Cliquez sur **Service Bloc** puis **Conteneurs**.
- Sélectionnez le conteneur dans lequel télécharger le fichier ou créez-en un nouveau si vous n'avez pas de conteneur.
- Cliquez sur **Télécharger** et choisissez le fichier image VHD.
- Assurez-vous que le type de blob est Page Blob.

## Créer l'image

- Accédez à <https://portal.azure.com/#home>
- Cliquez sur **Images**.
- Cliquez sur **Créer**.
- Choisissez le groupe de ressources à utiliser ou créez-en un nouveau.
- Saisissez un nom pour l'image.
- Choisissez le type de système d'exploitation **Linux** et **Génération de VM Gen 2**
- Dans Stockage blob, cliquez sur parcourir et sélectionnez le fichier image VHD nouvellement téléchargé.
- Cliquez sur **Vérifier + créer**.
- Cliquez sur **Créer**.

## Créer une VM

- Accédez à <https://portal.azure.com/#home>
- Cliquez sur **Machines virtuelles**.
- Cliquez sur **Créer**, et choisissez Machine virtuelle dans le menu déroulant.
- Choisissez le groupe de ressources.
- Saisissez un nom pour la VM.
- Dans Image, cliquez sur "**Voir toutes les images**", cliquez sur "**Mes images**" et choisissez la nouvelle image qui a été créée.
- Choisissez la taille de la VM.
- Choisissez le type d'authentification.
- Cliquez sur **Suivant : Disques**
- Sélectionnez une taille de disque OS d'au moins 20 GiB. Veuillez vous référer aux [Exigences du serveur](../index.md#exigences-du-serveur).
- Cliquez sur **Vérifier + créer**
- Cliquez sur **Créer**

## Trouver l'adresse IP publique de la nouvelle VM et ajouter des règles de pare-feu entrantes

- Accédez à <https://portal.azure.com/#home>
- Cliquez sur **Machines virtuelles**.
- Cliquez sur la nouvelle VM.
- Vous pouvez voir l'adresse IP publique sous "Adresse IP publique de la NIC principale"
- Faites défiler vers le bas jusqu'à Mise en réseau et cliquez dessus
- Cliquez sur **+ Créer une règle de port**, Règle de port entrant, Plages de ports de destination 25, Protocole TCP, nommez-la SMTP. Répétez pour les autres ports entrants requis — **8084** (rappel de scellement) et **19818** (WireGuard). Voir [Exigences du serveur → Accès réseau entrant](../index.md#acces-reseau-entrant-le-pare-feu-doit-autoriser) pour la liste complète.

!!! warning "Attachez d'abord le disque de données"
    Avant le premier démarrage, attachez un second disque vierge d'au moins 30 Go. Au premier démarrage, l'appliance le formate comme disque de données (`VEREIGN-DATA`, monté sur `/var/data`) et y conserve toute la configuration et les données ; sans lui, le démarrage échoue et effectue un rollback. Voir [Guide d'installation → Étape 4](../Installation-guide.md#etape-4-charger-limage-de-machine-virtuelle).

## Installer HIN Gateway

Après la création réussie de la VM, procédez aux étapes d'installation et d'intégration comme décrit dans les [instructions](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/) fournies.

!!! tip "Support"

    Pour toute question ou problème lié au déploiement et au fonctionnement de l'appliance Stargate, veuillez contacter le support HIN.

    Veuillez inclure des informations pertinentes telles que le nom du client, la version de l'appliance, et des captures d'écran/[logs](../Docker-advanced.md#fournir-les-logs-au-support) le cas échéant, pour nous aider à traiter votre demande efficacement.
