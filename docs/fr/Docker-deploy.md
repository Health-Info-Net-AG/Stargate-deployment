# Déploiement Docker de Stargate

## Prérequis

**Exigences du serveur :**

Veuillez vous référer aux [Exigences recommandées](./index.md#exigences-du-serveur)

* Docker sera installé automatiquement s'il manque
* Assurez-vous qu'il y a une connexion Internet sur la machine où vous installez les services Stargate
* Assurez-vous que le trafic est correctement configuré pour atteindre l'instance Stargate

## Étape 1: Configurer les paramètres client

!!! tip
    Vous pouvez cloner notre dépôt avec toutes les données et exemples de configurations à l'intérieur avec la commande:

    ```bash
    git clone https://github.com/Health-Info-Net-AG/Stargate-deployment.git
    ```

    Si vous n'avez pas `git` installé, vous pouvez toujours obtenir une archive avec tous les fichiers à l'intérieur. Téléchargez-la via le lien suivant. [Télécharger en ZIP](https://github.com/Health-Info-Net-AG/Stargate-deployment/archive/refs/heads/main.zip){ .md-button style="position:relative;left:50%;transform:translate(-50%,0%);" }

Le script d'installation crée automatiquement `customer-config.sh` à partir du modèle fourni lors du premier lancement, de sorte qu'une nouvelle installation ne nécessite **aucune configuration manuelle**. Si vous préférez le créer vous-même, copiez le modèle:

```bash
cp customer-config-prod.example.sh customer-config.sh
```

Vous n'avez **pas** besoin de le modifier - chaque valeur est soit détectée automatiquement, soit configurée ultérieurement via le tableau de bord:

| Paramètre | Comment il est défini |
|---------|---------------|
| `SERVER_STATIC_IP` | Détecté automatiquement à partir de l'interface réseau principale du serveur. |
| `CUSTOMER_NAME` | Par défaut, le nom d'hôte du système. |
| `DEPLOYMENT_NAME` | Dérivé de `CUSTOMER_NAME` (utilisé dans les étiquettes de logs et le nom d'hôte Alloy). |
| Mots de passe et clés (`POSTGRES_PASSWORD`, `S3_SECRET_KEY`, `VAULT_TOKEN`, `WG_PRIVATE_KEY`) | Générés de manière sécurisée au premier lancement et réécrits dans `customer-config.sh`. |

Les domaines de courrier, le nom d'hôte de messagerie, les certificats S/MIME et les pairs WireGuard sont tous configurés à l'exécution via le tableau de bord une fois la pile démarrée - ils ne font pas partie de `customer-config.sh`.

!!! note "Derrière un NAT ou une IP flottante ?"
    La détection automatique utilise l'IP de l'interface principale du serveur. Si votre serveur est joignable via une *autre* IP publique ou flottante (fréquent avec le NAT), définissez `SERVER_STATIC_IP` sur cette IP publique dans `customer-config.sh` avant l'installation, afin que les URL du tableau de bord et de connexion Keycloak pointent vers l'adresse joignable. Sinon, laissez-le vide.

**Paramètres auto-dérivés — laissez vide sauf si vous devez les remplacer :**

| Paramètre | Dérivé de | Défaut |
|---------|-------------|---------|
| `MXENGINE_PUBLIC_ADDRESS` | `SERVER_STATIC_IP` | `http://<SERVER_STATIC_IP>:8084` |

**Paramètres du certificat S/MIME :**

| Paramètre | Description | Défaut |
|---------|-------------|---------|
| `CERT_CA_IRISAGENT_DOMAIN` | Domaine CA pour l'émission de certificats via le tunnel WireGuard | `hintest.ch` |

!!! note
    **La configuration du pair WireGuard** est effectuée à l'exécution via le tableau de bord (page `/installation`). Les détails du pair sont configurés par déploiement après le démarrage de la pile - ils ne font pas partie de `customer-config.sh`.

**Paramètres locaux WireGuard (généralement laissés par défaut) :**

| Paramètre | Défaut | Description |
|---------|---------|-------------|
| `WG_PRIVATE_KEY` | *(auto-généré)* | Généré par IRISAgent lors de la première exécution, puis sauvegardé dans `customer-config.sh` |
| `WG_LOCAL_IP` | `SERVER_STATIC_IP` | Auto-dérivé. Remplacez uniquement si vous avez besoin d'une adresse de tunnel différente. |
| `WG_INTERFACE_PORT` | `19818` | Port du tunnel WireGuard (TCP et UDP sont exposés) |
| `WG_TRANSPORT_MODE` | `tcp` | Protocole de transport: `tcp` (par défaut, fonctionne à travers la plupart des pare-feu) ou `udp` |

**Paramètres optionnels (ont des valeurs par défaut raisonnables) :**

| Paramètre | Défaut | Description |
|---------|-------------|---------|
| `POSTGRES_PASSWORD` | *(auto-généré)* | Mot de passe aléatoire de 24 caractères auto-généré si vide |
| `S3_SECRET_KEY` | *(auto-généré)* | Clé secrète S3 pour le stockage d'objets |
| `OUTBOUND_SEALER_MX_DOMAIN` | `hintest.ch` | Domaine MX du scelleur pour la livraison des sceaux sortants |
| `POLICY_SYNC_REPO_URL` | GitHub HIN Stargate policies | URL du dépôt Git pour la synchronisation des politiques OPA/Rego |
| `LOKI_URL` | *(non défini)* | Point de terminaison Loki pour l'envoi centralisé des logs (ex. `https://loki.example.com`) |

**Auto-générés (ne pas définir manuellement) :**

* `VAULT_TOKEN` — Généré par Vault lors de la première initialisation, sauvegardé dans `customer-config.sh`
* `WG_PRIVATE_KEY` — Généré par IRISAgent lors de la première exécution, sauvegardé dans `customer-config.sh`

## Étape 2: Déployer sur un serveur

!!! tip
    Vous pouvez cloner notre dépôt avec toutes les données et exemples de configurations à l'intérieur avec la commande:

    ```bash
    git clone https://github.com/Health-Info-Net-AG/Stargate-deployment.git && \
      cd Stargate-deployment-main
    ```

    Si vous n'avez pas `git` installé, vous pouvez toujours obtenir une archive avec tous les fichiers à l'intérieur et l'extraire:

    ```bash 
    wget https://github.com/Health-Info-Net-AG/Stargate-deployment/archive/refs/heads/main.zip && \
      unzip main.zip && \
      rm main.zip && \
      cd Stargate-deployment-main
    ```

Copiez manuellement les fichiers sur le serveur

```bash
scp -r docker-compose/* votre-serveur:/chemin/vers/stargate/
```

SSH vers le serveur

```bash
ssh votre-serveur
cd /chemin/vers/stargate
```

Créez la configuration client à partir du modèle et remplissez les paramètres requis ([voir Étape 1](#etape-1-configurer-les-parametres-client)

```bash
cp customer-config-prod.example.sh customer-config.sh
nano customer-config.sh   # Remplir les paramètres requis (voir Étape 1)
```

Exécutez l'installation

```bash
chmod +x scripts/*.sh
./scripts/install.sh
```

## Étape 3: Ce que fait l'installation

Le script d'installation (`install.sh`) effectue les étapes suivantes:

1. **Vérifier les dépendances** — Détecte Docker, Docker Compose et `jq`. S'ils manquent, les installe automatiquement (prend en charge Ubuntu/Debian, RHEL/AlmaLinux/Rocky).
2. **Charger et valider** `customer-config.sh` — Vérifie les champs requis (`SERVER_STATIC_IP`, `CUSTOMER_NAME`, `DEPLOYMENT_NAME`). Dérive automatiquement les champs optionnels (URL MXEngine, etc.).
3. **Générer `.env`** à partir de la configuration client — Génère automatiquement les mots de passe s'ils ne sont pas définis.
4. **Démarrer tous les services** via Docker Compose (infrastructure + applications).
5. **Initialiser Vault** — Le conteneur `vault-init` initialise, descelle et crée les montages de secrets KV-v2. Écrit éventuellement la clé privée WireGuard dans Vault.
6. **Sauvegarder les clés Vault** dans `secrets/vault-keys.json` et mettre à jour `.env` avec le jeton root. Le jeton est également sauvegardé dans `customer-config.sh` pour la persistance à travers les recréations de VM.
7. **Redémarrer les services d'application** pour prendre en compte le jeton Vault.
8. **Sauvegarder la clé privée WireGuard** dans `customer-config.sh` — extraite de Vault après que IRISAgent l'a générée.
9. **Configurer la tâche cron de sauvegarde quotidienne** (s'exécute à 2h00).

Une fois l'installation terminée, la pile fonctionne mais aucun domaine de courrier, certificat S/MIME ou pair WireGuard n'est encore configuré. Continuez avec [Étape 4: Intégration via le tableau de bord](#etape-4-integration-via-le-tableau-de-bord).

## Étape 4: Intégration via le tableau de bord

Après l'installation, terminez l'intégration via le tableau de bord à l'adresse `https://<SERVER_STATIC_IP>`. Le tableau de bord vous guide à travers trois pages dans l'ordre:

### `/installation` — Configuration du pair WireGuard

Effectue la négociation nonce/HIN pour établir une connexion pair WireGuard, et sauvegarde la configuration WireGuard résultante dans le service IRISAgent.

### `/onboarding` — Certificat S/MIME

Génère la clé de signature S/MIME et le CSR via le service smimekeys et soumet le CSR à la CA via le tunnel WireGuard maintenant établi. (Ceci remplace l'ancien flux de certificats basé sur des scripts.)

### `/mail` — Domaines de courrier et configuration du relais

Soumet le nom d'hôte et la liste des domaines de relais au service `mtaconf` via son API REST. Le démon applique la configuration à Stalwart sans redémarrer le conteneur.

!!! tip "Ajouter ou modifier des domaines ultérieurement"
    Rouvrez la page `/mail` dans le tableau de bord, modifiez la liste des domaines et soumettez. Le démon applique la modification à l'exécution - pas d'invocation de script, pas de modification de `.env`, pas de redémarrage de service nécessaire.

## Étape 5: Enregistrement du pair WireGuard

La soumission du CSR S/MIME sur `/onboarding` échouera si votre instance Stargate n'est pas encore enregistrée en tant que pair WireGuard côté CA HIN. C'est le problème le plus courant lors de la configuration initiale.

La page `/installation` du tableau de bord gère l'enregistrement automatique du pair WireGuard via la négociation nonce/HIN. Si l'enregistrement automatique échoue, l'enregistrement manuel peut être effectué en fournissant les valeurs suivantes à HIN:

1. **Clé publique WireGuard** — extraire des logs irisagent:

   ```bash
   docker compose logs irisagent | grep "public key"
   ```

2. **`DEPLOYMENT_NAME`** — depuis votre `customer-config.sh`
3. **`SERVER_STATIC_IP`** — l'IP publique de votre serveur Stargate
4. **`WG_INTERFACE_PORT`** — seulement si vous l'avez modifié par rapport au défaut `19818`

**Une fois l'enregistrement du pair confirmé :**

Réexécutez la page `/onboarding` dans le tableau de bord pour régénérer le CSR et le soumettre via le tunnel maintenant actif.

**Pour vérifier le tunnel avant de demander le certificat :**

Redémarrez uniquement irisagent

```bash
docker compose restart irisagent
```

Vérifiez la négociation WireGuard réussie

```bash
docker compose logs irisagent 2>&1 | grep -i "handshake\|peer"
```

!!! tip
    Vérifiez votre pare-feu: Le port `19818/TCP` doit être ouvert **dans les deux sens, entrant et sortant** sur le serveur Stargate.

## Étape 6: Recommandations post-intégration

Une fois le certificat émis et les courriels circulant, deux éléments de configuration sont fortement recommandés pour tout déploiement en production. Les ignorer ne casse pas le chiffrement, mais dégradera votre réputation d'expéditeur, provoquera des avertissements "nous ne pouvons pas vérifier l'expéditeur" dans Outlook/Gmail, et peut éventuellement conduire à un blocage des courriels sortants.

### Étape 6.1 SPF / DKIM / DMARC pour les domaines expéditeurs

Stargate envoie des courriels depuis sa propre IP publique au nom de vos utilisateurs. Sans enregistrements d'authentification DNS appropriés, les destinataires verront des avertissements "nous ne pouvons pas vérifier cet expéditeur" et pourront rejeter le courrier.

Pour des instructions complètes sur la configuration des enregistrements SPF, DKIM, DMARC et PTR, consultez le [Guide de configuration DNS](DNS-setup.md#enregistrements-recommandes).

Au minimum, pour chaque domaine que vous acheminez via Stargate:

* **SPF**: ajoutez `ip4:<STARGATE_IP>` à l'enregistrement TXT du domaine
* **DMARC**: publiez `v=DMARC1; p=none` à `_dmarc.<VOTRE_DOMAINE>`
* **PTR**: définissez le DNS inversé pour l'IP Stargate pour qu'il corresponde à `MAIL_HOSTNAME`

### Étape 6.2 Relayer les courriels sortants via votre plateforme de courrier (recommandé pour M365 / Exchange Online)

Par défaut, après que Stargate a signé/chiffré un courrier sortant, il le livre directement au MX du destinataire. Cela fonctionne, mais l'IP de connexion est l'IP de votre Stargate - et à moins que cette IP ait des années de bonne réputation, elle peut finir sur des listes noires tierces (ex. Barracuda, Abusix), provoquant des échecs de livraison intermittents.

Le modèle recommandé est d'**envoyer le courrier signé via votre locataire M365 / Exchange** afin que le dernier saut vers l'Internet soit l'infrastructure bien réputée de Microsoft. Stargate signe et vérifie toujours chaque message par politique ; seul le dernier saut change. Cela reflète le modèle de connecteur "Envoyer à MX" de l'ancien HIN MGW.

#### Côté Stargate — relais par domaine

Configurez le relais par domaine via la page `/mail` du tableau de bord. Chaque domaine peut être mappé à son propre point de terminaison entrant M365 / Exchange ; le tableau de bord envoie le mappage à l'API REST de mtaconf et Stalwart est reconfiguré à l'exécution.

Après que mxengine a signé le courrier, Stalwart le renverra à votre locataire sur le port 25 avec TLS au lieu de le livrer directement au MX du destinataire. Voir `Exchange-integration.md` pour la syntaxe complète par domaine.

#### Côté M365 / Exchange Online

Vous recréez essentiellement le même ensemble de connecteurs + règles de transport que l'ancien HIN MGW (le manuel O365 original de HIN MGW est la référence - les mêmes cinq règles s'appliquent). Le minimum est:

1. **Connecteur entrant** - accepte les courriels de Stargate, identifié par le certificat TLS (le sujet du certificat doit correspondre à un domaine accepté dans votre locataire). Un certificat auto-signé sur Stargate sera rejeté par ce connecteur - utilisez un certificat valide émis par une AC (Let's Encrypt convient).
2. **Connecteur sortant "Envoyer à MX"** - livre au MX du destinataire, activé uniquement par règle de transport.
3. **Règle de transport `set_header`** - étiquette les courriels sortants avec un en-tête comme `outgoing: outgoing_<domaine>` avant qu'ils ne quittent O365 la première fois, afin que le voyage de retour puisse le reconnaître.
4. **Règle de transport `outgoing_to_mx`** - correspond à l'en-tête `outgoing_<domaine>` sur les courriels revenant de Stargate et les achemine via le connecteur "Envoyer à MX".
5. **Règle de transport `mgw_bypass_antispam`** - contourne le filtrage anti-spam sur les courriels revenant de Stargate.

mxengine ne supprime pas les en-têtes arbitraires, donc l'étiquette `outgoing_<domaine>` définie par `set_header` survit à l'aller-retour et déclenche `outgoing_to_mx` correctement.

!!! info "Pourquoi ce modèle est important"
    Avec la configuration de relais de retour, l'expéditeur public vers l'Internet est Microsoft. Combiné avec SPF/DKIM/DMARC corrects (section 6.1), les destinataires voient une IP Microsoft avec `spf=pass` et `dkim=pass` alignés sur votre domaine - ce qui est le profil de réputation le plus propre que vous puissiez leur donner.

Voir `Exchange-integration.md` pour des instructions étape par étape complètes, y compris des captures d'écran.

## Démarrages ultérieurs (après redémarrage)

L'installateur active une unité systemd `stargate`, donc la pile démarre automatiquement au démarrage. Pour la démarrer manuellement:

```bash
sudo systemctl start stargate
```

Cela exécute `start.sh`, qui:

1. Démarre les services d'infrastructure
2. Descelle Vault en utilisant les clés stockées
3. Démarre les services d'application

(`./scripts/start.sh` fonctionne toujours directement si vous préférez.)

## Arrêter les services

```bash
sudo systemctl stop stargate
```

(ou `./scripts/stop.sh` directement)

Cela arrête les conteneurs mais préserve toutes les données.

## Persistance des données

Toutes les données sont stockées dans des volumes Docker et **persistent à travers les redémarrages**.

| Service | Volume | Données |
|---------|--------|------|
| PostgreSQL | `postgres_data` | Toutes les bases de données (smimekeys, policy, irisagent, mxengine) |
| Vault | `vault_data` | Clés de chiffrement, secrets, clés S/MIME |
| SeaweedFS | `seaweedfs_data` | Stockage d'objets (messages, pièces jointes) |
| Stalwart | `stalwart_data` | État du serveur de courrier |

### Opérations sûres (données préservées)

Arrêter et démarrer:

```bash
sudo systemctl stop stargate
sudo systemctl start stargate
```

Ou en utilisant les scripts directement:

```bash
./scripts/stop.sh
./scripts/start.sh
```

!!! warning "N'utilisez pas les commandes `docker compose` directement"
    Utilisez toujours `systemctl` ou les scripts fournis (`start.sh` / `stop.sh`) pour gérer le déploiement. L'exécution directe de `docker compose up`, `docker compose down` ou `docker compose restart` **ne descellera pas Vault**, laissant les services dépendants incapables de démarrer. Le script `start.sh` gère la procédure de descellage de Vault automatiquement.

### Comportement de scellement de Vault

**Vault se scelle** lorsque son conteneur redémarre. C'est une fonctionnalité de sécurité.

Le script `start.sh` (et le service systemd) descellent automatiquement Vault en utilisant les clés stockées dans `secrets/vault-keys.json`. C'est pourquoi vous devez toujours utiliser les scripts fournis ou le service systemd pour gérer la pile.

## :warning: Opérations destructrices (données supprimées)

!!! warning
    Ces commandes **SUPPRIMENT TOUTES LES DONNÉES** - à utiliser avec prudence !

    Vous ne pouvez restaurer les données que si vous effectuez [des opérations de sauvegarde](./Docker-advanced.md#sauvegarde-manuelle) au préalable et que vous sauvegardez la sauvegarde dans un endroit sûr.

!!! danger
    Tout supprimer (volumes, secrets, config)

    ```bash
    ./scripts/purge.sh
    ```

    Ou supprimer manuellement les volumes. Le drapeau -v supprime les volumes

    ```bash
    docker compose down -v
    ```

## Référence des scripts

| Script | Objectif |
|--------|--------|
| `install.sh` | Première installation (Docker, Vault). La configuration du domaine/certificat/pair se fait ensuite dans le tableau de bord. |
| `update.sh` | Mettre à jour les images des services (préserve le jeton Vault, recrée les conteneurs) |
| `start.sh` | Démarrer les services et desceller Vault |
| `stop.sh` | Arrêter les conteneurs (données préservées) |
| `backup.sh` | Sauvegarde complète (base de données, clés Vault, configuration, certificats) |
| `restore.sh` | Restaurer à partir d'une archive de sauvegarde (fonctionne sur une nouvelle machine) |
| `purge.sh` | :warning: Supprimer TOUTES les données (nécessite confirmation) |
| `health-check.sh` | Contrôle de santé complet de tous les services (code de sortie 0 = sain, 1 = échecs) |
| `init-vault.sh` | Initialisation Vault (utilisé par le conteneur `vault-init`, ne pas appeler directement) |
| `init-keycloak.sh` | Configuration du mot de passe administrateur Keycloak (utilisé par le conteneur `keycloak-init`, ne pas appeler directement) |
| `gather-app-versions.sh` | Collecte les versions des applications depuis les points de terminaison `/liveness` pour node-exporter (s'exécute dans le conteneur `version-collector`) |

## Fichiers de configuration

| Fichier | Objectif |
|------|---------|
| `customer-config-prod.example.sh` | Modèle pour les paramètres client (copier vers `customer-config.sh`) |
| `customer-config.sh` | Paramètres spécifiques au client (créés à partir du modèle, remplir avant l'installation) |
| `.env` | Fichier d'environnement généré (créé par `install.sh`) |
| `secrets/vault-keys.json` | Clés de descellage Vault et jeton root (sauvegarder en toute sécurité !) |
| `secrets/signing-key.csr` | CSR généré pour le certificat S/MIME |

## Support

!!! tip "Support"

    Pour toute question ou problème lié au déploiement et au fonctionnement de l'appliance Stargate, veuillez contacter le support HIN.

    Veuillez inclure des informations pertinentes telles que le nom du client, la version de l'appliance, et des captures d'écran/[logs](./Docker-advanced.md#fournir-les-logs-au-support) le cas échéant, pour nous aider à traiter votre demande efficacement.
