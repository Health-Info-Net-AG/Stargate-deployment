# Dépannage et diagnostics

Guide structuré pour le diagnostic d'une appliance HIN Gateway depuis la ligne de commande: éléments à vérifier, emplacement des journaux et procédures de récupération sans risque.

!!! info "Où exécuter ces commandes"
    Exécutez toutes les commandes ci-dessous à partir du **répertoire de déploiement** - le dossier contenant `docker-compose.yml` et `scripts/` (sur les images de machine virtuelle (VM), il s'agit généralement de `/usr/share/stargate-deployment/docker-compose`, ou du répertoire dans lequel vous avez effectué l'installation). Toutes les commandes `docker compose` et `./scripts/*` supposent que vous vous trouvez dans ce répertoire de travail.

    ```bash
    cd /usr/share/stargate-deployment/docker-compose   # adjust to your install path
    ```

---

## 1. Commencez ici: le contrôle d'état

Une seule commande permet d'obtenir une vue d'ensemble de l'appliance:

=== "Rapide"

    ```bash
    ./scripts/health-check.sh
    ```

=== "Détaillé"

    ```bash
    ./scripts/health-check.sh -v
    ```

Elle indique, pour chacun des éléments suivants, si le contrôle a réussi ou échoué: l'état des **conteneurs** (en cours d'exécution/en bon état), les points de terminaison de **vivacité** (smimekeys, policy, irisagent, mxengine), l'état de scellement de **Vault**, la connectivité à **PostgreSQL** et les bases de données, **SeaweedFS**, le tunnel **WireGuard** et les handshakes avec les pairs, le MTA **Stalwart** (ports 25 / 10026), les points de terminaison des métriques **Prometheus**, ainsi que l'**espace disque** et la **mémoire**.

!!! tip
    Exécutez d'abord cette commande. En général, une seule ligne `FAIL` permet d'identifier directement la section correspondante ci-dessous.

---

## 2. Où trouver les journaux

| Couche | Commande | Informations affichées |
| ------- | --------- | --------------- |
| Démarrage / installation initiale / démarrage automatique | `sudo journalctl -u stargate -n 200 --no-pager` | Le service systemd qui exécute `start.sh` au démarrage et lors de la première installation |
| Exécutions des mises à jour | `cat ../update.log` (racine du déploiement, un niveau au-dessus de `docker-compose/`) | Sortie du dernier `update.sh` déclenché depuis le tableau de bord ou l'hôte |
| Un seul service | `docker logs stargate-<service> --tail 100` | par exemple `stargate-dashboard`, `stargate-mxengine`, `stargate-keycloak` |
| Suivre un service en temps réel | `docker logs -f stargate-mxengine` | Temps réel |
| Tous les conteneurs en temps réel | `docker ps -a --format '{{.Names}}' \| xargs -I{} sh -c 'docker logs --timestamps -f {} 2>&1 \| sed "s/^/[{}] /"'` | Journaux fusionnés, préfixés par le conteneur |
| Interface web de consultation des journaux | Dozzle à l'adresse `https://<SERVER_IP>:8190` (connexion Keycloak) | Consultez tous les journaux des conteneurs dans une interface utilisateur |

Pour transmettre les journaux au support HIN, utilisez le script d'envoi et communiquez le lien obtenu - voir **[Fournir des journaux au support](Docker-advanced.md#fournir-les-logs-au-support)**:

```bash
./scripts/send-logs-to-support.sh --all          # or --since 1h  / --tail 500
```

---

## 3. Conteneurs non démarrés ou en cours de redémarrage

```bash
docker compose ps -a --format 'table {{.Service}}\t{{.Status}}'
```

Consultez la colonne `Status`:

| Statut | Signification | Action |
| -------- | --------- | -------- |
| `Up ... (healthy)` | Fonctionnement normal | - |
| `Up ...` (no health) | En cours d'exécution; aucun contrôle d'état défini | Consultez ses `docker logs` si vous suspectez un problème |
| `Restarting` | Redémarrages en boucle | `docker logs stargate-<svc>` - corrigez l'erreur à l'origine du problème (configuration, secret, dépendance) |
| `Exited (0)` | Initialisation ponctuelle terminée correctement (p. ex. `*-init`, `vault-data-fixer`) | Normal |
| `Exited (1+)` | Échec | `docker logs stargate-<svc>` - les dernières lignes indiquent la cause |
| `Created` | Jamais démarré - une dépendance n'a pas démarré | Vérifiez de quoi il dépend (`depends_on`, généralement Postgres/Vault); corrigez d'abord ce point |

