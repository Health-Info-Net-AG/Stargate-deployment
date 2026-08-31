# Authentification des e-mails (DKIM / ARC / SPF / DMARC)

**Module :** HIN Mail Gateway -> Domains -> *[domaine]* -> Email authentication
**S'applique à :** Aux administrateurs de domaine qui configurent la signature sortante et la vérification entrante pour un domaine de messagerie

---

La section **Email authentication** contrôle la manière dont l'authenticité des e-mails est prouvée, et avec quelle rigueur l'authenticité des e-mails entrants est vérifiée, c'est-à-dire la vérification DKIM/ARC/SPF/DMARC. Elle génère également les enregistrements DNS TXT qui doivent être publiés afin que les serveurs de messagerie externes puissent vérifier le courrier de votre domaine.

On accède à cette section via :

```
Domains -> sélectionner un domaine -> Email authentication
```

Le panneau comporte cinq sous-sections :

1. DKIM
2. ARC
3. SPF
4. DMARC
5. Enregistrements DNS à publier

Les modifications ne sont appliquées qu'après avoir cliqué sur le bouton **Save** en bas de la page.

![Screenshot](assets/Email-authentication.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

---

### Ce que fait chaque protocole

| Protocole | Direction | Objectif |
|---|---|---|
| **DKIM** (DomainKeys Identified Mail) | Signature sortante / Vérification entrante | Signe cryptographiquement les messages sortants avec une clé privée, associée à une clé publique publiée dans le DNS, afin que les destinataires puissent confirmer que le message n'a pas été altéré en transit et provient réellement de ce domaine |
| **ARC** (Authenticated Received Chain) | Signature de la vérification entrante pour le relais suivant | Préserve les résultats d'authentification DKIM/SPF d'origine lorsqu'un message transite par des intermédiaires (listes de diffusion, services de transfert, etc.) qui casseraient autrement les signatures DKIM |
| **SPF** (Sender Policy Framework) | Vérification entrante | Vérifie que l'adresse IP du serveur de messagerie expéditeur est autorisée à envoyer du courrier pour le domaine de l'expéditeur, sur la base d'un enregistrement DNS publié par ce domaine |
| **DMARC** (Domain-based Message Authentication, Reporting & Conformance) | Vérification entrante | Relie les résultats DKIM et SPF entre eux et indique aux serveurs destinataires la conduite à tenir |

Bien configurer DKIM et DMARC pour **votre propre domaine** protège votre délivrabilité et votre marque contre l'usurpation. Les paramètres de **vérification** (menus déroulants de vérification DKIM, ARC, SPF, DMARC) contrôlent en revanche le niveau de confiance que la passerelle accorde à ces signaux pour le courrier **entrant** provenant d'autres domaines.

---

### DKIM

| Champ | Description |
|---|---|
| **Enable DKIM signing** | Lorsqu'il est actif, la passerelle signe tout le courrier sortant de ce domaine avec la clé privée configurée. Activez cette option avant de publier l'enregistrement DNS DKIM |
| **Generate DKIM key** (bouton, en haut à droite) | Génère une nouvelle paire de clés RSA-2048 pour ce domaine et remplit le champ Private key (PEM) |
| **DKIM verification** | Contrôle avec quelle rigueur un e-mail est vérifié par rapport à l'enregistrement DKIM publié de l'expéditeur |
| **Selector** | Le sélecteur DKIM (ex. `s1`) utilisé pour publier et rechercher la clé publique à l'adresse `<selector>._domainkey.<domain>`. Ne modifiez ceci que si vous devez faire fonctionner plusieurs clés en parallèle (par exemple lors d'une rotation de clé) : chaque sélecteur nécessite son propre enregistrement DNS TXT |
| **Private key (PEM)** | La clé privée RSA utilisée pour signer le courrier sortant. Vous pouvez soit cliquer sur **Generate DKIM key** pour en créer une, soit coller votre propre clé privée RSA-2048 au format PEM |

