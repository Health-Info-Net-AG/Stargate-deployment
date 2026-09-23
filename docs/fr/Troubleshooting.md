# Dépannage et diagnostic

Guide structuré pour diagnostiquer une appliance Stargate depuis la ligne de commande : ce qu’il faut vérifier, où se trouvent les journaux et quelles actions de récupération sont sans risque.

!!! info "Où se trouvent les scripts"
    Les scripts utilitaires se trouvent dans le répertoire de déploiement, sous `scripts/`. Les commandes ci-dessous utilisent le **chemin complet des images de VM** : `/usr/share/stargate-deployment/docker-compose/scripts/`. Si vous avez effectué l’installation ailleurs, remplacez-le par votre propre répertoire d’installation (le dossier qui contient `docker-compose.yml` et `scripts/`).

    Les commandes `docker compose ...` doivent être exécutées **depuis le répertoire de déploiement** :

    ```bash
    cd /usr/share/stargate-deployment/docker-compose   # adjust to your install path
    ```

!!! info "Où se trouvent les données modifiables"
    L’arborescence `docker-compose/` ci-dessus (scripts, `docker-compose.yml`, modèles de configuration) est **en lecture seule à l’exécution**. Toutes les données modifiables se trouvent à la place sous **`/var/data`** : `.env`, `customer-config.sh`, `secrets/`, la configuration TLS, Keycloak et APISIX générée, les sauvegardes ainsi que les données propres à chaque service (`STARGATE_DATA_DIR` remplace cette racine à des fins de test). En particulier : la configuration et les secrets se trouvent sous `/var/data/vereign/`, les sauvegardes sous `/var/data/backups/` et le journal de mise à jour dans `/var/data/vereign/update.log`. Pour la description complète, voir [Configuration avancée Docker](Docker-advanced.md). Utilisez de préférence les scripts d’encapsulation (`./scripts/start.sh`, `./scripts/update.sh`, ...) plutôt qu’un simple `docker compose up -d`, qui ne prend pas en compte `/var/data/vereign/.env` de lui-même.

---

## 1. Commencez ici : le contrôle d’état

Une seule commande donne une vue d’ensemble de l’appliance :

=== "Rapide"

    ```bash
    /usr/share/stargate-deployment/docker-compose/scripts/health-check.sh
    ```

=== "Détaillé"

    ```bash
    /usr/share/stargate-deployment/docker-compose/scripts/health-check.sh -v
    ```

Elle indique un résultat réussi ou en échec pour : les **conteneurs** (en cours d’exécution / en bon état), les points de terminaison de **disponibilité** (liveness : smimekeys, policy, irisagent, mxengine), l’état de scellement de **Vault**, la connectivité **PostgreSQL** et les bases de données, **SeaweedFS**, le tunnel **WireGuard** et les handshakes avec les pairs, le MTA **Stalwart** (ports 25 / 10026), les points de terminaison des métriques **Prometheus**, ainsi que le **disque et la mémoire**.

!!! tip
    Exécutez d’abord cette commande. Une seule ligne `FAIL` vous oriente généralement directement vers la section concernée ci-dessous.

---

## 2. Où trouver les journaux

| Niveau | Commande | Ce qui est affiché |
| ------- | --------- | --------------- |
| Démarrage / première installation / démarrage automatique | `sudo journalctl -u stargate -n 200 --no-pager` | Le service systemd qui exécute `start.sh` au démarrage, ainsi que l’installation au premier démarrage |
| Exécutions de mise à jour | `cat /var/data/vereign/update.log` | Sortie du dernier `update.sh` déclenché depuis le tableau de bord ou l’hôte |
| Un seul service | `docker logs stargate-<service> --tail 100` | p. ex. `stargate-dashboard`, `stargate-mxengine`, `stargate-keycloak` |
| Suivre un service en direct | `docker logs -f stargate-mxengine` | Temps réel |
| Tous les conteneurs en direct | `docker ps -a --format '{{.Names}}' \| xargs -I{} sh -c 'docker logs --timestamps -f {} 2>&1 \| sed "s/^/[{}] /"'` | Journaux fusionnés, préfixés par le nom du conteneur |
| Visualiseur de journaux web | Dozzle à l’adresse `https://<SERVER_IP>:8190` (connexion Keycloak) | Parcourir les journaux de tous les conteneurs dans une interface web |

