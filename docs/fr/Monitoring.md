# Surveillance et Logs

HIN Gateway inclut des services intégrés de surveillance et de collecte de logs qui fonctionnent aux côtés des conteneurs d'application.

## Composants

| Service | Port | Objectif |
| --------- | ------ | --------- |
| node-exporter | `9100` | Métriques au niveau de l'hôte (CPU, mémoire, disque, réseau) pour Prometheus |
| version-collector | - | Collecte les versions des applications depuis les points de terminaison `/liveness` |
| Alloy | `12345` | Collecteur de logs Docker - envoie les logs des conteneurs à Loki |
| Loki | `3100` (interne) | Backend d'agrégation de logs local |
| Dozzle | `8190` | Visualisateur de logs de conteneurs basé sur le web (HTTPS, SSO Keycloak ; optionnel) |
| oauth2-proxy | `8190` | Partie fiable OIDC qui authentifie l'accès Dozzle (avec Dozzle) |

---

## Dozzle - Visualisateur de logs local

Dozzle fournit une interface web pour visualiser les logs en temps réel de tous les conteneurs HIN Gateway. Il est optionnel et activé en définissant `DOZZLE_ENABLED="true"` dans `customer-config.sh`.

L'accès est protégé par **Keycloak**: un `oauth2-proxy` se place devant Dozzle et nécessite la même connexion que le tableau de bord (le domaine `stargate`). Dozzle lui-même n'est pas exposé directement.

**Accès :** ouvrez `https://<IP_SERVEUR>:8190` dans un navigateur et connectez-vous avec vos identifiants HIN Gateway (Keycloak).

!!! note
    Le port `8190` (HTTPS) doit être accessible depuis votre réseau. Si vous restreignez l'accès par IP ou pare-feu, autorisez `8190/tcp` comme vous le faites pour le tableau de bord et Keycloak.

Les logs sont organisés par service. En sélectionnant un service spécifique, vous pouvez visualiser ses entrées de logs et détails correspondants.

![Aperçu Dozzle](./assets/dozzle-overview.png)

---

## Grafana Alloy - Transfert de logs

Grafana Alloy collecte les logs de tous les conteneurs d'application HIN Gateway et les écrit dans l'instance Loki locale. Optionnellement, les logs peuvent également être transférés vers un point de terminaison distant compatible Loki pour une surveillance centralisée.

### Comment cela fonctionne

1. Alloy découvre les conteneurs HIN Gateway via le socket Docker
2. Les logs sont toujours écrits dans l'instance **Loki locale** (utilisée par le tableau de bord pour l'exportation des logs)
3. Si une URL Loki distante est configurée, les logs sont **également transférés** vers ce point de terminaison

### Configurer le transfert de logs à distance

Depuis le tableau de bord HIN Gateway, accédez à la page **Paramètres**. Dans la section **Grafana Alloy**, entrez l'URL de poussée Loki de votre serveur de collecte de logs distant:

![Paramètres Alloy](./assets/alloy-settings.png)

L'URL doit suivre le format standard de l'API de poussée Loki:

```plain
https://logs.example.com/loki/api/v1/push
```

Laissez le champ vide pour désactiver le transfert de logs à distance.

!!! note
    Les modifications prennent effet dans un délai d'1 minute (Alloy interroge la configuration du tableau de bord à cet intervalle). Aucun redémarrage de conteneur n'est nécessaire.

### Exigences du côté distant

Votre point de terminaison Loki distant doit être accessible depuis le serveur HIN Gateway via HTTPS (port 443). Si vous utilisez une liste d'autorisation basée sur IP sur votre entrée, ajoutez l'IP publique du serveur HIN Gateway.

---

## Métriques Prometheus

HIN Gateway expose des points de terminaison de métriques compatibles Prometheus depuis ses conteneurs d'application. Ceux-ci peuvent être récupérés par tout serveur compatible Prometheus pour une collecte centralisée des métriques.

### Points de terminaison disponibles

| Service | Port | Chemin |
| --------- | ------ | ------ |
| smimekeys-client | `2113` | `/metrics` |
| irisagent | `2114` | `/metrics` |
| policy | `2115` | `/metrics` |
| mxengine | `2116` | `/metrics` |
| node-exporter | `9100` | `/metrics` |
| APISIX | `9091` | `/apisix/prometheus/metrics` |

### Configuration de récupération

Ajoutez le serveur HIN Gateway comme cible dans votre configuration Prometheus. Exemple pour une instance unique:

```yaml
scrape_configs:
  - job_name: 'stargate-<name>-smimekeys'
    static_configs:
      - targets: ['<HIN_GATEWAY_IP>:2113']
        labels:
          environment: 'stargate-<name>'
          service: 'smimekeys-client'
    metrics_path: /metrics

  - job_name: 'stargate-<name>-irisagent'
    static_configs:
      - targets: ['<HIN_GATEWAY_IP>:2114']
        labels:
          environment: 'stargate-<name>'
          service: 'irisagent'
    metrics_path: /metrics

  - job_name: 'stargate-<name>-policy'
    static_configs:
      - targets: ['<HIN_GATEWAY_IP>:2115']
        labels:
          environment: 'stargate-<name>'
          service: 'policy'
    metrics_path: /metrics

  - job_name: 'stargate-<name>-mxengine'
    static_configs:
      - targets: ['<HIN_GATEWAY_IP>:2116']
        labels:
          environment: 'stargate-<name>'
          service: 'mxengine'
    metrics_path: /metrics

  - job_name: 'stargate-<name>-node'
    static_configs:
      - targets: ['<HIN_GATEWAY_IP>:9100']
        labels:
          environment: 'stargate-<name>'
          service: 'node-exporter'
    metrics_path: /metrics
```

Remplacez `<IP_HIN_GATEWAY>` par l'IP publique ou privée du serveur et `<nom>` par un identifiant de déploiement (ex. `prod`, `nom-client`).

!!! tip
    Les étiquettes `environment` et `service` permettent le filtrage dans les tableaux de bord Grafana sur plusieurs instances HIN Gateway.

### Exigences de pare-feu

Les ports de métriques (2113-2116, 9100) doivent être accessibles depuis votre serveur Prometheus. Si vous restreignez l'accès par IP, ajoutez l'IP de votre serveur de surveillance aux règles de pare-feu.

---

## Node Exporter

Le service node-exporter expose des métriques standard au niveau de l'hôte (CPU, mémoire, E/S disque, réseau) sur le port **9100**. Il inclut également un collecteur de fichiers texte qui expose des métriques personnalisées du sidecar version-collector (informations de version des applications).

---

## Résumé des ports exposés

| Port | Service | Protocole | Objectif |
| ------ | --------- | ---------- | --------- |
| `8190` | Dozzle (via oauth2-proxy) | HTTPS | Interface de visualisation des logs authentifiée (SSO Keycloak) |
| `9100` | node-exporter | HTTP | Métriques de l'hôte (Prometheus) |
| `2113` | smimekeys-client | HTTP | Métriques de l'application (Prometheus) |
| `2114` | irisagent | HTTP | Métriques de l'application (Prometheus) |
| `2115` | policy | HTTP | Métriques de l'application (Prometheus) |
| `2116` | mxengine | HTTP | Métriques de l'application (Prometheus) |
| `9091` | APISIX | HTTP | Métriques de la passerelle (Prometheus) |
