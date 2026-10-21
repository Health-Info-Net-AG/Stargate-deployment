# Dépannage et diagnostic

Guide structuré pour diagnostiquer une appliance Stargate depuis la ligne de commande : ce qu’il faut vérifier, où se trouvent les journaux et quelles actions de récupération sont sans risque.

!!! info "Où se trouvent les scripts"
    Les scripts utilitaires se trouvent dans le répertoire de déploiement, sous `scripts/`. Les commandes ci-dessous utilisent le **chemin complet des images de VM** : `/usr/share/stargate-deployment/docker-compose/scripts/`. Si vous avez effectué l’installation ailleurs, remplacez-le par votre propre répertoire d’installation (le dossier qui contient `docker-compose.yml` et `scripts/`).

    Les commandes `docker compose ...` doivent être exécutées **depuis le répertoire de déploiement** :

    ```bash
    cd /usr/share/stargate-deployment/docker-compose   # adjust to your install path
    ```

!!! info "Où se trouvent les données modifiables"
    L’arborescence `docker-compose/` ci-dessus (scripts, `docker-compose.yml`, modèles de configuration) est **en lecture seule à l’exécution**. Toutes les données modifiables se trouvent à la place sous **`/var/data`** : `.env`, `customer-config.sh`, `secrets/`, la configuration TLS, Keycloak et APISIX générée, les sauvegardes ainsi que les données propres à chaque service (`STARGATE_DATA_DIR` remplace cette racine à des fins de test). En particulier : la configuration et les secrets se trouvent sous `/var/data/vereign/` et les sauvegardes sous `/var/data/backups/`. Pour la description complète, voir [Configuration avancée Docker](Docker-advanced.md). Utilisez de préférence les scripts d’encapsulation (`./scripts/start.sh`, `./scripts/stop.sh`, ...) plutôt qu’un simple `docker compose up -d`, qui ne prend pas en compte `/var/data/vereign/.env` de lui-même.

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
| Mises à jour (appliance VM) | `hingateway-status`, `docker logs stargate-ops-agent --tail 100` et `journalctl -u greenboot-healthcheck` | Versions système démarrée, préparée et de retour arrière ; sauvegarde, téléchargement et erreurs d’une mise à jour (uniquement jusqu’au prochain redémarrage) ; résultat du contrôle de santé au démarrage |
| Exécutions de `update.sh` | `cat /var/data/vereign/update.log` | Sortie de toutes les exécutions de `update.sh`, la plus récente à la fin : mises à jour des installations Compose simples, mises à jour depuis le tableau de bord sur les anciennes VM avant bootc et exécutions après une modification de `customer-config.sh` |
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
- Les e-mails **sortants et le scellement** passent par Stalwart → **mxengine** (`:8084` HTTP, SMTP `:1587`) : `docker logs stargate-mxengine`.
- Les **boucles de messagerie** se manifestent par un même message qui circule en boucle. Vérifiez que l’enregistrement MX de votre domaine ne renvoie pas vers l’adresse IP de cette appliance elle-même.
- Le routage attendu est décrit dans **[Configuration du relais de messagerie](Mail-relay-setup.md)** et **[Configuration DNS](DNS-setup.md)**.

### Échec d’une mise à jour

Sur l’appliance VM, une mise à jour lancée depuis le tableau de bord est exécutée par l’ops-agent en trois phases : une **sauvegarde** (`backup.sh`), le **téléchargement** de l’image système cible (`bootc switch`) et le **redémarrage** sur cette image. Commencez par :

```bash
docker logs stargate-ops-agent --tail 100     # the update orchestrator: backup, download, errors
hingateway-status                             # booted, staged and rollback OS versions
```

Le conteneur de l’ops-agent est recréé à chaque démarrage ; son journal ne couvre donc une mise à jour que jusqu’au redémarrage de la VM. Après un redémarrage, utilisez plutôt `hingateway-status` et `journalctl -u greenboot-healthcheck`.