### Comment configurer DKIM pour un nouveau domaine
1. Cliquez sur **Generate DKIM key** (ou collez une clé PEM RSA-2048 existante que vous gérez en externe)
2. Laissez **Selector** à sa valeur par défaut (`s1`) sauf raison particulière de le modifier
3. Basculez **Enable DKIM signing** sur Active
4. Cliquez sur **Save**
5. Copiez l'enregistrement TXT `s1._domainkey.<domain>` généré depuis le champ **DNS records to publish** (voir §7) et ajoutez-le chez votre fournisseur DNS
6. Une fois l'enregistrement DNS propagé, le courrier signé par ce domaine portera une signature DKIM valide

### Comment effectuer une rotation d'une clé DKIM
1. Cliquez sur **Replace key** à côté de Private key (PEM)
2. Générez une nouvelle clé (ou collez-en une nouvelle)
3. Publiez l'enregistrement TXT du nouveau sélecteur dans le DNS *avant* de l'enregistrer/l'activer en production, afin d'éviter une période durant laquelle le courrier signé ne peut pas être vérifié
4. Enregistrez, puis supprimez l'enregistrement DNS de l'ancien sélecteur une fois que vous avez confirmé que la nouvelle clé signe correctement

---

### ARC

| Champ | Description |
|---|---|
| **ARC verification** (menu déroulant) | Contrôle avec quelle rigueur les chaînes ARC entrantes sont validées |
| **Enable ARC signing** | Lorsqu'il est actif, la passerelle ajoute un sceau ARC au courrier transféré, préservant les résultats d'authentification si le message est relayé ultérieurement par un autre système |
| **Reuse DKIM key** (bascule) | Lorsqu'il est actif, la signature ARC utilise la même clé RSA que celle configurée dans la section DKIM ci-dessus, au lieu de nécessiter une clé distincte. Recommandé sauf besoin spécifique de garder les deux signatures cryptographiquement séparées |

---

### SPF

| Champ | Description |
|---|---|
| **SPF verification** | Contrôle avec quelle rigueur le courrier entrant est vérifié par rapport à l'enregistrement SPF publié du domaine expéditeur |

> **Remarque :** Ce panneau contrôle uniquement la *vérification* du SPF entrant. Il ne génère pas d'enregistrement SPF TXT sortant pour votre propre domaine (aucune entrée SPF n'apparaît dans la §7 "DNS records to publish"). Si ce domaine envoie du courrier via un relais externe (par exemple Microsoft 365, configuré dans **Mail routing -> Outbound relay**), assurez vous que le mécanisme `include:` de ce fournisseur est déjà publié dans le propre enregistrement SPF de votre domaine chez votre fournisseur DNS, indépendamment de cette passerelle.

---

### DMARC

| Champ | Description |
|---|---|
| **DMARC verification** | Contrôle avec quelle rigueur le courrier entrant est vérifié par rapport à la politique DMARC de l'expéditeur |


### Valeur de vérification


| Libellé dans l'interface | Valeur | Comportement |
|---|---|---|
| **Disabled** | `disable` | N'est pas vérifié du tout. Le mécanisme ne s'exécute pas |
| **Optional** | `relaxed` | Vérifié et **signalé** dans `Authentication-Results`. Le message est **toujours accepté**, qu'il réussisse ou échoue |
| **Required** | `strict` | Vérifié et signalé, et le message est **rejeté** en cas d'échec définitif. Sinon, il est accepté |

En résumé : Disabled signifie qu'aucune vérification n'est effectuée ; Optional et Required vérifient tous deux et consignent le résultat. La seule différence entre les deux est l'application : **Optional ne rejette jamais**, **Required rejette en cas d'échec définitif**.

