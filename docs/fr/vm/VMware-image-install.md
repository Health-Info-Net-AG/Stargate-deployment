# Déploiement Stargate sur VMware ESXi à l'aide d'une image

Déployez Stargate sur VMware

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
