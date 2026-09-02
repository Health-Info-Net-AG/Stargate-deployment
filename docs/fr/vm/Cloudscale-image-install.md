# Déploiement Stargate sur Cloudscale à l'aide d'une image

## Obtenir l'URL du fichier image

- Référez-vous au [Catalogue des VM](VM-Catalog.md?h=qcow2) pour les images disponibles avec leurs URL.
- Copiez l'URL `qcow2` dans votre presse-papiers.

## Importer le fichier image dans Cloudscale

- Dans l'interface Web de Cloudscale, naviguez jusqu'au menu "Images personnalisées" et cliquez sur "Importer une image personnalisée".
- Définissez un **Nom d'image** approprié.
- Définissez un **Slug**, par exemple "stargate".
- Collez l'URL de l'image Stargate dans le champ **URL de téléchargement**.
- Définissez **Format source** sur le format de téléchargement, recommandé : `qcow2`.
- Configurez les paramètres supplémentaires si nécessaire.
- Cliquez sur **Importer**.

## Créer une VM

- Naviguez vers **Serveurs** et cliquez sur **Lancer un nouveau serveur**.
- Entrez votre **FQDN** ou nom d'hôte préféré.
- Sous **Système d'exploitation**, sélectionnez **Images personnalisées** et choisissez votre image importée.
- Sous **Flavor de calcul**, sélectionnez **Flex-4-2** ou **Flex-8-2** en fonction de la charge prévue (peut être ajusté ultérieurement). Voir [Exigences du serveur](../index.md#exigences-du-serveur) pour plus de détails.
- Sous **Capacité de stockage**, définissez au moins **30 Go**. Veuillez vous référer aux [Exigences du serveur](../index.md#exigences-du-serveur).
- Sous **Emplacement du serveur**, sélectionnez votre zone préférée.
- Sous **Gestion du réseau**, activez uniquement **IPv4** si l'instance Stargate doit être accessible sur Internet (par exemple, pour Office 365).
- Sous **Sécurité d'accès**, sélectionnez votre clé SSH (utilisable avec l'utilisateur `almalinux`).
- Sous **Mot de passe**, définissez un mot de passe sécurisé de votre choix.

!!! tip "Sans mot de passe, l'authentification SSH par mot de passe est désactivée"
    Vous devez tout de même utiliser le mot de passe initial fourni par HIN lors de votre première connexion. Toutefois, si vous ne définissez pas de nouveau mot de passe, cloud-init désactivera l'authentification SSH par mot de passe pour tous les utilisateurs, de sorte que l'accès SSH ne sera possible qu'à l'aide d'une clé publique.

- Cliquez sur **Lancer**.

!!! warning "Attachez d'abord le disque de données"
    Avant le premier démarrage, attachez un second disque vierge d'au moins 30 Go. Au premier démarrage, l'appliance le formate comme disque de données (`VEREIGN-DATA`, monté sur `/var/data`) et y conserve toute la configuration et les données ; sans lui, le démarrage échoue et effectue un rollback. Voir [Guide d'installation → Étape 4](../Installation-guide.md#etape-4-charger-limage-de-machine-virtuelle).

## Installer HIN Gateway

Après la création réussie de la VM, procédez aux étapes d'installation et d'intégration comme décrit dans les [instructions](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/) fournies.

!!! tip "Support"

    Pour toute question ou problème lié au déploiement et au fonctionnement de l'appliance Stargate, veuillez contacter le support HIN.

    Veuillez inclure des informations pertinentes telles que le nom du client, la version de l'appliance, et des captures d'écran/[logs](../Docker-advanced.md#fournir-les-logs-au-support) le cas échéant, pour nous aider à traiter votre demande efficacement.