Pour transmettre les journaux au support HIN, utilisez le script d’envoi : il collecte les N dernières lignes de journal de **chaque** service (avec les informations sur l’hôte et les versions), les téléverse et affiche un lien à communiquer. Voir **[Fournir les journaux au support](Docker-advanced.md#fournir-les-logs-au-support)** :

```bash
/usr/share/stargate-deployment/docker-compose/scripts/send-logs-to-support.sh --tail 5000     # last 5000 lines from each service
# other options:  --since 1h   |   --until 5m   |   --all   (no argument = --tail 500)
```

L’envoi est limité à 20 MB ; sur une appliance très sollicitée, préférez donc `--tail`/`--since` à `--all`.

---

## 3. Conteneurs arrêtés ou qui redémarrent en boucle

```bash
docker compose ps -a --format 'table {{.Service}}\t{{.Status}}'
```

Consultez la colonne `Status` :

| Statut | Signification | Action |
| -------- | --------- | -------- |
| `Up ... (healthy)` | Fonctionne normalement | - |
| `Up ...` (sans état de santé) | En cours d’exécution ; aucun contrôle d’état défini | Consultez ses `docker logs` si vous soupçonnez un problème |
| `Restarting` | Redémarrages en boucle | `docker logs stargate-<svc>` : corrigez l’erreur d’origine (configuration, secret, dépendance) |
| `Exited (0)` | Initialisation ponctuelle terminée avec succès (p. ex. `*-init`, `vault-data-fixer`) | Normal |
| `Exited (1+)` | Échec | `docker logs stargate-<svc>` : les dernières lignes en indiquent la cause |
| `Created` | Jamais démarré, car une dépendance n’a pas démarré | Vérifiez de quoi il dépend (`depends_on`, généralement Postgres/Vault) et corrigez d’abord ce point |

Redémarrer un seul service (opération sûre et non destructive) :

```bash
docker compose up -d <service>          # recreate one service
docker compose restart <service>        # just restart it
```

!!! note "Ordre de démarrage"
    Les services attendent leurs dépendances (`depends_on` + contrôles d’état). Lors d’un redémarrage complet, de brèves lignes `connection refused` / `database system is starting up` pendant le démarrage de Postgres et de Vault sont **normales** et disparaissent en moins d’une minute.

---

## 4. Diagnostic par symptôme

### Le tableau de bord ou Keycloak ne se charge pas / connexion impossible

- Tous deux sont placés derrière Caddy : le **tableau de bord** sur `:443`, **Keycloak** sur `:8180`.
- Vérifiez toute la chaîne : `docker logs stargate-caddy`, `stargate-dashboard`, `stargate-keycloak`, `stargate-apisix`.
- Keycloak doit être **en bon état** (healthy) pour que le tableau de bord fonctionne : `docker compose ps keycloak`.
- Un avertissement TLS dans le navigateur est normal (certificat auto-signé) : acceptez-le et continuez.
- L’échec des redirections de connexion signifie généralement que l’URL publique ne correspond pas à l’adresse par laquelle vous accédez à la machine. Vérifiez que `KEYCLOAK_PUBLIC_URL` / `DASHBOARD_PUBLIC_URL` dans `.env` pointent vers l’adresse IP ou le nom d’hôte que vous utilisez réellement.

### Tunnel WireGuard indisponible / échec de l’émission des certificats

C’est le problème le plus fréquent : **l’émission des certificats échoue lorsque le tunnel est indisponible**. Rétablissez donc toujours le tunnel en premier.

```bash
/usr/share/stargate-deployment/docker-compose/scripts/health-check.sh -v      # shows WireGuard peer + handshake status
docker logs stargate-irisagent | grep -iE "handshake|peer|cert|wireguard"
```

- Vérifiez que le pare-feu autorise **`19818` (UDP *et* TCP)** en entrée et en sortie.
- Vérifiez que le pair est enregistré côté HIN (étape réalisée par le support). Vous fournissez pour cela la clé publique WG, `DEPLOYMENT_NAME`, `SERVER_STATIC_IP` et `WG_INTERFACE_PORT`.
- Dès que le tunnel affiche un handshake récent, relancez l’émission des certificats depuis le tableau de bord.

### Vault scellé ou échec de l’initialisation

```bash
docker compose exec vault vault status        # look for "Sealed: false"
docker logs stargate-vault-init
```

- Vault doit être **descellé** pour que smimekeys, mxengine et policy fonctionnent. Les clés se trouvent dans `/var/data/vereign/secrets/vault-keys.json`.
- Si `vault-init` s’est terminé avec un code différent de zéro, le fichier de clés est peut-être absent ou corrompu. Consultez ses journaux ; une nouvelle exécution de `/usr/share/stargate-deployment/docker-compose/scripts/init-vault.sh` tente à nouveau le descellement.

!!! danger "Ne supprimez pas `/var/data/vereign/secrets/vault-keys.json`"
    Perdre ce fichier, c’est perdre l’accès à tous les secrets enregistrés. Conservez-en une sauvegarde.

### Connectivité PostgreSQL / base de données

```bash
docker compose exec postgres pg_isready -U postgres
docker logs stargate-postgres --tail 50
```

- Un message temporaire `the database system is starting up (57P03)` juste après un redémarrage est normal : les services se reconnectent automatiquement.
- Des échecs d’authentification persistants signifient généralement que la valeur `POSTGRES_PASSWORD` dans `.env` ne correspond plus au volume de données. Consultez les remarques sur les mises à jour et les secrets, et évitez de modifier cette valeur à la main.

### Les e-mails ne circulent pas

- Les e-mails **entrants** arrivent sur **`:25`** (Stalwart). De nombreux fournisseurs cloud **bloquent le port 25** par défaut :

    ```bash
    nc -zv <this-server-ip> 25          # from an external host
    docker logs stargate-stalwart --tail 100
    ```

    Si le port `25` est bloqué, demandez une dérogation à votre fournisseur.
- Les e-mails **sortants et le scellement** passent par Stalwart → **mxengine** (`:8084` callback de scellement, SMTP `:1587`) : `docker logs stargate-mxengine`.
- Les **boucles de messagerie** se manifestent par un même message qui circule en boucle. Vérifiez que l’enregistrement MX de votre domaine ne renvoie pas vers l’adresse IP de cette appliance elle-même.
- Le routage attendu est décrit dans **[Configuration du relais de messagerie](Mail-relay-setup.md)** et **[Configuration DNS](DNS-setup.md)**.

### Échec d’une mise à jour

```bash
docker logs stargate-ops-agent --tail 40      # the update orchestrator
cat /var/data/vereign/update.log              # the update script output
```

- L’ops-agent extrait le tag de la version cible (dont le `docker-compose.yml` fixe les versions des images), puis exécute `update.sh` sur l’hôte.
- Une fois l’opération terminée, vérifiez que les versions ont été appliquées : `/usr/share/stargate-deployment/docker-compose/scripts/gather-app-versions.sh` (ou consultez les tags d’image dans `docker compose ps`).
- Si un service reste bloqué après une mise à jour, recréez-le avec `docker compose up -d <service>`.

**La mise à jour démarre, mais rien ne se passe (mise à jour depuis une version antérieure).** Si le journal de l’ops-agent s’arrête à `pulling deployment repo ...` et que la mise à jour n’avance plus, le dépôt sur la VM contient très probablement des **modifications locales sur un fichier suivi** (le plus souvent un `docker-compose.yml` modifié à la main). Le `git checkout` de l’ops-agent refuse alors de s’exécuter et la mise à jour reste bloquée. Réinitialisez de force le dépôt sur la dernière révision, puis relancez la mise à jour. Git est la source unique de vérité ; cette opération n’annule que les modifications locales apportées aux fichiers **suivis**. `customer-config.sh`, `.env` et `secrets/` se trouvent sous `/var/data/vereign/`, en dehors de la copie du dépôt, et sont toujours préservés :

```bash
cd /usr/share/stargate-deployment
git fetch origin
git checkout -f main
git reset --hard origin/main
cd docker-compose
/usr/share/stargate-deployment/docker-compose/scripts/update.sh
```

`update.sh` régénère `.env`, télécharge les images et recrée les services concernés : vous n’avez **pas** besoin de redémarrer Stargate manuellement. Une fois l’opération terminée, relancez la mise à jour depuis le tableau de bord ; elle se déroulera alors normalement.

!!! warning
    N’utilisez pas `git pull` ici. Sur une copie de travail comportant des modifications locales, cette commande s’interrompt avec le message « local changes would be overwritten », ce qui oblige à passer par un `git stash`, un conflit de fusion ou une récupération manuelle. La séquence `git checkout -f` + `git reset --hard` ci-dessus évite entièrement ce détour : c’est la méthode sûre et reproductible pour mettre le dépôt à jour.

### Dozzle (visualiseur de journaux) inaccessible

- L’URL est `https://<SERVER_IP>:8190` ; elle exige une **connexion Keycloak** (même realm que le tableau de bord) via oauth2-proxy.
- Dozzle ne s’exécute que si `DOZZLE_ENABLED="true"`. Vérification : `docker compose ps dozzle oauth2-proxy`.
- Assurez-vous que le pare-feu autorise **`:8190`** en entrée. Voir **[Surveillance et journaux](Monitoring.md)**.

### Intégration : la saisie du code d’activation renvoie une erreur

Si le code d’activation est refusé, vérifiez dans l’ordre :

- **Code erroné** : il n’a pas été copié en entier (copier-coller tronqué, espace en trop ou caractère manquant). Copiez à nouveau le code complet et saisissez-le une nouvelle fois.
- **Code déjà utilisé** : il a déjà été consommé lors d’une intégration précédente. Demandez un nouveau code.
- **WireGuard / connectivité vers HIN** : le tunnel `irisagent` n’est pas établi, le code ne peut donc pas être validé auprès de HIN. Voir *Tunnel WireGuard indisponible* ci-dessus (`/usr/share/stargate-deployment/docker-compose/scripts/health-check.sh -v`, `docker logs stargate-irisagent`).
- **Aucun domaine associé à l’enregistrement** : aucun domaine n’est associé à l’enregistrement HIN du client, il n’y a donc rien à activer. Ce point se règle du côté de HIN.

### Intégration : code d’activation accepté, mais aucun domaine n’est affiché

**Cause la plus probable : le tunnel WireGuard n’est pas établi**, généralement à cause d’une **adresse IP publique erronée** ou d’un **port non ouvert dans le pare-feu**. Sans le tunnel, l’appliance ne peut pas récupérer la liste des domaines auprès de HIN.

- Vérifiez que `SERVER_STATIC_IP` dans `customer-config.sh` correspond à l’adresse IP publique réelle.
- Vérifiez que **`19818` (UDP *et* TCP)** est ouvert en entrée et en sortie.
- Vérifiez que le pair est enregistré côté HIN pour cette adresse IP (étape réalisée par le support).
- `docker logs stargate-irisagent` doit afficher un handshake récent ; sinon, rétablissez d’abord le tunnel (voir *Tunnel WireGuard indisponible* ci-dessus).

### Modifier l’adresse IP du serveur (configuration initiale uniquement)

Si l’adresse IP du serveur était erronée ou non définie au premier démarrage, réinitialisez proprement puis réinstallez :

```bash
/usr/share/stargate-deployment/docker-compose/scripts/purge.sh                 # destroys ALL data - see warning below
nano /var/data/vereign/customer-config.sh    # set SERVER_STATIC_IP=<NEW IP>
/usr/share/stargate-deployment/docker-compose/scripts/install.sh
```

Le certificat TLS et plusieurs URL de services sont dérivés de l’adresse IP au premier démarrage ; une purge suivie d’une réinstallation les régénère donc pour la nouvelle adresse.

!!! danger "Uniquement avant l’intégration"
    `purge.sh` **supprime définitivement toutes les données** : bases de données, Vault et clés S/MIME. Cette opération n’est sûre **que sur une appliance neuve, pas encore intégrée**. **N’exécutez jamais `purge.sh` pour changer l’adresse IP d’une passerelle en production ou déjà intégrée** : cela entraîne une perte de données et des e-mails qui ne peuvent plus être déchiffrés. Pour un changement d’adresse IP en production, contactez le support.

---

## 5. Stockage et disque

```bash
df -h /                              # is the disk full?
docker system df                     # space used by images / containers / volumes
du -sh /var/lib/docker/volumes/*     # per-volume usage (Postgres, SeaweedFS, Loki, ...)
```

- Les journaux des conteneurs sont plafonnés (json-file, 100 MB × 5 par conteneur) et ne devraient donc pas remplir le disque, contrairement aux images et aux volumes.
- Pour libérer de l’espace sans risque : `docker image prune -af` (supprime uniquement les images inutilisées). Évitez `docker system prune --volumes`, qui supprime les volumes de données.
- Le stockage objet est assuré par **SeaweedFS** (`stargate-seaweedfs`) : `docker logs stargate-seaweedfs --tail 50`.

---

## 6. Ressources de la VM

```bash
free -h                              # memory (min 8 GB)
nproc                                # CPUs (min 4)
docker stats --no-stream             # per-container CPU/RAM
uptime                               # load average
```

Les métriques de l’hôte sont également exportées pour Prometheus sur **`:9100/metrics`** (voir [Surveillance](Monitoring.md#metriques-prometheus)). Si la machine utilise massivement le swap ou tourne à pleine charge, attendez-vous à des contrôles d’état instables et à des mises à jour lentes.

---

## 7. Réseau et ports

Contrôle rapide de l’accessibilité des principaux ports entrants :

```bash
for p in 25 443 8180 8190 19818; do nc -zv <this-server-ip> $p; done
```

| Port | Service | Sens |
| ------ | --------- | ----------- |
| `25` | Stalwart SMTP (e-mails entrants) | entrant |
| `443` | Tableau de bord (HTTPS) | entrant |
| `8180` | Keycloak | entrant |
| `8190` | Dozzle (facultatif) | entrant |
| `19818` | WireGuard (UDP **et** TCP) | entrant/sortant |

Un accès sortant est nécessaire vers le registre de conteneurs, l’autorité de certification S/MIME (via le tunnel WireGuard) et toute instance Loki distante que vous avez configurée. Le tableau complet des ports figure sur la **[page d’accueil](index.md)** et dans l’**[Aperçu des applications](Applications.md)**.

---

## 8. Actions de récupération

De la moins à la plus perturbatrice :

```bash
docker compose up -d <service>       # recreate one stuck service
sudo systemctl restart stargate      # restart the whole stack (via start.sh)
/usr/share/stargate-deployment/docker-compose/scripts/stop.sh  &&  /usr/share/stargate-deployment/docker-compose/scripts/start.sh
```

!!! warning "Sauvegardes et récupération destructive"
    `/usr/share/stargate-deployment/docker-compose/scripts/backup.sh` et `/usr/share/stargate-deployment/docker-compose/scripts/restore.sh` assurent la sauvegarde et la restauration des données. `/usr/share/stargate-deployment/docker-compose/scripts/purge.sh` **supprime toutes les données** (bases de données, Vault, stockage) en vue d’une réinstallation propre : à n’utiliser qu’en dernier recours et uniquement avec une sauvegarde à jour. Détails : [Configuration avancée Docker](Docker-advanced.md).

---

## 9. Quand contacter le support

Si le contrôle d’état signale toujours des échecs après les étapes ci-dessus, ouvrez un ticket via **[Support / Contactez-nous](Support.md)** en joignant :

- La **version de l’appliance** (`/usr/share/stargate-deployment/docker-compose/scripts/gather-app-versions.sh`) et le **nom du client**.
- La **sortie du contrôle d’état** (`/usr/share/stargate-deployment/docker-compose/scripts/health-check.sh -v`).
- Le lien vers le **lot de journaux** généré par `/usr/share/stargate-deployment/docker-compose/scripts/send-logs-to-support.sh` (voir [Fournir les journaux au support](Docker-advanced.md#fournir-les-logs-au-support)).
- Ce que vous faisiez au moment de la panne, ainsi que d’éventuelles captures d’écran.

## Mettre à jour une instance Verimesh

Les instructions suivantes décrivent la mise à jour d’une instance Verimesh de la version v0.5.1 vers la version v0.5.3.

*Remarque :* vous devez vous connecter à la VM avec le compte administrateur Linux.

### Étapes de mise à jour

1. Modifiez le fichier `.env` et définissez la version de l’ops-agent sur v0.0.3.
2. Modifiez la configuration client et définissez-y également la version de l’ops-agent sur v0.0.3.
3. Passez sur la branche main : `git checkout main`
4. Récupérez les dernières modifications : `git pull`
5. Mettez à jour le conteneur ops-agent : `docker compose up -d ops-agent`
6. Connectez-vous au tableau de bord.
7. Ouvrez Settings.
8. Dans la section Update, en bas de la page, saisissez la version cible (v0.5.3) et lancez la mise à jour.

## Configurer Keycloak après la mise à jour

Remarque : ces instructions s’appliquent si vous utilisiez l’image de VM v0.5.1 et avez ensuite effectué une mise à jour vers une version plus récente.

Depuis la dernière mise à jour de Keycloak, une modification incompatible (breaking change) redirige de manière inattendue les utilisateurs authentifiés vers la page de connexion lorsqu’ils accèdent à certaines routes de l’application (p. ex. Peers, Peer Certificates).

Pour corriger ce problème, la configuration manuelle suivante doit être effectuée dans l’*interface de Keycloak*.

### Étapes de résolution

1. Ouvrez Keycloak dans votre navigateur à l’adresse `https://<VM IP address>:8180/admin/master/console/`
    - Le **port `:8180` est indispensable** : Keycloak est servi sur le port 8180. Si vous ouvrez l’adresse IP sans port, vous arrivez sur le tableau de bord (`:443`), qui vous redirige vers la connexion du realm **stargate**, dans lequel l’utilisateur admin n’existe pas (c’est la cause habituelle des messages « invalid username or password » ou « wrong realm » à cette étape).
    - Connectez-vous au realm **master** (le chemin `/admin/master/console/` le sélectionne) avec le nom d’utilisateur `admin` (la valeur de `KEYCLOAK_ADMIN_USER`, en minuscules) et la valeur de `KEYCLOAK_ADMIN_PASSWORD` figurant dans le fichier `/var/data/vereign/.env` de la machine (à lire depuis la console Linux).

2. Dans la console d’administration, passez du realm **master** au realm **stargate** à l’aide du sélecteur de realm (en haut à gauche).
3. Ouvrez Clients → dashboard.
4. Ouvrez l’onglet Client scopes → cliquez sur dashboard-dedicated.
5. Sélectionnez Configure a new mapper → Audience.
6. Définissez les paramètres suivants :
    - Name : apisix-audience
    - Included client audience : apisix (à sélectionner dans la liste déroulante)
    - Included custom audience : (laisser vide)
    - Add to access token : On
    - Add to token introspection : On
    - Add to ID token / lightweight token : Off

7. Cliquez sur Save.

 <br> ![keycloak-console](assets/troubleshooting/keycloak-update.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }


# Réinitialiser le mot de passe d’un utilisateur Stargate dans Keycloak

Suivez les étapes ci-dessous pour réinitialiser le mot de passe d’un utilisateur Stargate via la console d’administration Keycloak.

1. **Se connecter à la VM HIN Gateway**
    - Ouvrez la console de la VM ou connectez-vous à la VM HIN Gateway via SSH.

2. **Récupérer les identifiants de l’administrateur Keycloak**
    - Ouvrez le fichier `/var/data/vereign/.env`.
    - Repérez les variables suivantes :
        - `KEYCLOAK_ADMIN_USER`
        - `KEYCLOAK_ADMIN_PASSWORD`

3. **Ouvrir la console d’administration Keycloak**
    - Dans un navigateur, accédez à l’adresse suivante : `http://<VM-IP>:8180/admin/master/console`
    - Remplacez `<VM-IP>` par l’adresse IP de la VM HIN Gateway.

4. **Se connecter à Keycloak**
    - Saisissez le nom d’utilisateur et le mot de passe administrateur récupérés dans le fichier `.env`.
    - Conservez le même mot de passe administrateur. Si vous le modifiez malgré tout, vous devez conserver le nouveau mot de passe en lieu sûr.

5. **Sélectionner le realm Stargate**
    - Dans le sélecteur de realm de la console d’administration Keycloak, sélectionnez **Stargate**.

6. **Trouver l’utilisateur**
    - Ouvrez **Users**.
    - Recherchez et sélectionnez l’utilisateur Stargate dont le mot de passe doit être réinitialisé.

7. **Réinitialiser le mot de passe de l’utilisateur**
    - Sélectionnez l’option de réinitialisation du mot de passe de l’utilisateur.
    - Saisissez le nouveau mot de passe et confirmez la modification.

**Ne modifiez pas et ne réinitialisez pas le mot de passe de l’administrateur Keycloak dans le cadre de cette procédure.**
Toute modification du mot de passe administrateur peut bloquer Keycloak au point que plus personne ne puisse y accéder.


# Demander un code d’activation

Pour installer ou réinstaller une instance HIN Gateway, vous avez besoin d’un code d’activation, que le support HIN peut vous fournir.


!!! warning "La réinitialisation du code d’activation coupe la connexion avec le pair"
    La réinitialisation du code d’activation d’une instance active supprime la connexion du pair WireGuard du client.

    Si vous demandez cette réinitialisation pour la mauvaise instance client, la connexion de cette instance active sera supprimée et interrompue. Avant de demander une réinitialisation, vérifiez soigneusement l’instance concernée et confirmez tous les domaines qui y sont hébergés.
