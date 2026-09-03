# Configuration du relais de courrier HIN Gateway

## Créer un relais HIN Gateway pour un domaine de courrier hébergé dans Microsoft Office 365

Pour le relais, nous avons besoin d'une VM ou d'un serveur avec une adresse IP statique réelle.

Dans cet exemple, nous utiliserons une VM avec l'adresse IP `128.140.117.200` et le nom d'hôte `mail.vrgnservices.eu` pour relayer les courriels pour le domaine `vrgnservices.eu`.

## Configurer les enregistrements DNS

Consultez le [Guide de configuration DNS](./DNS-setup.md) pour des instructions complètes sur tous les enregistrements requis (A, MX, SPF, PTR, DMARC, DKIM).

Exemple rapide pour le domaine `vrgnservices.eu` avec l'IP HIN Gateway `128.140.117.200`:

* **Enregistrement A**: `mail.vrgnservices.eu` → `128.140.117.200`
* **Enregistrement MX**: `MX @ 15 mail.vrgnservices.eu.` (priorité plus élevée que l'Exchange MX existant à 20)
* **Enregistrement SPF**: `v=spf1 ip4:128.140.117.200 include:spf.protection.outlook.com -all`

Vérifier:

```shell
# host mail.vrgnservices.eu
mail.vrgnservices.eu a l'adresse 128.140.117.200
```

```shell
# host -t mx vrgnservices.eu
vrgnservices.eu le courrier est géré par 20 vrgnservices-eu.mail.protection.outlook.com.
vrgnservices.eu le courrier est géré par 15 mail.vrgnservices.eu.
```

```shell
# host -t txt vrgnservices.eu|grep v=spf1
vrgnservices.eu texte descriptif "v=spf1 ip4:128.140.117.200 include:spf.protection.outlook.com -all"
```

## Installer les conteneurs docker compose HIN Gateway

[Déploiement HIN Gateway](./Docker-deploy.md)

### Exigences

* **2 cœurs CPU** (minimum)
* **4 Go de RAM** (minimum)
* **20 Go de stockage** (minimum)
* **Accès root**: Doit être exécuté en tant que root ou avec `sudo`
* **Distributions prises en charge**:
  * Distributions compatibles RHEL 8, 9 et 10 telles que Alma Linux, Rocky Linux, CentOS Stream
  * Ubuntu 22 et 24
  * Debian 11, 12 et 13
* **Adresse IPv4 réelle**
* **Enregistrements DNS valides**: Votre domaine doit avoir:
  * Des enregistrements MX pointant vers vos serveurs de courrier
  * Un enregistrement SPF définissant les réseaux d'envoi autorisés

Le script installe tous les composants et les démarre. Les domaines de courrier et le nom d'hôte Stalwart sont ensuite configurés à l'exécution via la page `/mail` du tableau de bord (le démon mtaconf extrait les paramètres de relais de courrier nécessaires du DNS en fonction de ces domaines).

## Configurer Exchange

Nous devons configurer des connecteurs et une règle de transport dans Exchange pour relayer tous les courriels sortants vers le relais HIN Gateway et autoriser les courriels entrants de celui-ci.

Accédez à [https://admin.exchange.microsoft.com/#/connectors](https://admin.exchange.microsoft.com/#/connectors)

### Connecteur sortant

Créez un connecteur de courrier sortant, cliquez sur "Ajouter":

Sélectionnez "Connexion depuis": "Office 365" "Connexion vers": "Serveur de courrier de votre organisation", cliquez sur "Suivant".

![capture d'écran](./assets/new_connector_outgoing1.png)

Nommez-le par exemple "From Office 365 to HIN Gateway relay server" et cochez "Conserver les en-têtes de courrier internes Exchange", cliquez sur "Suivant".

![capture d'écran](./assets/new_connector_outgoing2.png)

Sélectionnez "Uniquement lorsque j'ai une règle de transport configurée qui redirige les messages vers ce connecteur", cliquez sur "Suivant".

![capture d'écran](./assets/new_connector_outgoing3.png)

Entrez l'adresse IP du serveur relais HIN Gateway, cliquez sur "+", cliquez sur "Suivant".

![capture d'écran](./assets/new_connector_outgoing4.png)

Sélectionnez "Tout certificat numérique, y compris les certificats auto-signés", cliquez sur "Suivant".

![capture d'écran](./assets/new_connector_outgoing5.png)

Entrez une adresse de courrier valide pour votre domaine, cliquez sur "+", cliquez sur "Valider", cliquez sur "Suivant".

![capture d'écran](./assets/new_connector_outgoing6.png)

Cliquez sur "Créer un connecteur".

![capture d'écran](./assets/new_connector_outgoing7.png)

Cliquez sur "Ajouter un autre connecteur".

![capture d'écran](./assets/new_connector_outgoing8.png)

### Connecteur entrant

Créez un connecteur de courrier entrant, choisissez "Connexion depuis": "Serveur de courrier de votre organisation", cliquez sur "Suivant".

![capture d'écran](./assets/new_connector_incoming1.png)

Nommez-le par exemple "Receive mail from HIN Gateway relay server" et cochez "Conserver les en-têtes de courrier internes Exchange", cliquez sur "Suivant".

![capture d'écran](./assets/new_connector_incoming2.png)

Sélectionnez "En vérifiant que l'adresse IP du serveur d'envoi correspond à l'une des adresses IP suivantes", tapez l'adresse IP du serveur HIN Gateway, cliquez sur "+", cliquez sur "Suivant".

![capture d'écran](./assets/new_connector_incoming3.png)

Cliquez sur "Créer un connecteur".

![capture d'écran](./assets/new_connector_incoming4.png)

Cliquez sur "Terminé".

![capture d'écran](./assets/new_connector_incoming5.png)

Voici à quoi cela ressemble une fois terminé:

![capture d'écran](./assets/new_connector_incoming6.png)

### Règle de transport

Créez la règle de transport. Accédez à [https://admin.exchange.microsoft.com/#/transportrules](https://admin.exchange.microsoft.com/#/transportrules)

Cliquez sur "+Ajouter une règle" --> "Créer une nouvelle règle".

![capture d'écran](./assets/new_transport_rule1.png)

Nommez-la par exemple "Relay all mail to HIN Gateway except mail coming from it", choisissez "Appliquer cette règle si" "Le destinataire :" "est externe/interne" "En dehors de l'organisation", cliquez sur "Enregistrer".  

![capture d'écran](./assets/new_transport_rule2.png)

Choisissez "Faire ce qui suit" "Rediriger le message vers le connecteur suivant" "From Office 365 to HIN Gateway relay server", cliquez sur "Enregistrer".

![capture d'écran](./assets/new_transport_rule3.png)

Choisissez "Sauf si L'adresse IP de l'expéditeur se trouve dans l'une de ces plages" entrez l'adresse IP du serveur HIN Gateway, cliquez sur "Ajouter", vérifiez l'adresse IP et cliquez sur "Enregistrer".

Ceci est nécessaire pour éviter les boucles de courrier, car cette règle s'applique également à d'autres domaines hébergés dans Office 365.  

![capture d'écran](./assets/new_transport_rule4.png)

Maintenant, cela devrait ressembler à ceci, cliquez sur "Suivant":

![capture d'écran](./assets/new_transport_rule5.png)

Cliquez sur "Suivant".

![capture d'écran](./assets/new_transport_rule6.png)

Cliquez sur "Terminer".

![capture d'écran](./assets/new_transport_rule7.png)

Cliquez sur "Terminé".

![capture d'écran](./assets/new_transport_rule8.png)

![capture d'écran](./assets/new_transport_rule9.png)

Cliquez sur la règle et définissez "Activer ou désactiver la règle" sur "Activé"  

![capture d'écran](./assets/new_transport_rule10.png)
