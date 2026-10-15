## v1.1.7

*Publiée le 14 octobre 2026.*

### Nouveautés et améliorations

- Les relais sortants peuvent désormais s'authentifier avec un nom d'utilisateur et un mot de passe pour chaque domaine.
- Les relais entrants peuvent désormais s'authentifier avec un nom d'utilisateur et un mot de passe pour chaque domaine.
- Étiquette de confidentialité Outlook: les e-mails marqués comme confidentiels dans le champ d'étiquette de confidentialité de Microsoft sont désormais distribués via HIN Mail avec chiffrement aux personnes qui ne sont pas membres HIN.
- Synchronisation de l'heure: HIN Gateway utilise désormais NTP pour maintenir son horloge synchronisée avec des serveurs de temps de confiance. NTP peut être configuré dans le tableau de bord.
- Transfert des logs: les logs peuvent désormais être envoyés à Loki au moyen d'un jeton d'API.
- Migration depuis v0.5.x: un script de migration exporte la clé et le certificat S/MIME lors du passage de v0.5.x à v0.6.x ou supérieure.
- Paramètres réseau par défaut: le serveur DNS par défaut est désormais 8.8.8.8 (auparavant 1.1.1.1). Le serveur DNS peut être modifié lors de la configuration.

### Corrections

- Correction des redémarrages répétés (jusqu'à trois de suite) après une modification des paramètres réseau.
- Correction d'une erreur lors de l'onboarding lorsque l'importation du certificat démarrait avant la fin de la synchronisation de l'Iris Agent.
- Les domaines sont désormais nettoyés des espaces superflus et convertis en minuscules lors de leur ajout.
- Correction du message de confirmation après la mise à jour d'un pair.
- La notification de nouvelle version est désormais traduite dans toutes les langues prises en charge.

## v0.6.2

*Publiée le 24 septembre 2026.*

Cette version corrective renforce la sécurité de HIN Gateway, corrige la version de Stalwart et désactive le filtrage anti-spam.

### Nouveautés et améliorations

- Intègre Stalwart v0.16.23, compatible avec le dernier jeu de règles du filtre anti-spam.
- Désactivation du jeu de règles anti-spam et du SpamFilter, afin qu'une nouvelle version du jeu de règles en amont ne puisse pas casser une version figée.

### Corrections

- Mise à jour de la gestion du filtre anti-spam dans le script de provisionnement et amélioration de la journalisation des erreurs.
- Mise à jour de l'image Stalwart vers la version v0.16.23 et ajout d'une fonction de suppression des serveurs DNSBL.

## v0.6.1

*Publiée le 4 septembre 2026.*

Cette version de maintenance renforce la sécurité de HIN Gateway, corrige le traitement des en-têtes d'e-mail et améliore la documentation sur les mises à jour et les migrations.

### Nouveautés et améliorations

- **Sécurité:** l'accès externe aux ports des services internes a été restreint, et les paramètres d'authentification ainsi que les autorisations ont été renforcés.
- **Mises à jour et retour arrière:** ajout d'instructions pour mettre à jour HIN Gateway et revenir à une version précédente, disponibles en anglais, en allemand, en français et en italien.
- **Guide de migration:** mise à jour des vérifications des e-mails avant et après la migration, et ajout des traductions du guide multi-domaines.

### Corrections

- Correction du traitement des en-têtes d'e-mail spécifiques à HIN.
- Ajout de l'image de disque de données VMware manquante aux téléchargements de la v0.6.0.

## v0.6.0

*Publiée le 31 août 2026.*

Cette version apporte la prise en charge des migrations multi-domaines, la configuration des relais par domaine, l'authentification des e-mails (par exemple DKIM et ARC) ainsi que des améliorations de l'installation, de la sécurité et de la stabilité.

### Nouveautés et améliorations

- **Configurations multi-domaines:** plusieurs domaines peuvent désormais être configurés sur un seul HIN Gateway ou y être migrés. Le guide mis à jour couvre les migrations complètes et progressives, y compris les scénarios de retour arrière.
- **Configuration par domaine:** la configuration des relais est désormais disponible pour chaque domaine.
- **Authentification des e-mails:** la signature DKIM et ARC ainsi que la vérification DKIM, ARC, SPF et DMARC peuvent désormais être configurées pour chaque domaine. Les enregistrements DNS nécessaires sont affichés directement dans HIN Gateway.
- **Installation et migration:** la documentation mise à jour couvre désormais les nouvelles installations, les migrations mono-domaine et multi-domaines, l'intégration Exchange, le routage du courrier, le réseau et les tests TLS.
- **Migration vers l'appliance:** une procédure documentée permet de transférer une installation Docker Compose existante vers l'appliance HIN Gateway basée sur une image.
- **Sauvegarde et restauration:** les données persistantes sont désormais stockées à un emplacement uniforme, la restauration est plus sûre et des avertissements s'affichent lorsque les versions de la sauvegarde et de la cible diffèrent.
- **Diagnostic et sécurité:** les contrôles de santé, la journalisation et la collecte des données de diagnostic ont été améliorés. Les scripts d'installation et de restauration protègent désormais mieux les identifiants et les données de sauvegarde.

### Corrections

- Amélioration de l'initialisation initiale des paramètres Vault et WireGuard.
- Amélioration du démarrage des services sur les machines virtuelles plus lentes.
- Correction de cas particuliers affectant les opérations de sauvegarde et de restauration.
- Correction de résultats inexacts des contrôles de santé et de la gestion des valeurs de repli de la configuration.

### Informations importantes pour les migrations vers l'appliance

Pour transférer une installation Docker Compose existante vers l'appliance basée sur une image, suivez le guide de migration dédié. La restauration d'une sauvegarde remplace toutes les données de l'appliance cible. Si son adresse IP publique change, HIN doit mettre à jour l'enregistrement WireGuard central.

## v0.5.3

*Publiée le 29 juillet 2026. Correctif appliqué le 5 août 2026.*

Cette version améliore la distribution des e-mails, la gestion des certificats, le tableau de bord et le dépannage. SEAL n'est pas modifié.

### Correctif du 5 août 2026

Correction d'un problème dans le processus d'importation des certificats, où le domaine n'était pas correctement associé au pair HIN Gateway correspondant.

Le correctif a été appliqué aux services centraux. Les installations locales sur machine virtuelle n'étaient pas concernées et n'ont nécessité aucune mise à jour.

### Nouveautés et améliorations

- Des relais distincts peuvent désormais être configurés pour les expéditeurs et les destinataires.
- Les e-mails destinés à des destinataires hors du réseau HIN peuvent être envoyés via le relais SMTP configuré.
- L'ancienne limite horaire de traitement des e-mails a été supprimée.
- La correspondance des expéditeurs et des destinataires a été améliorée pour les e-mails entrants et sortants.
- La propriété du domaine est désormais vérifiée avant l'émission d'un certificat S/MIME.
- Les certificats des pairs peuvent désormais être recherchés et triés.
- Les certificats TLS peuvent être générés directement depuis le tableau de bord.
- Une recherche et une pagination ont été ajoutées à la vue d'ensemble des pairs.
- La recherche dans les logs est désormais plus simple.
- Un avertissement s'affiche lorsque la clé privée n'a pas été importée.
- Les messages d'erreur et les informations de diagnostic ont été améliorés.

### Corrections

- Amélioration de la sélection du certificat lors de l'envoi d'e-mails chiffrés.
- Correction du traitement des messages chiffrés signés avec des certificats révoqués ou non fiables.
- Correction d'un problème lié aux jetons d'actualisation de session.
- Correction de plusieurs erreurs dans les formulaires de configuration et de gestion des domaines.
- Correction de la sélection de l'indicatif de pays et de la validation des champs.
- Correction d'un problème lors de la régénération d'un code d'activation.
- Correction du traitement de certaines informations de signataire S/MIME.
- Ajout des informations de connexion manquantes dans les journaux de distribution du tunnel.
- Les paramètres réseau sont désormais correctement réinitialisés après un changement d'adresse IP de la machine virtuelle.

## v0.5.1

Notre première version.