Redémarrer un seul service (opération sûre et non destructive):

```bash
docker compose up -d <service>          # recreate one service
docker compose restart <service>        # just restart it
```

!!! note "Ordre de démarrage"
    Les services attendent que leurs dépendances soient disponibles (`depends_on` + contrôles d'état). Lors d'un redémarrage complet, il est **normal** que des lignes `connection refused` / `database system is starting up` apparaissent brièvement pendant le démarrage de Postgres/Vault; elles disparaissent en moins d'une minute.

---

## 4. Diagnostic par symptôme

### Le tableau de bord ou Keycloak ne se charge pas / impossible de se connecter

- Le tableau de bord et Keycloak sont tous deux placés derrière Caddy: **le tableau de bord** sur `:443`, **Keycloak** sur `:8180`.
- Vérifiez l'ensemble de la chaîne: `docker logs stargate-caddy`, `stargate-dashboard`, `stargate-keycloak`, `stargate-apisix`.
- Keycloak doit être **en bon état** avant que le tableau de bord puisse fonctionner: `docker compose ps keycloak`.
- L'avertissement TLS dans le navigateur est normal (certificat auto-signé) - acceptez-le et poursuivez.
- Si les redirections de connexion échouent, cela signifie généralement que l'URL publique ne correspond pas à la manière dont vous accédez à la machine - vérifiez que `KEYCLOAK_PUBLIC_URL` / `DASHBOARD_PUBLIC_URL` dans `.env` pointent vers l'adresse IP ou le nom d'hôte que vous utilisez réellement.

### Tunnel WireGuard indisponible / échec de l'émission des certificats

Il s'agit du problème le plus fréquent - **l'émission des certificats échoue lorsque le tunnel est indisponible**, donc commencez toujours par rétablir le tunnel.

```bash
./scripts/health-check.sh -v      # shows WireGuard peer + handshake status
docker logs stargate-irisagent | grep -iE "handshake|peer|cert|wireguard"
```

- Vérifiez que le pare-feu autorise **`19818` (UDP *et* TCP)** dans les deux sens.
- Vérifiez que le pair est enregistré côté HIN (étape effectuée par le support) - vous devez fournir la clé publique WG, `DEPLOYMENT_NAME`, `SERVER_STATIC_IP`, `WG_INTERFACE_PORT`.
- Dès que le tunnel affiche un handshake récent, relancez l'émission des certificats depuis le tableau de bord.

### Vault scellé ou échec de l'initialisation

```bash
docker compose exec vault vault status        # look for "Sealed: false"
docker logs stargate-vault-init
```

- Vault doit être **descellé** pour que smimekeys/mxengine/policy fonctionnent. Les clés se trouvent dans `secrets/vault-keys.json`.
- Si `vault-init` s'est terminé avec un code différent de zéro, le fichier de clés est peut-être absent ou corrompu - consultez ses journaux; une nouvelle exécution de `./scripts/init-vault.sh` tente à nouveau de desceller Vault.

!!! danger "Ne supprimez pas `secrets/vault-keys.json`"
    La perte de ce fichier entraîne la perte de l'accès à tous les secrets enregistrés. Conservez-en une sauvegarde.

### Connectivité PostgreSQL / bases de données

```bash
docker compose exec postgres pg_isready -U postgres
docker logs stargate-postgres --tail 50
```

- L'apparition temporaire du message `the database system is starting up (57P03)` juste après un redémarrage est normale - les services se reconnectent automatiquement.
- Des échecs d'authentification persistants indiquent généralement que `POSTGRES_PASSWORD` dans `.env` ne correspond plus à celle du volume de données - consultez les remarques relatives aux mises à jour et aux secrets, et évitez de modifier cette valeur manuellement.

### Les e-mails ne sont pas acheminés

- Les **e-mails entrants** arrivent sur **`:25`** (Stalwart). De nombreux fournisseurs de services cloud **bloquent le port 25** par défaut:

    ```bash
    nc -zv <this-server-ip> 25          # from an external host
    docker logs stargate-stalwart --tail 100
    ```

    Si `25` est bloqué, demandez une exception à votre fournisseur.
- **Le trafic sortant et le scellement** suivent le chemin Stalwart → **mxengine** (`:8084` callback de scellement, SMTP `:1587`): `docker logs stargate-mxengine`.
- Les **boucles de messagerie** se manifestent par le même message qui circule en continu - vérifiez que l'enregistrement MX de votre domaine ne pointe pas vers l'adresse IP propre de cette appliance.
- Voir **[Configuration du relais de messagerie](Mail-relay-setup.md)** et **[Configuration DNS](DNS-setup.md)** pour le routage attendu.

### Échec d'une mise à jour

```bash
docker logs stargate-ops-agent --tail 40      # the update orchestrator
cat ../update.log                             # the update script output
```

- L'ops-agent récupère le manifeste de version, inscrit les versions dans `customer-config.sh`, puis exécute `update.sh` sur l'hôte.
- Une fois l'opération terminée, vérifiez les versions appliquées: `./scripts/gather-app-versions.sh` (ou contrôlez les tags d'image avec `docker compose ps`).
- Si un service reste bloqué après une mise à jour, exécutez `docker compose up -d <service>` pour le recréer.

