# Configuration DNS pour Stargate

Ce guide couvre tous les enregistrements DNS requis pour un déploiement fonctionnel de Stargate. Configurez ces enregistrements **avant** d'installer Stargate ou immédiatement après, selon le type d'enregistrement.

Tout au long de ce guide:

- `<STARGATE_IP>` - l'adresse IP publique statique de votre serveur Stargate (`SERVER_STATIC_IP` dans `customer-config.sh`)
- `<MAIL_HOSTNAME>` - le FQDN du relais Stargate (ex. `mail.example.ch` ; configuré via la page `/mail` du tableau de bord)
- `<YOUR_DOMAIN>` - votre domaine de courrier (ex. `example.ch` ; configuré via la page `/mail` du tableau de bord)

---

## Résumé des enregistrements

| Enregistrement | Nom | Valeur | Requis | Quand |
|--------|------|-------|----------|------|
| [A](#enregistrement-a) | `<MAIL_HOSTNAME>` | `<STARGATE_IP>` | Oui | Avant l'installation |
| [MX](#enregistrements-mx) | `<YOUR_DOMAIN>` | `<MAIL_HOSTNAME>` (priorité 15) | Oui | Avant l'installation |
| [SPF](#enregistrement-spf) | `<YOUR_DOMAIN>` | `ip4:<STARGATE_IP>` ajouté au TXT | Oui | Avant l'installation |
| [PTR](#ptr-dns-inverse) | `<STARGATE_IP>` | `<MAIL_HOSTNAME>` | Recommandé | Avant l'installation |
| [DMARC](#enregistrement-dmarc) | `_dmarc.<YOUR_DOMAIN>` | `v=DMARC1; p=none; ...` | Recommandé | Après l'installation |
| [DKIM](#enregistrements-dkim) | `selector._domainkey.<YOUR_DOMAIN>` | Depuis M365/fournisseur | Recommandé | Après l'installation |

Pour les déploiements multi-domaines, répétez les enregistrements MX, SPF, DMARC et DKIM pour chaque domaine répertorié dans `MAIL_DOMAINS`.

---

## Enregistrements requis

### Enregistrement A

Créez un enregistrement A pointant le nom d'hôte du courrier Stargate vers l'IP publique du serveur:

```plain
<MAIL_HOSTNAME>.    A    <STARGATE_IP>
```

Exemple:

```plain
mail.example.ch.    A    128.140.117.200
```

Si Stargate dispose d'une adresse IPv6, ajoutez également un enregistrement AAAA:

```plain
mail.example.ch.    AAAA    2a01:4f8:c012:1234::1
```

**Pourquoi**: Les serveurs de courrier externes se connectent à ce nom d'hôte pour livrer les courriels. Sans l'enregistrement A, l'enregistrement MX ci-dessous n'est pas résolvable.

### Enregistrements MX

Ajoutez un enregistrement MX pour Stargate avec une **priorité plus élevée** (nombre inférieur) que le serveur de courrier existant. Cela garantit que les courriels entrants atteignent d'abord Stargate pour le traitement S/MIME avant d'être transférés vers Exchange ou votre plateforme de courrier.

```plain
<YOUR_DOMAIN>.    MX    15    <MAIL_HOSTNAME>.
```

Conservez l'enregistrement MX existant d'Exchange / serveur de courrier avec une priorité inférieure (nombre supérieur):

```plain
<YOUR_DOMAIN>.    MX    20    <YOUR_DOMAIN>.mail.protection.outlook.com.
```

Exemple (ensemble MX complet):

```plain
example.ch.    MX    15    mail.example.ch.
example.ch.    MX    20    example-ch.mail.protection.outlook.com.
```

!!! info
    Un numéro MX inférieur signifie une priorité plus élevée. Stargate avec la priorité 15 reçoit les courriels avant Exchange Online avec la priorité 20.

**Pourquoi**: Stargate intercepte les courriels entrants, traite S/MIME, puis les transfère au prochain MX (Exchange). Le deuxième enregistrement MX est également utilisé par Stalwart pour savoir où relayer les courriels traités.

**Important**: Si Stargate est le **seul** enregistrement MX pour un domaine, Stalwart filtrera son propre nom d'hôte et n'aura pas de cible de livraison. Conservez toujours un deuxième MX pointant vers votre serveur de courrier réel.

### Enregistrement SPF

Ajoutez l'IP du serveur Stargate **et l'IP du scelleur HIN** à l'enregistrement SPF de votre domaine afin que les courriels sortants relayés via celui-ci réussissent les vérifications SPF chez le destinataire.

**Si vous utilisez M365 / Exchange Online:**

```plain
<YOUR_DOMAIN>.    TXT    "v=spf1 ip4:<STARGATE_IP> ip4:<HIN_SEALER_IP> include:spf.protection.outlook.com -all"
```

**Si vous n'utilisez pas M365 / Google Workspace:**

```plain
<YOUR_DOMAIN>.    TXT    "v=spf1 ip4:<STARGATE_IP> ip4:<HIN_SEALER_IP> -all"
```

Exemple:

```plain
example.ch.    TXT    "v=spf1 ip4:128.140.117.200 ip4:193.247.208.66 include:spf.protection.outlook.com -all"
```

!!! question "Pourquoi l'IP du scelleur HIN est requise"
    Lorsque Stargate produit un message SCELLÉ (chiffré) pour un destinataire non-HIN, le dernier saut sortant vers le destinataire est le **scelleur HIN**, pas votre Stargate ou M365. Sans l'IP du scelleur dans votre enregistrement SPF, chaque message sortant SCELLÉ échouera au SPF chez le destinataire et - car il n'y a pas de signature DKIM sur la charge utile SCELLÉE - DMARC échouera également. Les destinataires avec DMARC strict (Gmail, Outlook avec application `p=reject`, Proofpoint) rejetteront ou classeront le message comme indésirable.

    IPs du scelleur à ajouter dans SPF:

    | Environnement | Hôte du scelleur | IP à ajouter à SPF |
    |-------------|-------------|------------------|
    | HIN Test (alpha/bêta) | `mx3.hintest.ch` | `193.247.208.66` |
    | HIN Production | À déterminer - demandez la liste canonique à HIN avant la mise en production | À déterminer |

    Si HIN publie plus d'un hôte de scellement (ex. `mx1`, `mx2`, `mx3`), incluez **toutes** leurs IPs. Résolvez-les avec `dig +short mx hintest.ch` suivi de `dig +short A <chaque-mx>`. Jusqu'à ce que vous ayez la liste complète, laissez la politique SPF à `~all` (échec doux) au lieu de `-all` (échec dur) afin que les courriels SCELLÉS légitimes via une IP de scelleur non répertoriée ne soient pas catégoriquement rejetés.

!!! warning "Limite de recherche SPF"
    La chaîne `include:` totale dans un enregistrement SPF doit rester en dessous de **10 recherches DNS**. L'ajout d'entrées `ip4:` ne compte pas dans cette limite. Vérifiez votre nombre avec [MXToolbox SPF lookup](https://mxtoolbox.com/spf.aspx).

**Comment Stargate utilise SPF**: Le démon mtaconf résout l'enregistrement SPF de chaque domaine pour remplir automatiquement la liste des IP autorisées à relayer via Stargate sans authentification. C'est ainsi que les IP sortantes de Microsoft 365 sont automatiquement mises sur liste blanche - elles apparaissent dans la chaîne `include:spf.protection.outlook.com`.

---

## Enregistrements recommandés

### PTR (DNS inversé)

Configurez l'enregistrement DNS inversé (PTR) pour l'IP Stargate afin qu'il corresponde à `<MAIL_HOSTNAME>`:

```plain
200.117.140.128.in-addr.arpa.    PTR    mail.example.ch.
```

Ceci est configuré chez votre **fournisseur d'hébergement** (Hetzner, Azure, AWS, etc.), pas dans le panneau DNS de votre bureau d'enregistrement de domaine. La plupart des fournisseurs ont un paramètre "DNS inversé" ou "rDNS" dans la page de gestion du serveur/IP.

**Pourquoi**: De nombreux serveurs de courrier récepteurs (y compris Gmail et Outlook) vérifient que l'enregistrement PTR de l'IP de connexion résout un nom d'hôte, et que ce nom d'hôte résout la même IP (DNS inversé à confirmation directe / FCrDNS). Un PTR manquant ou non correspondant est un fort signal de spam et peut entraîner des échecs de livraison.

### Enregistrement DMARC

Publiez une politique DMARC pour chaque domaine d'envoi. Commencez par `p=none` (surveillance uniquement), puis renforcez après avoir confirmé l'alignement:

```plain
_dmarc.<YOUR_DOMAIN>.    TXT    "v=DMARC1; p=none; rua=mailto:postmaster@<YOUR_DOMAIN>"
```

Exemple:

```plain
_dmarc.example.ch.    TXT    "v=DMARC1; p=none; rua=mailto:postmaster@example.ch"
```

Une fois que les rapports agrégés DMARC confirment que SPF et/ou DKIM réussissent constamment, renforcez la politique:

1. `p=none` - surveillance uniquement (commencez ici)
2. `p=quarantine` - les courriels suspects vont dans les spams
3. `p=reject` - les courriels non autorisés sont rejetés

**Pourquoi**: DMARC lie SPF et DKIM ensemble et indique aux destinataires quoi faire avec les courriels qui échouent aux deux. Même `p=none` suffit pour effacer la bannière "nous ne pouvons pas vérifier cet expéditeur" d'Outlook, tant que SPF réussit.

Vérifiez votre enregistrement DMARC: [MXToolbox DMARC lookup](https://mxtoolbox.com/dmarc.aspx)

### Enregistrements DKIM

Si votre domaine est un domaine accepté dans M365 ou Google Workspace, activez la signature DKIM dans le centre d'administration et publiez les enregistrements CNAME comme indiqué:

**Exemple M365:**

```plain
selector1._domainkey.<YOUR_DOMAIN>.    CNAME    selector1-<YOUR_DOMAIN_DASHED>._domainkey.<TENANT>.onmicrosoft.com.
selector2._domainkey.<YOUR_DOMAIN>.    CNAME    selector2-<YOUR_DOMAIN_DASHED>._domainkey.<TENANT>.onmicrosoft.com.
```

!!! note
    La publication des enregistrements CNAME seuls ne suffit pas - la signature DKIM doit également être **activée** dans le centre d'administration M365 (portail Defender > Authentification des courriels > DKIM).

**Pourquoi**: DKIM prouve que le corps du message n'a pas été altéré pendant le transit. Combiné avec SPF et DMARC, il fournit la plus forte authentification de l'expéditeur.

---

## Configuration multi-domaines

Pour les déploiements gérant plusieurs domaines de courrier (configurés via la page `/mail` du tableau de bord), chaque domaine a besoin de son propre ensemble d'enregistrements DNS.

### Enregistrements par domaine

Pour chaque domaine configuré:

| Enregistrement | Requis |
|--------|----------|
| MX pointant vers `<MAIL_HOSTNAME>` | Oui |
| SPF incluant `ip4:<STARGATE_IP>` | Oui |
| DMARC (`_dmarc.<domain>`) | Recommandé |
| DKIM (de votre fournisseur de courrier) | Recommandé |

L'enregistrement A et l'enregistrement PTR sont partagés (ils pointent vers le serveur Stargate, pas vers des domaines individuels).

### Routage de courrier par domaine

Les enregistrements MX de chaque domaine indiquent à Stargate où livrer les courriels traités. Si différents domaines utilisent différents serveurs Exchange:

```plain
domain1.ch    MX    15    mail.domain1.ch.
domain1.ch    MX    20    exchange1.domain1.ch.

domain2.ch    MX    15    mail.domain2.ch.
domain2.ch    MX    20    exchange2.domain2.ch.
```

Alternativement, configurez des cibles de relais explicites par domaine via la page `/mail` du tableau de bord (champ hôte de relais par domaine) pour remplacer le routage basé sur MX.

---

## Vérification

Après avoir configuré tous les enregistrements, vérifiez-les:

```bash
# Enregistrement A
host <MAIL_HOSTNAME>
# Attendu: <MAIL_HOSTNAME> a l'adresse <STARGATE_IP>

# Enregistrements MX
host -t mx <YOUR_DOMAIN>
# Attendu: Les enregistrements MX de Stargate et d'Exchange sont répertoriés

# Enregistrement SPF
host -t txt <YOUR_DOMAIN> | grep v=spf1
# Attendu: L'enregistrement SPF inclut ip4:<STARGATE_IP>

# PTR (DNS inversé)
host <STARGATE_IP>
# Attendu: <STARGATE_IP> → <MAIL_HOSTNAME>

# DNS inversé à confirmation directe (FCrDNS)
host $(host <STARGATE_IP> | awk '{print $NF}' | sed 's/\.$//')
# Attendu: résout en <STARGATE_IP>

# DMARC
host -t txt _dmarc.<YOUR_DOMAIN>
# Attendu: v=DMARC1; p=...

# DKIM (M365)
host -t cname selector1._domainkey.<YOUR_DOMAIN>
# Attendu: CNAME vers le onmicrosoft.com de votre locataire
```

Exemple de sortie:

```shell
$ host mail.example.ch
mail.example.ch a l'adresse 128.140.117.200

$ host -t mx example.ch
example.ch le courrier est géré par 15 mail.example.ch.
example.ch le courrier est géré par 20 example-ch.mail.protection.outlook.com.

$ host -t txt example.ch | grep v=spf1
example.ch texte descriptif "v=spf1 ip4:128.140.117.200 include:spf.protection.outlook.com -all"

$ host 128.140.117.200
200.117.140.128.in-addr.arpa pointeur de nom de domaine mail.example.ch.

$ host -t txt _dmarc.example.ch
_dmarc.example.ch texte descriptif "v=DMARC1; p=none; rua=mailto:postmaster@example.ch"
```

Outils en ligne:

- [MXToolbox MX Lookup](https://mxtoolbox.com/MXLookup.aspx)
- [MXToolbox SPF Check](https://mxtoolbox.com/spf.aspx) (inclut le nombre de recherches)
- [MXToolbox DMARC Check](https://mxtoolbox.com/dmarc.aspx)
- [Mail-Tester](https://www.mail-tester.com/) (envoyez un courriel de test pour obtenir un score de délivrabilité)

---

## Dépannage

### "Client host rejected: Access denied" (554 5.7.1)

Stalwart rejette le serveur expéditeur car son IP n'est pas dans la liste de relais autorisée. Cela signifie généralement:

- L'enregistrement SPF de votre domaine n'inclut pas la plage IP du serveur expéditeur
- La configuration du courrier n'a pas été rechargée depuis la mise à jour de l'enregistrement SPF

Rechargez la configuration du courrier via la page `/mail` du tableau de bord (soumettez à nouveau la configuration) ou redémarrez le conteneur: `docker compose restart stalwart`

### Courrier marqué comme spam / "ne peut pas vérifier l'expéditeur"

- SPF est manquant ou n'inclut pas l'IP Stargate - ajoutez `ip4:<STARGATE_IP>` à votre enregistrement SPF
- DMARC n'est pas publié - ajoutez au moins `v=DMARC1; p=none`
- L'enregistrement PTR est manquant ou ne correspond pas - configurez le DNS inversé chez votre fournisseur d'hébergement
- DKIM n'est pas activé dans votre locataire M365/fournisseur

### La recherche MX ne renvoie que Stargate

Si Stargate est le seul MX pour un domaine, Stalwart filtre son propre nom d'hôte et n'a pas de cible de relais. Ajoutez un deuxième enregistrement MX pointant vers votre serveur de courrier:

```plain
example.ch.    MX    15    mail.example.ch.          ← Stargate (entrant)
example.ch.    MX    20    example-ch.mail.protection.outlook.com.  ← Exchange (cible de relais)
```

### Nombre de recherches SPF dépassé (> 10)

Chaque `include:` dans l'enregistrement SPF déclenche des recherches DNS supplémentaires. La chaîne totale doit rester en dessous de 10. Solutions:

- Utilisez des entrées `ip4:` / `ip6:` au lieu de `include:` lorsque c'est possible (elles ne comptent pas)
- Aplatissez les inclusions imbriquées à l'aide d'un outil comme [SPF Flattener](https://dmarcly.com/tools/spf-record-flattener)
- Supprimez les entrées `include:` inutilisées d'anciens fournisseurs

### Port 25 bloqué par le fournisseur d'hébergement

Certains fournisseurs de cloud (Azure, certains plans Hetzner) bloquent le port 25 sortant par défaut. Vérifiez auprès de votre fournisseur et demandez une exception. Cela affecte à la fois la livraison entrante (serveurs externes se connectant à votre Stargate) et le relais sortant (Stargate livrant aux cibles MX).
