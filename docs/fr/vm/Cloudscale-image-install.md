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
- Sous **Capacité de stockage**, définissez au moins **20 Go**. Veuillez vous référer aux [Exigences du serveur](../index.md#exigences-du-serveur).
- Sous **Emplacement du serveur**, sélectionnez votre zone préférée.
- Sous **Gestion du réseau**, activez uniquement **IPv4** si l'instance Stargate doit être accessible sur Internet (par exemple, pour Office 365).
- Sous **Sécurité d'accès**, sélectionnez votre clé SSH (utilisable avec l'utilisateur `almalinux`).
- Cliquez sur **Lancer**.

## Se connecter et initialiser l'instance Stargate

- Connectez-vous à la console VM avec l'utilisateur `hinadmin` afin de configurer et installer les composants Stargate.
- Pour obtenir le mot de passe `hinadmin`, envoyez un courriel à <support@hin.ch> avec l'objet : **"Password required for VM installation."**

[Cliquez ici pour envoyer un courriel](mailto:support@hin.ch?subject=Password%20required%20for%20VM%20installation.&body=Hello%20dear%20Support,%0A%0AI%20would%20like%20to%20receive%20the%20password%20for%20a%20VM%20installation.%0A%0APLEASE%20PROVIDE%20YOUR%20CUSTOMER%20INFO%20HERE){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

```shell
sudo su -
cd ~/stargate-deployment/docker-compose/
```

- Utilisez vi/nano pour modifier `customer-config.sh`
- Les détails de configuration se trouvent dans le [README - Étape 1 : Configurer les paramètres client](../Docker-deploy.md#etape-1-configurer-les-parametres-client)
- Exécutez le script d'installation :

```shell
./scripts/install.sh
```

!!! tip "Support"

    Pour toute question ou problème lié au déploiement et au fonctionnement de l'appliance Stargate, veuillez contacter le support HIN.

    Veuillez inclure des informations pertinentes telles que le nom du client, la version de l'appliance, et des captures d'écran/[logs](../Docker-advanced.md#fournir-les-logs-au-support) le cas échéant, pour nous aider à traiter votre demande efficacement.
