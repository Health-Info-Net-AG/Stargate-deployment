# HIN Gateway

!!! tip
    Procédure d'installation technique d'une architecture de messagerie à domaine unique avec Microsoft 365

## Introduction

Ce document fournit un guide complet sur le processus d'installation technique et de migration vers le nouveau HIN Gateway ("Stargate Appliance"). Il s'applique aux architectures de messagerie Microsoft 365 utilisant un seul domaine de confiance.

Ce guide s'adresse aux clients HIN, aux administrateurs informatiques et aux ingénieurs système chargés du déploiement et de la configuration du nouveau HIN Gateway, ainsi que de la migration du Mail Gateway (MGW) existant vers la nouvelle solution.

Le HIN Gateway est une solution de passerelle de messagerie sécurisée qui permet une communication fiable, chiffrée et régie par des politiques au sein de l'Espace de confiance HIN. Elle fait office d'intermédiaire central entre les infrastructures de messagerie internes et les partenaires de communication externes, garantissant que l'ensemble du trafic de messagerie est transmis en toute sécurité, respecte les politiques de l'organisation et répond aux normes de sécurité de HIN.

## Présentation du flux de messagerie avec le HIN Gateway

- Les e-mails entrants sont acheminés via le HIN Gateway, où ils sont validés, déchiffrés (si nécessaire) et vérifiés au regard des politiques de confiance et de sécurité avant d'être transférés vers le serveur de messagerie interne.
- Les e-mails sortants sont envoyés depuis les systèmes internes vers le HIN Gateway, où le chiffrement, le routage et l'application des politiques sont effectués avant leur transmission aux destinataires externes.
- La communication entre les HIN Gateways est sécurisée par des certificats de pair à pair et des tunnels WireGuard, garantissant ainsi une communication fiable entre les domaines.

## Processus d'installation et de migration

La procédure structurée et étape par étape décrite dans ce document couvre les points suivants:

1. Préparation et plan de secours
2. Installation et configuration du HIN Gateway
3. Activation du domaine et validation du certificat
4. Intégration du serveur de messagerie et configuration du routage
5. Tests, mise en production et validation post-migration
6. Mise hors service du MGW existant

L'objectif de HIN dans ce processus est d'assurer une migration sécurisée, fluide et entièrement validée, qui perturbe le moins possible les opérations et garantit la continuité ininterrompue des services de messagerie.

## Foire aux questions

!!! question "Puis-je effectuer l'installation et la migration moi-même?"
    Oui, l'installation et la migration peuvent être entièrement réalisées par le client, à l'exception de l'"Étape 1.3 - Exporter la ou les clés privées".

    Pour des raisons de sécurité et afin de préserver la sécurité de votre clé privée, vous devez contacter le support HIN ou participer à la réunion téléphonique prévue pour la migration afin de recevoir le code nécessaire à l'exportation de la clé privée depuis les passerelles de messagerie actuellement en service.

    Si l'installation et la migration ne peuvent être menées à bien, veuillez participer à la réunion d'assistance prévue avec nos ingénieurs.

!!! question "Y aura-t-il une interruption de la distribution des e-mails pendant la migration?"
    Entre l'"Étape 1.5 - Arrêt de la machine virtuelle MGW existante" et l'"Étape 18 - Configuration du serveur de messagerie", tous les e-mails seront mis en file d'attente sur le serveur de messagerie. Une fois l'"Étape 18 - Configuration du serveur de messagerie" terminée, les e-mails en file d'attente seront envoyés ou remis dans la boîte de réception.

!!! question "Des e-mails seront-ils perdus pendant l'installation et la migration?"
    Non, aucun e-mail ne sera perdu pendant l'installation et la migration.

## Aperçu des étapes d'installation

| Étape | Sujet | Responsabilité |
| :--: | :---- | :------------: |
| 0 | Vérification des prérequis | Client |
| 1.1 | Smoke Test | Client |
| 1.2 | Sauvegarde du MGW existant | Client |
| 1.3 | Exporter la ou les clés privées | Client / HIN |
| 1.4 | Plan d'urgence / Scénario de repli | Client |
| 1.5 | Arrêt de la machine virtuelle MGW existante | Client |
| 2 | WireGuard | Client |
| 3 | Sélectionner la machine virtuelle cible | Client |
| 4 | Charger l'image de la machine virtuelle | Client |
| 5 | Connexion réseau à la machine virtuelle | Client |
| 6 | Accès via le navigateur | Client |
| 7 | Saisissez le code d'activation | Client |
| 8 | Configuration du mesh network | Client |
| 9 | Mise en place du mesh network sécurisé | Client |
| 10 | Connexion à Keycloak | Client |
| 11 | Mettre à jour le mot de passe | Client |
| 12 | Mettre à jour les informations du compte | Client |
| 13 | Configuration initiale et configuration du domaine | Client |
| 14 | Configurer le transport du courrier | Client |
| 15 | Configurer les whitelist headers | Client |
| 16 | Certificats de pairs | HIN |
| 17 | Valider les certificats des pairs | Client |
| 18 | Configurer le serveur de messagerie | Client |
| 19 | Test avant la migration | Client |
| 20 | Validation après le basculement | Client |
| 21 | Mise hors service du MGW existant | Client |
| 22 | Modifier le mot de passe de la machine virtuelle | Client |
| Annexe 1 | Sauvegarde et restauration des paramètres de l'appliance | Client |