**La mise à jour démarre, mais rien ne se passe (mise à jour depuis une version antérieure).** Si le journal de l'ops-agent s'arrête à `pulling deployment repo ...` et que la mise à jour ne progresse plus, le dépôt sur la VM contient très probablement des **modifications locales sur un fichier suivi** (le plus souvent un `docker-compose.yml` modifié manuellement). Le `git checkout` de l'ops-agent refuse alors de s'exécuter, ce qui bloque la mise à jour. Réinitialisez le dépôt de force sur la dernière révision, puis relancez la mise à jour. Git est la source unique de vérité; cette opération n'annule que les modifications locales apportées aux fichiers **suivis** - `customer-config.sh`, `.env` et `secrets/` figurent dans `.gitignore` et sont préservés:

```bash
cd /usr/share/stargate-deployment
git fetch origin
git checkout -f main
git reset --hard origin/main
sed -i 's/^OPS_AGENT_VERSION=.*/OPS_AGENT_VERSION="v0.0.3"/' docker-compose/customer-config.sh   # v0.0.3 or newer
cd docker-compose
./scripts/update.sh
```

`update.sh` régénère `.env`, récupère les images et recrée les services concernés - vous n'avez **pas** besoin de redémarrer HIN Gateway manuellement. Une fois l'opération terminée, relancez la mise à jour depuis le tableau de bord; elle se poursuivra alors normalement.

!!! warning
    N'utilisez pas `git pull` ici. Sur une copie de travail comportant des modifications locales, cette commande échoue avec le message «local changes would be overwritten», ce qui impose de passer par un `git stash`, un conflit de fusion ou une récupération manuelle. La séquence `git checkout -f` puis `git reset --hard` ci-dessus évite entièrement ce problème: c'est la méthode sûre et reproductible pour remettre le dépôt à jour.

### Dozzle (visualisateur de journaux) inaccessible

- L'URL est `https://<SERVER_IP>:8190`; une **connexion Keycloak** (même realm que le tableau de bord) est requise via oauth2-proxy.
- Il ne s'exécute que si `DOZZLE_ENABLED="true"`. Vérifiez: `docker compose ps dozzle oauth2-proxy`.
- Assurez-vous que le pare-feu autorise **`:8190`** en entrée. Voir **[Surveillance et journaux](Monitoring.md)**.

---

## 5. Stockage et espace disque

```bash
df -h /                              # is the disk full?
docker system df                     # space used by images / containers / volumes
du -sh /var/lib/docker/volumes/*     # per-volume usage (Postgres, SeaweedFS, Loki, ...)
```

- Les journaux des conteneurs sont limités (json-file, 100 MB × 5 par conteneur), ils ne devraient donc pas saturer le disque, mais les images et les volumes le peuvent.
- Récupérez de l'espace sans risque avec: `docker image prune -af` (supprime uniquement les images inutilisées). Évitez `docker system prune --volumes` - cette commande supprime les volumes de données.
- Le stockage objet est assuré par **SeaweedFS** (`stargate-seaweedfs`): `docker logs stargate-seaweedfs --tail 50`.

---

## 6. Ressources de la VM

```bash
free -h                              # memory (min 8 GB)
nproc                                # CPUs (min 4)
docker stats --no-stream             # per-container CPU/RAM
uptime                               # load average
```

Les métriques de l'hôte sont également exportées pour Prometheus sur **`:9100/metrics`** (voir [Surveillance](Monitoring.md#métriques-prometheus)). Si la machine utilise fortement le swap ou est saturée, les contrôles d'état risquent de devenir instables et les mises à jour de ralentir.

---

## 7. Réseau et ports

Contrôle rapide de l'accessibilité des principaux ports entrants:

```bash
for p in 25 443 8180 8190 19818; do nc -zv <this-server-ip> $p; done
```

