# Intégration Exchange avec HIN Gateway

Ce guide explique comment configurer Microsoft Exchange (Online et On-Premises) pour acheminer les courriels via la passerelle HIN Gateway pour la signature et le chiffrement S/MIME.

<!-- Référence interne
     Ce guide est basé sur la page wiki [HIN Gateway mail relay setup](https://plan.vereign.com/projects/mail-gateway/wiki/stargate-mail-relay-setup) (par Zdravko Komitov). -->

![Noeud Mesh](assets/hin-mesh-node-orange-rgb-1.jpg){ width=32%; }
![O365 comme serveur MX](assets/hin-mesh-node-orange-rgb-2.png){ width=32%; }
![Serveur MX différent](assets/hin-mesh-node-orange-rgb-3.png){ width=32%; }

## Aperçu

HIN Gateway agit comme un relais de courrier entre les serveurs de courrier externes et votre environnement Exchange. Deux modèles d'intégration sont pris en charge:

**Modèle A - Exchange Online comme MX principal avec règles de transport :**

```mermaid
flowchart LR
    I1 --> EO --> TR --> C --> S1 --> EO
    E2 --> TR2 --> OC --> S2 --> I2
    I1["Internet"]
    I2["Internet"]
    EO["Exchange Online"]
    E2["Exchange Online"]
    TR["Règle de transport"]
    TR2["Règle de transport"]
    OC["Connecteur sortant"]
    C["Connecteur"]
    S1["HIN Gateway"]
    S2["HIN Gateway"]
```

**Modèle B - HIN Gateway comme MX principal:**

```mermaid
flowchart LR
    I1 --> mx15 --> mx20
    EO --> TR --> OC --> HG --> I2
    I1["Internet"]
    I2["Internet"]
    mx15["HIN Gateway (priorité MX 15)"]
    mx20["Exchange Online (priorité MX 20)"]
    EO["Exchange Online"]
    TR["Règle de transport"]
    OC["Connecteur sortant"]
    HG["HIN Gateway"]
```

Dans les deux modèles, vous avez besoin de:

1. **Enregistrements DNS** pointant vers le serveur HIN Gateway
2. **Connecteur sortant** - achemine les courriels d'Exchange vers HIN Gateway
3. **Connecteur entrant** - accepte les courriels de HIN Gateway dans Exchange
4. **Règle de transport** - déclenche le connecteur sortant pour les destinataires externes

## Prérequis

Avant de configurer Exchange, assurez-vous que:

- [X] HIN Gateway est installé et en cours d'exécution ([instructions de déploiement](Docker-deploy.md))
- [X] Vous disposez de **l'adresse IP publique du serveur HIN Gateway** (référencée ci-dessous comme `<HIN Gateway_IP>`)
- [X] Vous disposez du **nom d'hôte de courrier** du serveur HIN Gateway (référencé ci-dessous comme `<MAIL_HOSTNAME>`, ex. `mail.example.com`)
- [X] Vous connaissez votre **domaine de courrier** (référencé ci-dessous comme `<YOUR_DOMAIN>`, ex. `example.com`)
- [X] Vous avez un accès **admin Exchange** (Centre d'administration Exchange ou Shell de gestion Exchange sur site)
- [X] Les enregistrements DNS sont configurés selon le [Guide de configuration DNS](DNS-setup.md) (A, MX, SPF au minimum)

---

## Partie 1: Configuration DNS

Consultez le [Guide de configuration DNS](DNS-setup.md) pour des instructions complètes sur la configuration des enregistrements A, MX, SPF, PTR, DMARC et DKIM.

Au minimum, avant de procéder à la configuration Exchange ci-dessous, vous avez besoin de:

- **Enregistrement A**: `<MAIL_HOSTNAME>` pointant vers `<HIN Gateway_IP>`
- **Enregistrement MX**: `<YOUR_DOMAIN>` avec HIN Gateway à une priorité plus élevée (nombre inférieur) qu'Exchange
- **Enregistrement SPF**: `ip4:<HIN Gateway_IP>` et `ip4:<HIN_SEALER_IP>` ajoutés à l'enregistrement TXT de votre domaine (voir [Guide de configuration DNS - SPF](DNS-setup.md#enregistrement-spf) pour les IPs du scelleur)

---

## Partie 2: Configuration Exchange Online

### Étape A: Créer le connecteur sortant (Office 365 → HIN Gateway)

Ce connecteur achemine les courriels sortants d'Exchange Online vers le serveur relais HIN Gateway.

1. Accédez au [Centre d'administration Exchange - Connecteurs](https://admin.exchange.microsoft.com/#/connectors)

2. Cliquez sur **"+ Ajouter un connecteur"**

3. **Connexion depuis**: Sélectionnez **"Office 365"**
   - **Connexion vers**: Sélectionnez **"Serveur de courrier de votre organisation"**
   - Cliquez sur **"Suivant"**

4. **Nom du connecteur**: Entrez un nom descriptif, ex.:

   ```plain
   From Office 365 to HIN Gateway relay server
   ```

   - Cochez **"Conserver les en-têtes de courrier internes Exchange"**
   - Cliquez sur **"Suivant"**

5. **Utilisation du connecteur**: Sélectionnez **"Uniquement lorsque j'ai une règle de transport configurée qui redirige les messages vers ce connecteur"**
   - Cliquez sur **"Suivant"**

!!! tip
    Ceci est important - le connecteur n'acheminera aucun courrier par lui-même. Il ne sera utilisé que lorsqu'il sera déclenché par la règle de transport créée à l'étape C.

1. **Routage**: Sélectionnez **"Acheminer les courriels via ces hôtes intelligents"**
   - Entrez l'adresse IP du serveur HIN Gateway: `<HIN Gateway_IP>`
   - Cliquez sur **"+"** pour l'ajouter, puis sur **"Suivant"**

2. **Restrictions de sécurité**: Sélectionnez **"Tout certificat numérique, y compris les certificats auto-signés"**
   - Cliquez sur **"Suivant"**

!!! note
    Le MTA de HIN Gateway (Stalwart) accepte TLS opportuniste sur les connexions entrantes. Sélectionner "tout certificat numérique" assure la connectivité même avec des certificats auto-signés.

1. **Courriel de validation**: Entrez une adresse de courrier valide pour votre domaine (ex. `user@<YOUR_DOMAIN>`)
   - Cliquez sur **"+"**, puis sur **"Valider"**
   - Attendez que la validation se termine, puis cliquez sur **"Suivant"**

!!! tip
    Pour que la validation réussisse, le serveur HIN Gateway doit être en cours d'exécution et accepter les courriels sur le port 25.

1. Examinez les paramètres et cliquez sur **"Créer un connecteur"**

2. Sur l'écran de confirmation, cliquez sur **"Terminé"**

### Étape B: Créer le connecteur entrant (HIN Gateway → Office 365)

Ce connecteur accepte les courriels du serveur relais HIN Gateway dans Exchange Online.

1. Depuis la [page Connecteurs](https://admin.exchange.microsoft.com/#/connectors), cliquez sur **"+ Ajouter un connecteur"**

2. **Connexion depuis**: Sélectionnez **"Serveur de courrier de votre organisation"**
   - **Connexion vers**: Affiche **"Office 365"** (automatique)
   - Cliquez sur **"Suivant"**

3. **Nom du connecteur**: Entrez un nom descriptif, ex.:

   ```plain
   Receive mail from HIN Gateway relay server
   ```

   - Cochez **"Conserver les en-têtes de courrier internes Exchange"**
   - Cliquez sur **"Suivant"**

4. **Authentification des courriels envoyés**: Sélectionnez **"En vérifiant que l'adresse IP du serveur d'envoi correspond à l'une des adresses IP suivantes qui appartiennent exclusivement à votre organisation"**
   - Entrez l'adresse IP du serveur HIN Gateway: `<HIN Gateway_IP>`
   - Cliquez sur **"+"** pour l'ajouter, puis sur **"Suivant"**

!!! note
    Cela indique à Exchange Online de faire confiance aux courriels provenant de cette adresse IP spécifique, en contournant les vérifications supplémentaires de spam/authentification pour les courriels déjà traités par HIN Gateway.

1. Examinez les paramètres et cliquez sur **"Créer un connecteur"**

2. Cliquez sur **"Terminé"**

### Vérifier les connecteurs

Après avoir créé les connecteurs (y compris le connecteur Send to MX de l'[étape D](#etape-d-outgoing-to-mx-connecteur-send-to-mx-et-regle)), la page Connecteurs devrait afficher:

| Statut | Nom | Depuis | Vers |
|--------|------|------|-----|
| Activé | Receive mail from HIN Gateway relay server | Votre org | O365 |
| Activé | From Office 365 to HIN Gateway relay server | O365 | Votre org |
| Activé | Send to MX | O365 | Votre org |

### Étape C: Créer la règle de transport

La règle de transport redirige tous les courriels sortants via le connecteur sortant HIN Gateway, sauf les courriels provenant de HIN Gateway lui-même (pour éviter les boucles de courrier).

1. Accédez au [Centre d'administration Exchange - Règles](https://admin.exchange.microsoft.com/#/transportrules)

2. Cliquez sur **"+ Ajouter une règle"** → **"Créer une nouvelle règle"**

3. **Nom de la règle**: Entrez un nom descriptif, ex.:

   ```plain
   Relay all mail to HIN Gateway except mail coming from it
   ```

4. **Appliquer cette règle si**: Sélectionnez **"Le destinataire..."** → **"est externe/interne"** → **"En dehors de l'organisation"**
   - Cliquez sur **"Enregistrer"**

!!! note
    Cette condition garantit que seuls les courriels sortants (vers des destinataires externes) sont redirigés via HIN Gateway.

1. **Faire ce qui suit**: Sélectionnez **"Rediriger le message vers..."** → **"le connecteur suivant"** → sélectionnez le connecteur sortant créé à l'étape A (ex. "From Office 365 to HIN Gateway relay server")
   - Cliquez sur **"Enregistrer"**

2. **Sauf si**: Cliquez sur **"+"** pour ajouter une exception
   - Sélectionnez **"L'expéditeur..."** → **"L'adresse IP se trouve dans l'une de ces plages"**
   - Entrez l'adresse IP du serveur HIN Gateway: `<HIN Gateway_IP>`
   - Cliquez sur **"Ajouter"**, vérifiez que l'IP est listée, puis cliquez sur **"Enregistrer"**

!!! warning
    **Cette exception est critique** - elle empêche les boucles de courrier. Sans elle, les courriels de HIN Gateway arrivant dans Exchange Online seraient redirigés vers HIN Gateway dans une boucle infinie.

1. Examinez le résumé de la règle. Il devrait afficher:
   - **Appliquer cette règle si**: Le destinataire est situé En dehors de l'organisation
   - **Faire ce qui suit**: Rediriger le message vers le connecteur "From Office 365 to HIN Gateway relay server"
   - **Sauf si**: L'adresse IP de l'expéditeur se trouve dans l'une de ces plages: `<HIN Gateway_IP>`

2. Cliquez sur **"Suivant"**, puis sur **"Suivant"** à nouveau, puis sur **"Terminer"**, puis sur **"Terminé"**

3. **Activer la règle**: La règle est créée dans un état désactivé. Cliquez sur la règle dans la liste et basculez **"Activer ou désactiver la règle"** sur **"Activé"**

!!! tip
    N'oubliez pas d'activer la règle - elle ne fonctionnera pas tant qu'elle ne sera pas activée.

### Étape D: Outgoing to MX (connecteur Send to MX et règle)

Une fois que HIN Gateway a traité (signé ou chiffré) un message sortant, il le renvoie à Exchange Online via le connecteur entrant de l'étape B. Exchange Online doit ensuite le remettre au serveur de courrier du destinataire. C'est le rôle de la configuration «Outgoing to MX»: un connecteur dédié **Send to MX** envoie le message au MX du destinataire externe, et la règle de transport **outgoing_to_mx** redirige les messages traités vers ce connecteur.

#### Créer le connecteur Send to MX (Office 365 → Organisation partenaire)

1. Depuis la [page Connecteurs](https://admin.exchange.microsoft.com/#/connectors), cliquez sur **"+ Ajouter un connecteur"**

2. **Connexion depuis**: Sélectionnez **"Office 365"**
   - **Connexion vers**: Sélectionnez **"Organisation partenaire"**
   - Cliquez sur **"Suivant"**

3. **Nom du connecteur**: Entrez un nom descriptif, ex.:

   ```plain
   Send to MX
   ```

   - Assurez-vous que le connecteur est activé
   - Cliquez sur **"Suivant"**

!!! note
    Le nom du connecteur peut être choisi librement. Si vous utilisez un autre nom, sélectionnez ce nom dans la règle `outgoing_to_mx` décrite ci-dessous.

4. **Utilisation du connecteur**: Sélectionnez **"Uniquement lorsque j'ai une règle de transport configurée qui redirige les messages vers ce connecteur"**
   - Cliquez sur **"Suivant"**

!!! tip
    Comme le connecteur sortant de l'étape A, ce connecteur n'achemine aucun courrier par lui-même. Il n'est utilisé que lorsque la règle `outgoing_to_mx` décrite ci-dessous lui redirige un message.

5. **Routage**: Sélectionnez **"Utiliser l'enregistrement MX associé au domaine du partenaire"**
   - Cliquez sur **"Suivant"**

6. **Restrictions de sécurité**: Laissez **"Toujours utiliser TLS (Transport Layer Security) pour sécuriser la connexion"** décoché, afin qu'aucune restriction de sécurité ne s'applique
   - Cliquez sur **"Suivant"**

!!! note
    Ce connecteur remet le courrier à n'importe quel destinataire externe. Exiger TLS ou un certificat précis bloquerait la remise vers les serveurs destinataires qui ne remplissent pas ces conditions.

7. **Courriel de validation**: Entrez une adresse de courrier externe (en dehors de votre organisation)
   - Cliquez sur **"+"**, puis sur **"Valider"**
   - Attendez que la validation se termine, puis cliquez sur **"Suivant"**

8. Examinez les paramètres et cliquez sur **"Créer un connecteur"**

9. Cliquez sur **"Terminé"**

Le résumé du connecteur devrait afficher:

- **Scénario de flux de courrier**: Depuis Office 365, vers Organisation partenaire
- **Nom**: Send to MX
- **Statut**: Activé
- **Utilisation du connecteur**: Utiliser uniquement lorsque j'ai une règle de transport configurée qui redirige les messages vers ce connecteur
- **Routage**: Utiliser l'enregistrement MX associé au domaine du partenaire
- **Restrictions de sécurité**: Aucune

#### Créer la règle de transport outgoing_to_mx

Cette règle redirige vers le connecteur Send to MX les messages sortants qui reviennent de HIN Gateway. Elle reconnaît ces messages grâce à l'en-tête `outgoing`.

1. Accédez au [Centre d'administration Exchange - Règles](https://admin.exchange.microsoft.com/#/transportrules)

2. Cliquez sur **"+ Ajouter une règle"** → **"Créer une nouvelle règle"**

3. **Nom de la règle**: Entrez:

   ```plain
   outgoing_to_mx
   ```

4. **Appliquer cette règle si**: Sélectionnez **"Les en-têtes du message..."** → **"correspondent à ces modèles de texte"**
   - Nom de l'en-tête: `outgoing`
   - Modèle de texte: `outgoing_<YOUR_DOMAIN>` (ex. `outgoing_example.com`)
   - Cliquez sur **"Enregistrer"**

!!! note
    L'en-tête `outgoing` doit déjà figurer dans le message lorsqu'il revient de HIN Gateway. Dans la configuration de référence HIN, il est ajouté par une règle distincte (`set_header`), qui s'applique lorsque l'expéditeur se trouve dans l'organisation et définit l'en-tête `outgoing` avec la valeur `outgoing_<YOUR_DOMAIN>`. Sans cet en-tête, la règle `outgoing_to_mx` ne s'applique jamais.

5. **Faire ce qui suit**: Sélectionnez **"Rediriger le message vers"** → **"le connecteur suivant"** → sélectionnez **"Send to MX"**
   - Cliquez sur **"Enregistrer"**

6. **Sauf si**: Laissez vide

7. Cliquez sur **"Suivant"** pour ouvrir les paramètres de la règle:
   - **Mode de la règle**: **"Appliquer"**
   - **Gravité**: **"Non spécifiée"**
   - Laissez **"Activer cette règle le"** et **"Désactiver cette règle le"** décochés
   - Cochez **"Arrêter le traitement des règles suivantes"**
   - Laissez **"Différer le message si le traitement de la règle n'est pas terminé"** décoché
   - **Faire correspondre l'adresse de l'expéditeur dans le message**: **"En-tête"**

8. Cliquez sur **"Suivant"**, puis sur **"Terminer"**, puis sur **"Terminé"**

9. **Définir la priorité**: Cliquez sur la règle dans la liste, puis sur **"Modifier les paramètres de la règle"**, et donnez-lui une **priorité** plus élevée (nombre plus petit) que celle de la règle de transport de l'étape C, ex. `1`
   - Cliquez sur **"Enregistrer"**

!!! warning
    **La priorité et l'option «Arrêter le traitement des règles suivantes» sont critiques.** La règle doit être évaluée avant celle de l'étape C et doit arrêter le traitement. Sinon, un message qui revient de HIN Gateway risque d'être redirigé à nouveau vers HIN Gateway au lieu d'être remis au destinataire.

10. Examinez les détails de la règle. Ils devraient afficher:
    - **Nom de la règle**: outgoing_to_mx
    - **Mode**: Appliquer
    - **Gravité**: Non spécifiée
    - **Plage de dates**: Aucune plage de dates spécifique n'est définie
    - **Adresse de l'expéditeur**: Correspondance avec l'en-tête
    - **Priorité**: 1
    - **En cas d'erreurs de traitement de la règle**: Ignorer
    - **Appliquer cette règle si**: L'en-tête `'outgoing'` correspond aux modèles suivants: `'outgoing_<YOUR_DOMAIN>'`
    - **Faire ce qui suit**: Acheminer le message via le connecteur «Send to MX» et arrêter le traitement des règles suivantes

11. **Activer la règle**: La règle est créée dans un état désactivé. Basculez **"Activer ou désactiver la règle"** sur **"Activé"**

!!! tip
    N'oubliez pas d'activer la règle: elle ne fonctionnera pas tant qu'elle ne sera pas activée.

---

## Partie 3: Configuration du serveur Exchange On-Premises

Pour Exchange Server On-Premises (2016, 2019), la configuration est similaire mais effectuée via la console de gestion Exchange (EAC) ou le Shell de gestion Exchange (PowerShell).

### Connecteur d'envoi (On-Premises → HIN Gateway)

Créez un connecteur d'envoi pour acheminer les courriels sortants via HIN Gateway:

**Shell de gestion Exchange (PowerShell) :**

```powershell
New-SendConnector -Name "To HIN Gateway Relay" `
  -AddressSpaces "SMTP:*;1" `
  -SmartHosts "<HIN Gateway_IP>" `
  -SmartHostAuthMechanism None `
  -DNSRoutingEnabled $false `
  -SourceTransportServers "<VOTRE_SERVEUR_EXCHANGE>"
```

**Centre d'administration Exchange (GUI) :**

1. Accédez à **Flux de courrier** → **Connecteurs d'envoi**
2. Cliquez sur **+** pour créer un nouveau connecteur
3. **Nom**: "To HIN Gateway Relay"
4. **Type**: Sélectionnez **"Internet"**
5. **Paramètres réseau**: Sélectionnez **"Acheminer les courriels via des hôtes intelligents"**, ajoutez `<HIN Gateway_IP>`
6. **Authentification de l'hôte intelligent**: Sélectionnez **"Aucune"**
7. **Espace d'adressage**: Ajoutez `*` (tous les domaines) ou des domaines externes spécifiques
8. **Serveur source**: Sélectionnez votre ou vos serveurs de transport Exchange

### Connecteur de réception (HIN Gateway → On-Premises)

Créez ou modifiez un connecteur de réception pour accepter les courriels de HIN Gateway:

**Shell de gestion Exchange (PowerShell) :**

```powershell
New-ReceiveConnector -Name "From HIN Gateway Relay" `
  -Bindings "0.0.0.0:25" `
  -RemoteIPRanges "<HIN Gateway_IP>" `
  -TransportRole FrontendTransport `
  -Usage Custom `
  -AuthMechanism ExternalAuthoritative `
  -PermissionGroups ExchangeServers
```

**Centre d'administration Exchange (GUI) :**

1. Accédez à **Flux de courrier** → **Connecteurs de réception**
2. Cliquez sur **+** pour créer un nouveau connecteur
3. **Nom**: "From HIN Gateway Relay"
4. **Type**: Sélectionnez **"Transport frontal"**
5. **Liaisons des adaptateurs réseau**: Laissez par défaut ou liez à une IP spécifique
6. **Paramètres réseau distants**: Supprimez la valeur par défaut `0.0.0.0-255.255.255.255` et ajoutez uniquement `<HIN Gateway_IP>`
7. **Authentification**: Cochez **"Sécurisé externellement"**
8. **Groupes de permissions**: Cochez **"Serveurs Exchange"**

### Règle de transport (On-Premises)

Créez une règle de transport pour rediriger les courriels sortants via le connecteur d'envoi:

**Shell de gestion Exchange (PowerShell) :**

```powershell
New-TransportRule -Name "Relay outbound via HIN Gateway" `
  -SentToScope NotInOrganization `
  -RouteMessageOutboundConnector "To HIN Gateway Relay" `
  -ExceptIfSenderIpRanges "<HIN Gateway_IP>"
```

**Centre d'administration Exchange (GUI) :**

1. Accédez à **Flux de courrier** → **Règles**
2. Cliquez sur **+** → **"Créer une nouvelle règle"**
3. **Nom**: "Relay outbound via HIN Gateway"
4. **Appliquer cette règle si**: "Le destinataire est situé..." → "En dehors de l'organisation"
5. **Faire ce qui suit**: "Rediriger le message vers..." → "le connecteur suivant" → "To HIN Gateway Relay"
6. **Sauf si**: "L'adresse IP de l'expéditeur est dans..." → ajoutez `<HIN Gateway_IP>`

---

## Partie 4: Configuration côté HIN Gateway

### Configuration automatique (Par défaut)

Par défaut, Stalwart découvre automatiquement où livrer les courriels traités en consultant les enregistrements MX pour chaque domaine configuré via la page `/mail` du tableau de bord. Il filtre son propre nom d'hôte et utilise les entrées MX restantes comme cibles de livraison.

Cela fonctionne lorsque:

- Votre domaine a des enregistrements MX pointant à la fois vers HIN Gateway et Exchange
- HIN Gateway a un enregistrement MX de priorité plus élevée (nombre inférieur) qu'Exchange

### Remplacement manuel via le tableau de bord

Si vous souhaitez que tous les courriels sortants de HIN Gateway aillent vers un seul point de terminaison Exchange (ex. Exchange Online Protection), définissez l'hôte de relais via la page `/mail` du tableau de bord (ex. `[smtp.office365.com]`). Le tableau de bord envoie la valeur à l'API REST de mtaconf et le démon l'applique à Stalwart.

!!! note
    Un seul hôte de relais envoie tous les courriels via un seul serveur et ne prend pas en charge le routage par domaine. Pour plusieurs domaines acheminés via différents serveurs Exchange, utilisez la carte de relais par domaine sur la même page du tableau de bord (configure `sender_dependent_relayhost_maps` en arrière-plan) - voir [Configuration multi-domaines](#configuration-multi-domaines) ci-dessous.

### Configuration multi-domaines

Pour les configurations avec plusieurs domaines et différents serveurs Exchange (ex. BALZ Informatik AG avec 26 domaines), utilisez les enregistrements MX pour le routage par domaine:

```plain
domain1.com    MX 10  exchange1.domain1.com
domain1.com    MX 20  stargate.domain1.com

domain2.com    MX 10  exchange2.domain2.com
domain2.com    MX 20  stargate.domain2.com
```

Les enregistrements MX de chaque domaine indiquent à HIN Gateway où livrer les courriels traités pour ce domaine spécifique.

### Vérifier la configuration HIN Gateway

Après la configuration, vérifiez la configuration de Stalwart:

#### Vérifier la configuration du relais

```bash
docker logs stargate-stalwart --tail 50 | grep -i relay
```

#### Vérifier la file d'attente des courriels (devrait être vide quand tout fonctionne)

```bash
docker exec stargate-stalwart stalwart-cli -u http://localhost:8080 queue list
```

#### Envoyer un courriel de test et vérifier les logs

```bash
docker logs stargate-stalwart --tail 50
```

## Dépannage

### Les courriels ne quittent pas Exchange Online

- Vérifiez que la règle de transport est **activée** (elle est créée dans un état désactivé)
- Vérifiez les conditions de la règle - elle devrait s'appliquer aux destinataires "En dehors de l'organisation"
- Vérifiez que la validation du connecteur sortant a réussi
- Vérifiez la trace des messages Exchange dans le Centre d'administration pour l'état de livraison

### Boucles de courrier (messages dupliqués)

- Assurez-vous que la règle de transport a **l'exception** pour l'adresse IP de HIN Gateway
- Sans cette exception, les courriels de HIN Gateway arrivant dans Exchange sont redirigés vers HIN Gateway

### HIN Gateway n'accepte pas les courriels d'Exchange

- Vérifiez que le port 25 est ouvert sur le pare-feu du serveur HIN Gateway
- Vérifiez que l'enregistrement SPF inclut l'IP HIN Gateway
- Vérifiez les logs Stalwart: `docker logs stargate-stalwart`

### Exchange Online rejette les courriels de HIN Gateway

- Vérifiez que le connecteur entrant est configuré avec la bonne IP HIN Gateway
- Vérifiez que l'IP HIN Gateway n'a pas changé
- Vérifiez que le connecteur est activé (Statut: Activé)

### Erreurs de certificat TLS

HIN Gateway utilise TLS opportuniste avec un certificat auto-signé. Le connecteur sortant dans Exchange doit être configuré pour accepter "Tout certificat numérique, y compris les certificats auto-signés". Si vous voyez des erreurs liées à TLS:

- Vérifiez que le paramètre de sécurité du connecteur sortant autorise les certificats auto-signés
- Pour Exchange On-Premises, assurez-vous que le connecteur d'envoi ne nécessite pas TLS (`-RequireTLS $false`)

### La validation échoue lors de la création du connecteur

La validation du connecteur sortant nécessite:

- Le serveur HIN Gateway est en cours d'exécution et accepte les connexions sur le port 25
- L'adresse de courrier de validation est valide pour votre domaine
- Le chemin réseau entre Exchange Online et HIN Gateway est ouvert (pas de blocage par pare-feu)

---

## Référence rapide

| Composant | Emplacement Exchange Online | Objectif |
|-----------|--------------------------|---------|
| Connecteur sortant | Centre d'administration → Flux de courrier → Connecteurs | Acheminer les courriels sortants vers HIN Gateway |
| Connecteur entrant | Centre d'administration → Flux de courrier → Connecteurs | Accepter les courriels de HIN Gateway |
| Règle de transport | Centre d'administration → Flux de courrier → Règles | Déclencher le connecteur sortant pour les destinataires externes |
| Connecteur Send to MX | Centre d'administration → Flux de courrier → Connecteurs | Remettre au MX du destinataire les courriels qui reviennent de HIN Gateway |
| Règle outgoing_to_mx | Centre d'administration → Flux de courrier → Règles | Acheminer vers le connecteur Send to MX les courriels qui reviennent de HIN Gateway |

| Enregistrement DNS | Exemple | Objectif |
|------------|---------|---------|
| A | `mail IN A <HIN Gateway_IP>` | Pointer le nom d'hôte vers HIN Gateway |
| MX (HIN Gateway) | `@ IN MX 15 mail.<YOUR_DOMAIN>.` | Les courriels entrants frappent d'abord HIN Gateway |
| MX (Exchange) | `@ IN MX 20 <DOMAIN>.mail.protection.outlook.com.` | Secours / cible de livraison |
| SPF | `ip4:<HIN Gateway_IP>` et `ip4:<HIN_SEALER_IP>` ajoutés à l'enregistrement TXT existant | Autoriser HIN Gateway et le scelleur HIN à envoyer des courriels |

Pour la configuration DNS complète (y compris PTR, DMARC, DKIM et multi-domaines), consultez le [Guide de configuration DNS](DNS-setup.md).