- **Échec pendant la sauvegarde.** L’ops-agent annule la mise à jour lorsque la sauvegarde préalable échoue ; rien n’a donc été modifié. Vérifiez l’erreur dans le journal de l’ops-agent et l’espace libre sur le Data Disk (`df -h /var/data`), puis relancez la mise à jour.
- **Échec pendant le téléchargement.** L’état de la mise à jour dans le tableau de bord affiche l’erreur sous la forme `bootc switch: ...` ; le journal de l’ops-agent n’enregistre que `os select failed` avec le code de sortie. En général, la VM ne peut pas joindre le registre d’images (vérifiez l’accès Internet sortant et le DNS) ou le disque système est plein (`df -h /sysroot`). La version en cours d’exécution n’est pas affectée ; relancez la mise à jour une fois la cause corrigée.
- **Téléchargée, mais la version n’a pas changé.** La nouvelle version n’est activée que par un redémarrage. Si vous avez choisi `Later`, redémarrez la VM (`sudo systemctl reboot`) et vérifiez à nouveau `hingateway-status`. Si la VM a bien redémarré et affiche toujours l’ancienne version comme démarrée, elle est revenue automatiquement en arrière - voir le point suivant.
- **Retour arrière automatique après un démarrage en échec.** Après le démarrage d’une nouvelle version, des contrôles de santé s’exécutent - entre autres, si Docker fonctionne, si le Data Disk est monté et si la pile Stargate est en bon état, ainsi que les contrôles par défaut du système d’exploitation. Si un contrôle obligatoire échoue, le démarrage est marqué RED et la VM redémarre d’elle-même sur la version précédente. `journalctl -u greenboot-healthcheck` indique quel contrôle a échoué. Corrigez la cause avant de relancer la mise à jour ; un simple redémarrage répète le même retour arrière. Si la nouvelle version avait déjà modifié un schéma de base de données, ou si la mise à jour en échec était la première mise à niveau vers une image prenant en charge le Data Disk (la pile affiche alors un `/var/data` vide, mais vos données sont intactes), lisez les [avertissements sur le retour arrière](Docker-advanced.md#retour-arriere) avant toute autre action.
- **La nouvelle version démarre mais ne fonctionne pas correctement.** Vérifiez le contrôle de santé au démarrage avec `journalctl -u greenboot-healthcheck` et la pile avec `/usr/share/stargate-deployment/docker-compose/scripts/health-check.sh -v`. Pour revenir à la version précédente, utilisez `Roll back` dans le tableau de bord ou exécutez `hingateway-rollback && sudo systemctl reboot` - lisez d’abord les [avertissements sur le retour arrière](Docker-advanced.md#retour-arriere).
- Après une mise à jour réussie, vérifiez que les versions ont été appliquées : `/usr/share/stargate-deployment/docker-compose/scripts/gather-app-versions.sh` (ou les tags d’image dans `docker compose ps`).
- Si un service reste bloqué après une mise à jour, recréez uniquement ce service : `cd /usr/share/stargate-deployment/docker-compose && sudo docker compose --env-file /var/data/vereign/.env up -d --no-deps --force-recreate <service>`. `sudo` est nécessaire car seul root peut lire `.env`, et `--no-deps` empêche Compose de recréer aussi les dépendances du service, comme Vault, qui redémarrerait scellé. Si `/var/data/vereign/docker-compose.override.yml` (ou `.yaml`) existe, ajoutez `-f docker-compose.yml -f <fichier override>` après `--env-file /var/data/vereign/.env` pour que l’override reste appliqué. Les services qui appartiennent à un profil en ont également besoin : ajoutez `--profile dozzle` pour `dozzle` et `oauth2-proxy`, `--profile keri-idagent` pour `idagent` et `--profile keri-watcher` pour `watcher`.

Sur une installation Compose simple (un `git clone` que vous gérez vous-même), il n’y a pas de mise à jour via l’ops-agent : vous exécutez `update.sh` vous-même, et sa sortie est ajoutée à `/var/data/vereign/update.log`, l’exécution la plus récente se trouvant à la fin. Les étapes de mise à jour sont décrites dans [Installation Compose simple](Docker-advanced.md#installation-compose-simple).

!!! warning
    N’essayez pas de réparer une mise à jour sur l’appliance VM avec `git` ou `update.sh --release`. `/usr/share/stargate-deployment` fait partie de l’image système en lecture seule et il n’existe aucune copie du dépôt à réinitialiser ; les versions ne changent qu’en basculant d’image système.

#### VM plus anciennes (avant l’image bootc)

Les VM installées à partir d’une image antérieure à l’appliance bootc ont une copie git sous `/usr/share/stargate-deployment` au lieu d’une image système en lecture seule. Les étapes ci-dessus pour l’appliance VM ne s’appliquent pas à elles. À terme, migrez-les vers une appliance bootc comme décrit dans le guide en anglais « Migrating a Compose Deployment to a bootc Appliance ». En attendant, ce qui suit s’applique uniquement à ces anciennes VM. Sur celles-ci, l’ops-agent exécute `update.sh`, dont la sortie est ajoutée à `/var/data/vereign/update.log` (l’exécution la plus récente à la fin) - consultez ce fichier en premier lorsqu’une mise à jour échoue.

**La mise à jour démarre, mais rien ne se passe (mise à jour depuis une version antérieure).** Si le journal de l’ops-agent s’arrête à `pulling deployment repo ...` et que la mise à jour n’avance plus, le dépôt sur la VM contient très probablement des **modifications locales sur un fichier suivi** (le plus souvent un `docker-compose.yml` modifié à la main). Le `git checkout` de l’ops-agent refuse alors de s’exécuter et la mise à jour reste bloquée. Réinitialisez de force le dépôt sur la dernière révision, puis relancez la mise à jour. Git est la source unique de vérité ; cette opération n’annule que les modifications locales apportées aux fichiers **suivis**. `customer-config.sh`, `.env` et `secrets/` se trouvent sous `/var/data/vereign/`, en dehors de la copie du dépôt, et sont toujours préservés :

```bash
cd /usr/share/stargate-deployment
sudo git fetch origin
sudo git checkout -f main
sudo git reset --hard origin/main
cd docker-compose
sudo /usr/share/stargate-deployment/docker-compose/scripts/update.sh
```

`update.sh` régénère `.env`, télécharge les images et recrée les services concernés. Si la version a modifié des fichiers de configuration, exécutez ensuite `sudo /usr/share/stargate-deployment/docker-compose/scripts/start.sh` pour que tous les conteneurs prennent en compte les nouveaux fichiers. Une fois l’opération terminée, relancez la mise à jour depuis le tableau de bord ; elle se déroulera alors normalement.

!!! warning
    N’utilisez pas `git pull` ici. Sur une copie de travail comportant des modifications locales, cette commande s’interrompt avec le message « local changes would be overwritten », ce qui oblige à passer par un `git stash`, un conflit de fusion ou une récupération manuelle. La séquence `git checkout -f` + `git reset --hard` ci-dessus évite entièrement ce détour : c’est la méthode sûre et reproductible pour mettre le dépôt à jour.

#### VM en v0.5.1

Les étapes suivantes mettent à jour une VM de la version v0.5.1 vers la version v0.5.3. En v0.5.x, `.env`, `customer-config.sh` et `secrets/` se trouvent dans la copie, sous `/usr/share/stargate-deployment/docker-compose/`, et non sous `/var/data/vereign/`. Connectez-vous à la VM avec le compte administrateur Linux.

1. Modifiez `/usr/share/stargate-deployment/docker-compose/.env` et définissez la version de l’ops-agent sur v0.0.3.
2. Modifiez `/usr/share/stargate-deployment/docker-compose/customer-config.sh` et définissez-y également la version de l’ops-agent sur v0.0.3.
3. Récupérez les tags de version : `cd /usr/share/stargate-deployment && sudo git fetch --tags origin`
4. Extrayez la version cible : `sudo git checkout v0.5.3`. N’extrayez pas `main` : cette branche contient les scripts actuels, qui attendent la nouvelle organisation sous `/var/data`.
5. Mettez à jour le conteneur ops-agent : `cd docker-compose && sudo docker compose up -d ops-agent`
6. Connectez-vous au tableau de bord.
7. Ouvrez Settings.
8. Dans la section Update, en bas de la page, saisissez la version cible (v0.5.3) et lancez la mise à jour.

Migrez ensuite la VM vers une appliance bootc comme décrit dans le guide en anglais « Migrating a Compose Deployment to a bootc Appliance ».

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

Si l’adresse IP du serveur était erronée ou non définie au premier démarrage, réinitialisez proprement puis réinstallez. Sauvegardez d’abord la configuration, car `purge.sh` supprime aussi `customer-config.sh` :

```bash
/usr/share/stargate-deployment/docker-compose/scripts/backup.sh --config-only  # saves customer-config.sh
/usr/share/stargate-deployment/docker-compose/scripts/purge.sh                 # destroys ALL data - see warning below
/usr/share/stargate-deployment/docker-compose/scripts/restore.sh --config-only /var/data/backups/<timestamp>_config-only.tar.gz
nano /var/data/vereign/customer-config.sh    # set SERVER_STATIC_IP=<NEW IP>
reboot                                       # installs again with the new IP
```

`backup.sh` affiche la commande de restauration exacte, et l’archive reste dans `/var/data/backups`, que `purge.sh` ne supprime pas. Le redémarrage lance l’installation et recharge aussi les images construites localement que `purge.sh` supprime. Sur une installation Docker classique, exécutez `install.sh` au lieu de redémarrer.

Le certificat TLS et plusieurs URL de services sont dérivés de l’adresse IP au premier démarrage ; une purge suivie d’une réinstallation les régénère donc pour la nouvelle adresse. Le fichier restauré conserve les mots de passe générés et la clé WireGuard. Si la passerelle est déjà enregistrée auprès de HIN, l’enregistrement doit être mis à jour avec la nouvelle adresse IP.

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

### Le réseau Docker chevauche le réseau local

Les services communiquent entre eux sur un réseau Docker interne. Docker choisit sa plage d’adresses à la création de la pile et évite les réseaux auxquels la VM est directement connectée à ce moment-là. Si la plage contient malgré tout des adresses de votre réseau, l’appliance ne peut pas joindre ces machines (par exemple un serveur de messagerie ou DNS), et elles ne peuvent pas la joindre. Le contrôle d’état le signale sous **Docker network** :

```text
[FAIL] stargate-network 172.18.0.0/16 overlaps host routes: 172.18.5.0/24 dev ens18 - see Troubleshooting: The Docker network overlaps the local network
```

- **L’adresse IP a été modifiée après le premier démarrage** : Docker a choisi la plage alors que la VM avait encore sa première adresse. Sur une passerelle pas encore intégrée, utilisez la purge et la réinstallation décrites dans *Modifier l’adresse IP du serveur* ci-dessus ; Docker choisit alors lui-même une plage libre. Sur une passerelle déjà intégrée, recréez le réseau comme indiqué ci-dessous.
- **Le réseau en conflit se trouve derrière un routeur** (une route statique ou un réseau sur un autre site) : Docker n’évite pas ces réseaux. Le contrôle d’état voit toutes les routes de l’hôte, mais pas les réseaux joints via la passerelle par défaut. Donnez d’abord à Docker une plage libre : ajoutez ceci à `/etc/docker/daemon.json`, en conservant les paramètres déjà présents, avec une plage que votre réseau n’utilise pas :

    ```json
    {
      "default-address-pools": [
        { "base": "10.200.0.0/16", "size": 24 }
      ]
    }
    ```

    Exécutez ensuite `systemctl restart docker` et recréez le réseau comme indiqué ci-dessous.

La recréation du réseau conserve toutes les données dans `/var/data`. Arrêtez d’abord le service, sinon un Dozzle en cours d’exécution garde l’ancien réseau occupé :

```bash
systemctl stop stargate
cd /usr/share/stargate-deployment/docker-compose
docker compose --env-file /var/data/vereign/.env down
systemctl start stargate
/usr/share/stargate-deployment/docker-compose/scripts/health-check.sh
```

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

# Redémarrage sur la VM v0.6.1

Veuillez noter que si vous redémarrez (REBOOT) une instance qui fonctionne sous v0.6.1, elle reviendra à la version précédente de Stalwart <0.0.23, qui ne fonctionne pas.

Nous vous recommandons de mettre à jour l’instance vers une version plus récente depuis la section Settings->System version !