## Étapes détaillées

### Étape 0 - Vérification des conditions préalables

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Veuillez consulter les Instructions de déploiement de Stargate et vous assurer que toutes les étapes préparatoires nécessaires ont été effectuées avant le début des opérations de migration du HIN Gateway.

Les éléments suivants doivent être disponibles ou confirmés avant la migration:

- **Les identifiants vous seront fournis par HIN**
    - Identifiants de la machine virtuelle
    - Identifiants Keycloak
    - Code d'activation
- **Exportation de la clé privée**
    - Si vous travaillez sur un ordinateur Windows ayant accès à la machine virtuelle Mail Gateway via le port 22, nous pouvons vous aider, pendant l'appel, à activer l'exportation de la clé privée depuis la MGW.
    - Si vous n'avez pas accès à un tel ordinateur, veuillez contacter le support HIN par e-mail ou par téléphone (<support@hin.ch> / 0848 830 740) afin que nous puissions vous aider à établir une connexion d'assistance via System Administration -> Support Connection -> Connect.
- **Télécharger la dernière version** de l'[image de la machine virtuelle](vm/VM-Catalog.md)
- **Pare-feu** :
    - Autorisez le trafic : de n'importe quelle source vers HIN Gateway et de HIN Gateway vers n'importe quelle destination
        - WireGuard : veuillez consulter [Configuration requise du serveur - Accès réseau entrant](./index.md#acces-reseau-entrant-le-pare-feu-doit-autoriser) :
            - Configurez le port WireGuard `19818` (TCP/UDP) dans votre pare-feu.
                - Trafic entrant et sortant
    - Autorisez le trafic : poste d'administration → VM HIN Gateway
        - Exigences pour l'installation :
            - Port HTTPS `443`
                - Trafic entrant et sortant
            - Port Keycloak `8180`
                - Trafic entrant et sortant
        - Exigences pour le dépannage (facultatif, requis pour consulter les journaux et modifier tous les paramètres) :
            - Port SSH `22`
                - Trafic entrant et sortant
            - Port Dozzle `8190`
                - Trafic entrant et sortant
- **L'accès DHCP** doit être disponible pour l'"[Étape 5 - Connexion réseau à la machine virtuelle](#etape-5-connexion-reseau-a-la-machine-virtuelle)" (recommandé).
- **Exigences en matière de sauvegarde**, voir "Annexe 1 - Sauvegarde et restauration des paramètres de l'appliance".
- Confirmation que le MGW existant ne sera pas supprimé tant que la procédure d'acceptation n'aura pas été menée à bien.
- Accès au DNS, aux connecteurs de serveur de messagerie, aux règles de transport et aux paramètres de relais.

!!! info "Pourquoi WireGuard ?"
    Le port WireGuard remplit deux fonctions importantes:

    1. Le HIN Gateway utilise ce port pour obtenir les certificats de ses pairs auprès de l'autorité de certification HIN.
    2. Il utilise ce port pour établir un tunnel sécurisé vers d'autres passerelles HIN, par lequel s'effectue l'échange sécurisé de données (par exemple, le trafic de messagerie).

    Pour plus d'informations : Security Assessment WireGuard (en anglais)

!!! tip "Exportation de la clé privée"
    Si vous travaillez sur un ordinateur Windows ayant accès à la machine virtuelle Mail Gateway via le port 22, nous pouvons vous aider, pendant l'appel, à activer l'exportation de la clé privée depuis la MGW.

    Si vous n'avez pas accès à un tel ordinateur, veuillez contacter le support HIN par e-mail ou par téléphone (**support@hin.ch** / **0848 830 740**) afin que nous puissions vous aider à établir une connexion d'assistance via **System Administration -> Support Connection -> Connect**.

### Étape 1.1 - Smoke Test

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Envoyez un e-mail de test aux destinataires suivants, dont vous avez accès à la boîte de réception afin de vérifier que la réception s'effectue correctement:

- une adresse e-mail HIN ou de domaine sécurisée par HIN, par exemple: `user@hin.ch`
- une adresse e-mail hors de la communauté HIN, par exemple: `user@bluewin.ch`

Vérifiez que les deux e-mails ont bien été remis, y compris l'objet, le contenu et les pièces jointes le cas échéant.

### Étape 1.2 - Sauvegarde du MGW existant

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Effectuez une sauvegarde de l'appliance MGW existant et assurez-vous que la machine virtuelle soit conservée jusqu'à ce que la migration soit terminée avec succès et officiellement acceptée. Pour plus d'informations, consultez l'"Annexe 1 - Sauvegarde et restauration des paramètres de l'appliance".

### Étape 1.3 - Exporter la ou des clés privées

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)
:heavy_plus_sign:
![Responsibility HIN](https://img.shields.io/badge/Responsibility-HIN-orange)

!!! warning "HIN assistance required"
    Un code de déverrouillage est requis pour cette étape. Ce code est fourni par un ingénieur du support HIN. Si vous souhaitez poursuivre l’installation par vous-même, veuillez contacter le support HIN afin de demander le code de déverrouillage. Dans le cas contraire, le code de déverrouillage vous sera fourni lors de l’appel de migration prévu.

1. Connectez-vous à l'interface web du MGW existant.
2. Ouvrez **"Mail System"**. <br> ![Mail System](assets/installation-guide/step1.3-2-open-mail-system.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
3. Exécutez l’application en cliquant sur [**`HIN_Migration-Tool_v*.exe`**](https://images.hin.ch/mgw/HIN_MigrationTool-v3.0.exe) si vous souhaitez l’installer vous-même. Vous pouvez également attendre l’appel de migration, au cours duquel l’ingénieur support vous assistera pour l’installatio. <br> ![HIN Migration Tool](assets/installation-guide/step1.3-3-migration-tool.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
4. Saisissez le code de déverrouillage fourni par l'ingénieur du support. <br> ![Saisir le code de déverrouillage](assets/installation-guide/step1.3-4-unlock-code.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
5. Sélectionnez **"Enable export"**. <br> ![Activer l'exportation](assets/installation-guide/step1.3-5-enable-export.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
6. Saisissez l'adresse IP du MGW. <br> ![Saisir l'adresse IP du MGW](assets/installation-guide/step1.3-6-mgw-ip.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
7. Attendez la confirmation. <br> ![Attendre la confirmation](assets/installation-guide/step1.3-7-confirmation.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
8. Sélectionnez le domaine de confiance dans l'interface web (webGUI) du MGW. <br> ![Sélectionner le domaine de confiance](assets/installation-guide/step1.3-8-trusted-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
9. Faites défiler vers le bas et sélectionnez l'empreinte numérique gérée. <br> ![Sélectionner l'empreinte numérique gérée](assets/installation-guide/step1.3-9-managed-fingerprint.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
10. Faites défiler jusqu'à la section **"PKCS12 download"** (vous pouvez, si vous le souhaitez, saisir un mot de passe pour chiffrer la clé). Cliquez sur **"PKCS12 download"** et enregistrez le fichier `*.p12` sur l'ordinateur. <br> ![Téléchargement PKCS12](assets/installation-guide/step1.3-10-pkcs12-download.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
11. Revenez à l'application `HIN_Migration-Tool_v*.exe` et désactivez le bouton **Export**. <br> ![Désactiver l'exportation](assets/installation-guide/step1.3-11-disable-export.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Étape 1.4 - Plan d'urgence / Scénario de repli

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

**Scénario de retour en arrière** - Si une restauration est nécessaire:

1. Arrêtez le nouveau HIN Gateway.
2. Démarrez le MGW existant.
3. Vérifiez que le trafic de messagerie entrant et sortant fonctionne correctement via le MGW existant.

### Étape 1.5 - Arrêt de la machine virtuelle MGW existante

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Arrêtez la machine virtuelle MGW existante.

!!! warning
    Cette étape interrompra le flux de messagerie. Pendant cette interruption, les e-mails seront mis en file d'attente sur le serveur de messagerie et remis une fois l'installation terminée.

### Étape 2 - WireGuard

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Assurez-vous d'avoir configuré le port WireGuard `19818` (TCP/UDP) dans votre pare-feu:

- Trafic entrant et sortant
- Autoriser le trafic: "any-to-HIN Gateway" et "HIN Gateway-to-any"

### Étape 3 - Sélectionnez la machine virtuelle cible

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Sélectionnez l'une des images virtuelles disponibles et provisionnez-la comme décrit dans le guide d'installation sur la page du service HIN Gateway.

!!! info
    Pour des raisons de sécurité et de prise en charge, assurez-vous que votre hyperviseur n'utilise pas une version en fin de vie. L'appliance HIN Gateway est prise en charge sur la dernière version de l'hyperviseur et sur la version majeure immédiatement précédente.

- Installation de l'image de machine virtuelle:
    - [Image de machine virtuelle Azure](vm/Azure-image-install.md)
    - [Image Windows 11 Pro (Hyper-V)](vm/Windows11pro-image-install.md)
    - [Image VMware](vm/VMware-image-install.md)
    - [Image Proxmox](vm/Proxmox-image-install.md)
- [Configuration de Microsoft Exchange](Exchange-integration.md)

### Étape 4 - Charger l'image de machine virtuelle

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Téléchargez la machine virtuelle sélectionnée sur votre hyperviseur.

!!! warning "Deuxième disque requis — le disque de données"
    L'appliance utilise deux disques : le disque OS de l'image et un **disque de données** distinct qui contient toute la configuration, les secrets, les courriels et les bases de données. Cette séparation permet à une mise à jour d'image de remplacer l'OS sans toucher à vos données.

    L'**OVA VMware inclut déjà** ce disque. Sur toutes les autres plateformes (Proxmox, Hyper-V, Azure, Cloudscale), l'image est un disque OS unique — **attachez donc un second disque vierge d'au moins 30 Go avant le premier démarrage**.

    Ne le formatez pas et ne le partitionnez pas vous-même. Au premier démarrage, l'appliance formate le disque vierge (étiquette `VEREIGN-DATA`) et le monte sur `/var/data`. Sans lui, le premier démarrage échoue à son contrôle de santé et effectue un rollback.

### Étape 5 - Connexion réseau à la machine virtuelle

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Assurez-vous que la machine virtuelle dispose d'une connexion réseau et qu'une adresse IP statique lui a été attribuée.

**Option A:** Configurez l'adresse IP de la machine virtuelle directement dans l'hyperviseur que vous utilisez.

**Option B:** Configurez le serveur DHCP de votre routeur pour qu'il attribue systématiquement la même adresse IP en fonction de l'adresse MAC de la machine virtuelle.

**Option C:** Connectez-vous localement via la console de la machine virtuelle et configurez manuellement une adresse IP statique.
REMARQUE: l'image de la machine virtuelle exécute une installation automatique lors du premier démarrage. Si le réseau n'est pas configuré à ce stade, l'installation échouera car l'adresse IP du serveur ne pourra pas être déterminée.

Ajouter une adresse IP sous Linux:

1. Exécutez la commande "nmtui" dans la console

    ```bash
    nmtui
    ```

2. Utilisez les touches fléchées pour naviguer, puis appuyez sur "Enter" pour sélectionner la "connexion Ethernet" dont vous souhaitez modifier l'adresse IP. <br> ![Add IP Addr](assets/ip_addr_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
3. Accédez à "Configuration IPv4" et modifiez le paramètre de "Automatique" à "Manuel". <br> ![Add IP Addr](assets/ip_addr_2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
4. Utilisez les touches fléchées pour accéder aux champs dans lesquels vous pouvez saisir l'adresse IP, le gateway et le serveur DNS. Sélectionnez ensuite "OK". <br> ![Add IP Addr](assets/ip_addr_3.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
5. Après avoir enregistré la configuration de l'adresse IP, exécutez la commande suivante dans la console:

    ```bash
    sudo systemctl restart NetworkManager
    ```

??? tip "Cloud-init remplace les paramètres réseau de la VM après un redémarrage"
    **Ceci s'applique uniquement à l'image legacy.** L'appliance bootc – désormais l'option par défaut – n'utilise pas cloud-init pour gérer le réseau ; elle n'est donc pas concernée et ne fournit pas les alias `cloud-init-net-*` utilisés ci-dessous.

    Sur l'image legacy (généralement sur VMware/ESXi), cloud-init n'a pas de source de données, se rabat sur « DHCP sur la première carte réseau » et régénère la configuration réseau à chaque démarrage – une adresse statique définie avec `nmtui` est donc réinitialisée après un redémarrage. Un alias corrige cela en une étape en désactivant uniquement la génération du réseau par cloud-init, de sorte qu'une adresse ensuite définie sur le profil existant persiste :

    1. Empêcher cloud-init de régénérer le réseau à chaque démarrage :
    ```bash
    cloud-init-net-disable
    ```
    2. Exécutez `nmtui`, modifiez la connexion existante **`cloud-init <iface>`** et définissez-y l'IP statique, la passerelle et le DNS. N'ajoutez pas un second profil pour la même interface – celui de cloud-init a une priorité d'autoconnexion plus élevée et l'emporterait.
    ```bash
    nmtui
    ```
    3. Redémarrez et vérifiez que l'adresse persiste :
    ```bash
    sudo reboot
    # après le redémarrage :
    nmcli device status; ip -4 addr
    ```

    `cloud-init-net-enable` rétablit le réseau géré par cloud-init par défaut. Sans l'alias, l'étape 1 est le même dépôt de fichier à la main :
    ```bash
    echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    ```

!!! tip
    REMARQUE si vous avez utilisé l'option C et configuré le réseau manuellement, vous devez exécuter les commandes suivantes:

    ```bash
    cd /usr/share/stargate-deployment/docker-compose
    ./scripts/purge.sh
    # Update configuration with a new ip, by editing it with nano
    # SERVER_STATIC_IP=<NEW IP>
    nano customer-config.sh
    # OR use sed
    # sed -i 's/old IP/new IP/g' customer-config.sh
    ./scripts/install.sh
    ```

    Le script d'installation détectera automatiquement l'adresse IP du serveur à partir de la route par défaut. Toute adresse IP accessible, qu'elle soit publique ou privée, convient. L'endpoint public effectif est configuré ultérieurement via le dashboard.

    Une fois les scripts exécutés avec succès, passez à l'"Étape 6 - Accès via le navigateur".

### Étape 6 - Accès via le navigateur

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Ouvrez un navigateur et saisissez l'adresse IP configurée pour la machine virtuelle. L'écran de configuration initiale devrait s'afficher.

```plain
https://<adresse IP de la machine virtuelle>
```

### Étape 7 - Saisissez le code d'activation

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Sélectionnez la langue de votre choix et saisissez le code d'activation que vous avez reçu par e-mail de la part de HIN. Cliquez sur "Next".

![Activation code entry screen](assets/installation-guide/step7-activation-code.png)

!!! question "Je n'ai pas de code d'activation"
    Si vous ne disposez pas du code d'activation, veuillez contacter le support HIN par e-mail ou par téléphone (<support@hin.ch> / 0848 830 740).

### Étape 8 - Configuration du mesh network

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Vérifiez la configuration du mesh network:

- **Adresse IP** - L'adresse IP publique du trafic sortant (détectée automatiquement).
- **Transport** - Le protocole de transport (par défaut: `tcp`).
- **Port** - Le port WireGuard (par défaut: `19818`).

??? question "Qu'est-ce qu'une IP publique ?"
    Il s'agit d'une adresse IP que la machine utilisera pour être accessible via Internet.
    Ce **n'est pas** l'adresse IP interne de la machine derrière un pare-feu ou un NAT, par exemple `10.0.0.0/8`, `172.16.0.0/12` ou `192.168.0.0/16`.

Vérifiez que les valeurs sont correctes, puis cliquez sur "Next".

![Mesh network setup screen](assets/installation-guide/step8-mesh-network.png)

### Étape 9 - Mise en place du mesh network

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Le système va maintenant établir la connexion au mesh network. Cette étape connecte le HIN Gateway à l'agent Iris et synchronise les certificats.

Patientez jusqu'à la fin du processus. Les indicateurs d'état afficheront "Up" lorsque la connexion sera établie avec succès. Cliquez sur "Finish".

![Establishing secure mesh network](assets/installation-guide/step9-mesh-connecting.png)

!!! failure "Si la connexion échoue"
    Si la connexion échoue ou si l'état de l'agent Iris ou de la synchronisation des certificats reste "Down":

    - Vérifiez que le port 19818 (TCP/UDP) est ouvert dans votre firewall (voir "Étape 2 - WireGuard").
    - Vérifiez que l'adresse IP indiquée à l'"Étape 8 - Configuration du mesh network" est correcte et accessible depuis Internet.
    - Relancez le processus ou contactez le support HIN par e-mail ou par téléphone (support@hin.ch / 0848 830 740).

### Étape 10 - Connexion à Keycloak

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

!!! warning
    Le port `8180` doit être ouvert pour Keycloak. Il n'est pas nécessaire qu'il soit accessible depuis Internet. En revanche, il doit être accessible entre **votre ordinateur d'administration** et la machine virtuelle (VM) que vous installez. Dans le cas contraire, vous ne pourrez pas vous connecter à Keycloak ni poursuivre l'installation.

    ??? tip "Que faire si une erreur de connexion s'affiche ?"
        Vérifiez que le port `8180` est accessible depuis votre ordinateur vers la VM. Une fois la configuration mise à jour, retournez à l'interface utilisateur à l'adresse `https://<VM IP address>` et cliquez sur le bouton « Login ».

Une fois le mesh network établi, vous serez redirigé vers la page de connexion à Keycloak. Saisissez le nom d'utilisateur et le mot de passe fournis par HIN.

![Keycloak login page](assets/installation-guide/step10-keycloak-login.png)

!!! question
    Si vous ne disposez pas de ces identifiants, veuillez contacter le support HIN par e-mail ou par téléphone (<support@hin.ch> / 0848 830 740).

### Étape 11 - Mettre à jour le mot de passe

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Lors de votre première connexion, vous serez invité à modifier votre mot de passe. Saisissez un nouveau mot de passe sécurisé et confirmez-le.

![Update password screen](assets/installation-guide/step11-update-password.png)

### Étape 12 - Mise à jour des informations de compte

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Complétez votre profil de compte en saisissant votre prénom et votre nom. L'adresse e-mail est préremplie. Cliquez sur "Submit" pour continuer.

![Update account information screen](assets/installation-guide/step12-account-info.png)

### Étape 13 - Configuration initiale et configuration du domaine

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Sur cet écran, configurez vos paramètres initiaux:

- Vérifiez que tous vos domaines de confiance actuels au sein de la communauté HIN s'affichent correctement.
- Sélectionnez le ou les domaines de confiance qui doivent être "Enabled" pour obtenir des certificats de pair auprès de l'autorité de certification HIN (HIN CA).
- Indiquez pour quel(s) domaine(s) le préfixe "sec.\<domain\>" est déjà configuré ("Use sec-prefix").

??? tip "Comment vérifier si mon domaine est configuré avec un Security Prefix ?"
    Ouvrez notre outil en ligne dans votre navigateur : <https://trust.hin.ls-infra.me/>, saisissez `sec.<domain>` et cliquez sur le bouton **Check**. Si le message suivant s'affiche :

    ✅ Ce domaine est chiffré.

    Alors votre domaine est configuré avec un Security Prefix et vous devez activer l'option **Use sec-prefix**.

- Vérifiez que le nom de l'organisation et les propriétaires du domaine sont corrects. <br> ![Screenshot](assets/step_13_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" } <br> ![Screenshot](assets/step_13_2.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
- Importez le fichier de certificat S/MIME existant (`.p12`/`.pfx`) depuis le MGW existant:
    1. Développez le domaine et sélectionnez l'option Fichier P12/PFX.
    2. Si aucun mot de passe n'a été défini pour le fichier de certificat, laissez le champ "Mot de passe" vide.
    3. Cliquez sur "Import Certficate".
    4. Une fois le certificat importé, le message "Certificate imported successfully" s'affiche.
- Cliquez sur "Save configuration" en bas de la page pour enregistrer les modifications.

![Initial setup screen](assets/installation-guide/step13-initial-setup.png)

!!! warning
    - Au moins un domaine doit être "Enabled" pour poursuivre le processus d'intégration. Le bouton "Save configuration" ne sera actif qu'une fois cette condition remplie.
    - Si vous constatez que tous les domaines de confiance ne s'affichent pas ou que les informations relatives à l'organisation sont incorrectes, veuillez contacter le support HIN par e-mail ou par téléphone (<support@hin.ch> / 0848 830 740).

!!! danger "Importez votre clé privée existante"
    Si vous n'importez pas la clé privée de votre MGW existant, une nouvelle clé sera générée. Cela peut entraîner l'impossibilité de déchiffrer les messages pendant une durée pouvant aller jusqu'à 6 heures, ce qui pourrait entraîner une perte de données.

### Étape 14 - Configurer le transport du courrier

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Sur cet écran, configurez vos paramètres de transport de courrier pour la mise en place du relais de courrier sécurisé.

![Mail transport configuration screen](assets/installation-guide/step14-mail-transport.png)

Les paramètres suivants sont disponibles:

| Paramètre | Description |
|---------|-------------|
| **Host name du serveur de messagerie** | Le nom de domaine complet (FQDN) de cette instance de gateway (par exemple, `mail.example.com`). |
| **Adresses IP du serveur de messagerie** | La ou les adresses IP publiques de ce serveur. Ajoutez des adresses IP supplémentaires si le serveur est accessible via plusieurs adresses. |
| **Domaines** | Chaque domaine géré par ce gateway, ainsi que son Relay host (le serveur de messagerie interne auquel le courrier entrant est acheminé). |
| **Relay host par défaut** | Le relais SMTP par défaut pour l'envoi des e-mails. |

Dans la section **"Advanced"**, vous pouvez éventuellement configurer:

| Paramètre | Description |
|---------|-------------|
| **Configurer TLS** | Paramètres du certificat TLS pour les connexions SMTP. |
| **Filtre de contenu** | Point de terminaison du filtre de contenu interne (par défaut: `mxengine:1587`). |
| **Réseaux de confiance** | Réseaux supplémentaires autorisés à passer par ce gateway. |

??? tip "Comment tester une connexion TLS ?"
    Vous pouvez toujours vérifier si le certificat TLS configuré a été appliqué à votre connexion au HIN Gateway. Exécutez la commande suivante directement depuis le terminal du HIN Gateway :

    ```bash
    openssl s_client -connect 127.0.0.1:25 -starttls smtp -servername mail.<YOUR_DOMAIN>
    ```

    Ou directement depuis votre machine locale :

    ```bash
    openssl s_client -connect <HIN Gateway IP>:25 -starttls smtp -servername mail.<YOUR_DOMAIN>
    ```

    La sortie affichera toutes les informations relatives à votre connexion TLS et au certificat utilisé.

??? question "Comment convertir un certificat TLS de `pfx` en `pem` ?"
    Utilisez la commande openssl suivante :

    ```bash
    openssl pkcs12 -in <Certificate>.pfx -out <Certificate>.pem -nodes
    ```

    Par exemple :

    ```bash
    openssl pkcs12 -in certificate.pfx -out keyStore.pem -nodes
    # Il est parfois nécessaire d'ajouter l'argument -legacy sur les systèmes utilisant d'anciens générateurs de certificats
    openssl pkcs12 -in certificate.pfx -out keyStore.pem -nodes -legacy
    ```

Actions supplémentaires:

- Ajoutez des domaines supplémentaires en cliquant sur "Add domain", si nécessaire.
- Développez la section "Advanced" pour affiner les paramètres de transport du courrier.

!!! note
    Assurez-vous que toutes les configurations des Relay hosts et des domaines sont correctes avant de continuer.

Une fois la configuration vérifiée et terminée, cliquez sur "Apply configuration" pour continuer.

### Étape 15 - Configurer les whitelist headers

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Cliquez sur **"Domains"**, puis sélectionnez **"Whitelist headers"**.

Saisissez la clé exactement telle qu'elle a été configurée sur le serveur de messagerie.

![Screenshot](assets/step_15_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Étape 16 - Certificats de pair

![Responsibility HIN](https://img.shields.io/badge/Responsibility-HIN-orange)

Les certificats de pair sont émis par l'autorité de certification HIN (HIN CA) pour les domaines activés.

Une fois l'intégration terminée, accédez à la section **"Peer certificates"** du dashboard et cliquez sur le bouton **"Sync certificates"** pour synchroniser vos certificats de pairs depuis l'autorité de certification HIN.

![Peer certificates screen](assets/installation-guide/step15-peer-certificates.png)

### Étape 17 - Valider les certificats de pair

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Assurez-vous que votre domaine a bien reçu son certificat de pair basé sur une politique sous **"Domains"**. Le statut de chaque domaine doit être **"Good"**.

![Screenshot](assets/step_17_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

!!! question
    Contactez le support HIN par e-mail ou par téléphone (<support@hin.ch> / 0848 830 740) si vous rencontrez des problèmes.

### Étape 18 - Configurer le serveur de messagerie et le HIN Gateway

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Si vous avez suivi la procédure recommandée, à savoir exporter la clé privée, l'importer dans le HIN Gateway et conserver la même adresse IP que celle du MGW existant, aucune modification n'est nécessaire sur le serveur de messagerie.

Sinon, configurez votre serveur de messagerie ou les composants associés de manière à ce que le trafic soit acheminé via le nouveau HIN Gateway. Vérifiez et mettez à jour les paramètres suivants si nécessaire:

#### Serveur de messagerie

- Relais SMTP / hôte intelligent
- Connecteurs
- Règles de transport
- Domaines de routage

Voir [Intégration à Exchange](Exchange-integration.md) pour obtenir des instructions détaillées.

#### Configuration du HIN Gateway

- Accédez à la page `Settings` et, pour chaque domaine, ajoutez un **hôte de relais** en utilisant la valeur que vous avez relevée dans le champ `Forwarding server` du MGW dans "Étape 1.2 - Sauvegarde du MGW existant".
  <br> ![domain-relay-host](assets/installation-guide/step18-add-domain-relay.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

- Sur la même page `Settings`, configurez l'**hôte de relais par défaut**.
- Si vous utilisez Microsoft 365 / Exchange Online, ajoutez dans **`Settings` → `Trusted networks`** les plages d'adresses IP sortantes publiées par Microsoft, afin que le HIN Gateway considère comme fiables les e-mails provenant d'Exchange Online et les relaie:

    ```text
    40.92.0.0/15
    40.107.0.0/16
    51.4.72.0/24
    51.4.80.0/27
    51.5.72.0/24
    51.5.80.0/27
    52.100.0.0/14
    104.47.0.0/17
    2a01:111:f400::/48
    2a01:111:f403::/48
    2a01:4180:4050:400::/64
    2a01:4180:4050:800::/64
    2a01:4180:4051:400::/64
    2a01:4180:4051:800::/64
    ```

  <br> ![domain-relay-host](assets/installation-guide/step18-add-default-relay-and-network.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Étape 19 - Test avant la migration

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Répétez l'"Étape 1.1 - Smoke Test". En plus du test de fonctionnement, veuillez tester et valider les étapes suivantes:

**Courrier sortant:**

- Vérifiez que le serveur de messagerie est configuré pour envoyer des e-mails au HIN Gateway à l'aide d'un relais SMTP ou d'un connecteur Exchange.
- Vérifiez que le HIN Gateway peut envoyer des e-mails à des destinataires situés en dehors de la communauté HIN.
- Vérifiez que le HIN Gateway peut envoyer des e-mails à des destinataires au sein de la communauté HIN via WireGuard.

**Courrier entrant:**

- Vérifiez que les e-mails chiffrés provenant de la communauté HIN peuvent être reçus via WireGuard. Un expéditeur du domaine hin.ch constitue le scénario de test le plus simple.
- Vérifiez que les e-mails chiffrés provenant de la communauté HIN peuvent être reçus via SMTP à l'aide de S/MIME.
- Vérifiez que les réponses provenant d'expéditeurs extérieurs à la communauté HIN à un e-mail sécurisé initial (HIN Mail-SEAL) parviennent au HIN Gateway.
- Vérifiez que les e-mails en texte clair provenant d'expéditeurs externes à la communauté HIN peuvent être reçus.

### Étape 20 - Validation après la migration

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Confirmer:

- E-mails remis
- Chiffrement appliqué
- Aucun retard ni message rejeté
- Enregistrement réussi

Remplissez le [Formulaire de réception](https://www.hin.ch/files/pdf1/gateway-acceptance-en.pdf) et renvoyez-le à votre représentant HIN.

### Étape 21 - Mise hors service du MGW existant

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

!!! warning
    Ne supprimez pas immédiatement la machine virtuelle MGW existante; conservez-la en lieu sûr jusqu'à ce que tout soit opérationnel.

1. **Assurez-vous qu'il n'y a pas de trafic actif** - Vérifiez:
    - Aucun domaine ne pointe vers le MGW (DNS, SMTP, connecteurs).
    - Aucun e-mail n'est transféré via l'ancienne appliance.
2. **Archivez les journaux** - Exportez et enregistrez:
    - Journaux des e-mails
    - Journaux de sécurité/d'audit
    - Requis pour la conformité et le dépannage
3. **Nettoyage (facultatif)** - Supprimer:
    - Règles de firewall
    - DNS entries
    - Configurations de routage faisant référence au MGW existant

### Étape 22 - Modifier le mot de passe de la machine virtuelle

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Veuillez vous assurer que les identifiants de la machine virtuelle qui vous ont été fournis initialement sont remplacés par le mot de passe de votre choix et conservez-les dans un endroit sûr et sécurisé.

## Annexe 1 - Sauvegarde et restauration des paramètres de l'appliance

![Responsibility Customer](https://img.shields.io/badge/Responsibility-Customer-success)

Pour sauvegarder ou restaurer les paramètres de votre appliance HIN, cliquez sur le menu **"Administration"** dans le portail d'administration Web.

![Screenshot](assets/annex_1_1.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Sauvegarde des paramètres

Avant de créer une sauvegarde des paramètres actuels de votre appliance HIN, vous devez définir un mot de passe de sauvegarde. Ce mot de passe est nécessaire si vous devez restaurer la sauvegarde ultérieurement.

- Pour définir ou modifier le mot de passe de sauvegarde, cliquez sur **"Change Password"**.
- Pour créer et télécharger un fichier de sauvegarde, cliquez sur **"Download"**.

### Modification du mot de passe de sauvegarde

Pour modifier le mot de passe des futures sauvegardes, cliquez sur **"Change Password"**.

!!! note
    Veuillez noter que le nouveau mot de passe ne s'applique qu'aux sauvegardes créées après la modification du mot de passe. Les fichiers de sauvegarde existants restent protégés par le mot de passe défini lors de leur création.

### Restauration des paramètres

Pour restaurer les paramètres de l'appliance à partir d'un fichier de sauvegarde, cliquez sur **"Import Backup File"**.

Dans la fenêtre de dialogue, sélectionnez le fichier de sauvegarde souhaité et saisissez le mot de passe associé à cette sauvegarde. Les paramètres de l'appliance seront alors restaurés à partir du fichier de sauvegarde sélectionné.

### Sauvegarde via SCP

Le MGW prend en charge la sauvegarde de l'appliance via SCP.

Pour utiliser cette option, la clé publique du système qui accédera au MGW doit être enregistrée sous **"Backup using SCP"**. La sauvegarde est générée automatiquement tous les jours à minuit et est stockée sur le MGW sous le nom `backup.tgz`.

À l'aide de la clé publique configurée, le fichier de sauvegarde peut être récupéré via SCP par l'utilisateur `backup` du système d'exploitation. Une commande SCP type pour récupérer le fichier de sauvegarde est la suivante:

```bash
scp backup@192.168.1.60:/backup.tgz .
```

Cette commande télécharge le fichier `backup.tgz` depuis le MGW vers le répertoire local actuel.

!!! note
    Si vous saisissez une nouvelle clé publique, la clé existante sera remplacée.