Ce qui constitue un "échec définitif" pour Required (par mécanisme) :
- **DKIM** : le message comporte des signatures et *toutes* échouent. Aucune signature du tout donne `none`, ce qui n'est pas un échec, donc pas de rejet.
- **SPF** : un échec définitif `-all`. SoftFail/neutral/none/temp-error sont signalés mais ne provoquent pas de rejet.
- **DMARC** : ni DKIM ni SPF ne s'aligne, *et* il y a un verdict d'échec réel. L'absence d'enregistrement DMARC publié donne `none`, donc pas de rejet.
- **ARC** : la chaîne ARC échoue à la validation. L'absence de chaîne donne `none`, donc pas de rejet.

Deux remarques importantes :
- **DKIM s'exécute toujours en interne**, car DMARC en a besoin. Le paramètre DKIM contrôle uniquement si un résultat `dkim=` est consigné et si un échec DKIM peut entraîner un rejet ; il ne modifie jamais le verdict DMARC.
- Chaque mécanisme est indépendant, vous pouvez donc par exemple exécuter **DMARC = Required** avec **DKIM/SPF = Optional** : le courrier problématique est rejeté sur la base du verdict DMARC, et vous obtenez tout de même des lignes `dkim=`/`spf=` individuelles dans l'en-tête pour plus de visibilité.


---

### Enregistrements DNS à publier

Cette zone affiche les enregistrements TXT exacts que vous devez créer chez le fournisseur DNS de votre domaine afin que les serveurs de messagerie externes puissent vérifier le courrier de ce domaine. Les enregistrements affichés se mettent à jour automatiquement en fonction du sélecteur DKIM et des paramètres de politique DMARC ci-dessus.

| Enregistrement | Hôte | Type | Valeur |
|---|---|---|---|
| Clé publique DKIM | `<selector>._domainkey.<domain>` (ex. `s1._domainkey.vrgnservices.eu`) | TXT | `v=DKIM1; k=rsa; p=<public key>` |
| Politique DMARC | `_dmarc.<domain>` (ex. `_dmarc.vrgnservices.eu`) | TXT | `v=DMARC1; p=<policy>` (ex. `p=none`) |

Utilisez l'icône de copie en haut à droite de chaque bloc d'enregistrement pour copier sa valeur exacte. Collez chaque enregistrement comme un nouvel enregistrement TXT chez votre registraire/fournisseur DNS, en utilisant **Host/Name** et **Value** tels qu'affichés.

> Les modifications DNS peuvent prendre de quelques minutes à 48 heures pour se propager, selon les paramètres TTL de votre fournisseur. L'application DKIM/DMARC ne devrait pas être renforcée (par exemple en activant la signature ou en faisant évoluer la politique DMARC au delà de `none`) avant d'avoir confirmé que les enregistrements se sont propagés et se résolvent correctement.

---

## Enregistrer les modifications

Aucun des paramètres ci-dessus ne prend effet tant que vous n'avez pas cliqué sur le bouton orange **Save** en bas de la page. Save applique ensemble toutes les modifications de DKIM, ARC, SPF et DMARC ; il n'existe pas d'enregistrement par section.

---

## Dépannage

| Symptôme | Cause probable |
|---|---|
| Le courrier sortant échoue à la vérification DKIM chez les serveurs destinataires | La signature DKIM est activée mais l'enregistrement DNS TXT n'est pas encore publié/propagé, ou il y a une incohérence de sélecteur entre la passerelle et le DNS. |
| Le sceau ARC est absent sur le courrier transféré | **Enable ARC signing** est désactivé, ou **Reuse DKIM key** est désactivé sans qu'une clé ARC distincte soit configurée. |
| Impossible de voir la clé privée DKIM pour la copier ailleurs | C'est voulu : une fois enregistrée, la clé est masquée (`<hidden>`) et ne peut plus être réaffichée. Utilisez **Replace key** pour en émettre une nouvelle si vous devez la transférer vers un système qui n'en a pas déjà une copie. |
| Du courrier légitime commence à être mis en quarantaine/rejeté après un changement de politique DMARC | Une source d'envoi légitime n'est pas encore alignée sur DKIM/SPF. Revenez à la politique `none`, identifiez la source défaillante, corrigez l'alignement, puis renforcez à nouveau la politique. |
