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