| Port | Service | Direction |
| ------ | --------- | ----------- |
| `25` | Stalwart SMTP (e-mails entrants) | entrant |
| `443` | Tableau de bord (HTTPS) | entrant |
| `8180` | Keycloak | entrant |
| `8190` | Dozzle (facultatif) | entrant |
| `19818` | WireGuard (UDP **et** TCP) | entrant/sortant |

Un accès sortant est nécessaire vers le registre de conteneurs, l'autorité de certification S/MIME (via le tunnel WireGuard) et toute instance Loki distante que vous auriez configurée. Consultez le tableau complet des ports sur la **[page d'accueil](index.md)** et dans l'**[Aperçu des applications](Applications.md)**.

---

## 8. Actions de récupération

Classées de la moins à la plus perturbatrice:

```bash
docker compose up -d <service>       # recreate one stuck service
sudo systemctl restart stargate      # restart the whole stack (via start.sh)
./scripts/stop.sh  &&  ./scripts/start.sh
```

!!! warning "Sauvegardes et récupération destructive"
    `./scripts/backup.sh` et `./scripts/restore.sh` assurent la sauvegarde et la restauration des données. `./scripts/purge.sh` **supprime toutes les données** (bases de données, Vault, stockage) afin de permettre une réinstallation propre - à n'utiliser qu'en dernier recours et uniquement avec une sauvegarde à jour. Détails: [Configuration avancée Docker](Docker-advanced.md).

---

## 9. Quand contacter le support

Si le contrôle d'état indique toujours des échecs après les étapes ci-dessus, ouvrez un ticket via **[Support / Contactez-nous](Support.md)** et joignez les éléments suivants:

- La **version de l'appliance** (`./scripts/gather-app-versions.sh`) et le **nom du client**.
- La **sortie du contrôle d'état** (`./scripts/health-check.sh -v`).
- Un lien vers une **archive de journaux** générée par `./scripts/send-logs-to-support.sh` (voir [Fournir des journaux au support](Docker-advanced.md#fournir-les-logs-au-support)).
- Ce que vous faisiez au moment du dysfonctionnement, ainsi que toute capture d'écran utile.

## Mettre à jour une instance Verimesh

Les instructions suivantes décrivent la mise à jour d'une instance Verimesh de la version v0.5.1 vers la version v0.5.3.

*Remarque:* vous devez vous connecter à la VM avec le compte administrateur Linux.

### Étapes de mise à jour

1. Modifiez le fichier .env et définissez la version de l'ops-agent sur v0.0.3.
2. Modifiez également la configuration du client et définissez-y la version de l'ops-agent sur v0.0.3.
3. Basculez sur la branche main: `git checkout main`
4. Récupérez les dernières modifications: `git pull`
5. Mettez à jour le conteneur ops-agent: `docker compose up -d ops-agent`
6. Connectez-vous au tableau de bord.
7. Accédez à Settings.
8. Dans la section Update, en bas de la page, saisissez la version cible (v0.5.3) et lancez le processus de mise à jour.

## Configurer Keycloak après la mise à jour

Remarque: ces instructions s'appliquent si vous étiez sur l'image de VM v0.5.1 et que vous avez ensuite effectué une mise à jour vers une version plus récente.

À la suite de la dernière mise à jour de Keycloak, une modification incompatible entraîne la redirection inattendue des utilisateurs authentifiés vers la page de connexion lorsqu'ils accèdent à certaines routes de l'application (par exemple Peers, Peer Certificates).

Pour résoudre ce problème, la configuration manuelle suivante doit être effectuée dans l'*interface de Keycloak*.

### Étapes de résolution

1. Ouvrez Keycloak sur l'environnement concerné et saisissez l'URL - `<VM IP address>/admin/master/console/`
    utilisateur: Admin
    mot de passe: récupérez le mot de passe administrateur dans le fichier .env de la machine (vous devez pour cela vous connecter à la console Linux)

2. Console d'administration - changez de realm vers → realm stargate:
3. Allez dans Clients → dashboard
4. Ouvrez l'onglet Client scopes → cliquez sur dashboard-dedicated
5. Sélectionnez Configure a new mapper → Audience
6. Définissez les paramètres suivants:
    - Name: apisix-audience
    - Included client audience: apisix (à sélectionner dans la liste déroulante)
    - Included custom audience: (laissez vide)
    - Add to access token: On
    - Add to token introspection: On
    - Add to ID token / lightweight token: Off

7. Cliquez sur Save

 <br> ![keycloak-console](assets/troubleshooting/keycloak-update.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
