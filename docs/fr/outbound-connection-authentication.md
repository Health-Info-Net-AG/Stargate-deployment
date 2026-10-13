# Authentification des connexions sortantes

Lorsque HIN Gateway transmet les messages d’un domaine au saut suivant (par exemple un relais de messagerie ou un serveur de messagerie), ce dernier peut exiger que l’expéditeur se connecte avant d’accepter le courrier. L’authentification des connexions sortantes permet à HIN Gateway de s’authentifier auprès du saut suivant avec un nom d’utilisateur et un mot de passe (SMTP AUTH).

Fonctionnement:

- Chaque domaine dispose de son propre **Outbound relay** (hôte et port) dans le tableau de bord HIN Gateway
- Lorsque **Require authentication** est actif, HIN Gateway se connecte au relais sortant avec les identifiants que vous avez saisis avant de transmettre un message

## Avant de commencer

- Vous devez avoir accès au tableau de bord HIN Gateway
- Le domaine doit déjà être ajouté dans HIN Gateway et activé (onboarded)
- Demandez le nom d’utilisateur et le mot de passe à l’administrateur du côté destinataire (le relais ou le serveur de messagerie qui exige l’authentification)

## Configurer les identifiants

1. Connectez-vous au tableau de bord HIN Gateway.
2. Ouvrez **Domains** et sélectionnez le domaine.
3. Faites défiler la page jusqu’à **Mail routing** et repérez la section **Outbound**.

    ![Section Outbound avec authentification inactive](./assets/outbound-basic-auth-1.png)

    Vérifiez que **Outbound relay** affiche l’hôte et le port corrects du saut suivant (par exemple `relay.example.com:25`). Ces identifiants sont utilisés uniquement pour ce relais.

4. Cliquez sur le commutateur **Require authentication** pour qu’il affiche **Active**. Les champs **Username** et **Password** apparaissent.

    ![Section Outbound avec authentification active](./assets/outbound-basic-auth-2.png)

5. Saisissez le **Username** et le **Password** configurés du côté destinataire. Cliquez sur l’icône en forme d’œil pour afficher le mot de passe et vérifier qu’il ne contient pas de faute de frappe.
6. Faites défiler la page vers le bas et cliquez sur **Save**.

Désormais, HIN Gateway s’authentifie auprès du relais sortant chaque fois qu’il transmet un message pour ce domaine.

## Vérifier la configuration

Envoyez un message de test via HIN Gateway à un destinataire situé derrière le relais sortant et vérifiez qu’il arrive. Si ce n’est pas le cas, ouvrez **Logs** dans le tableau de bord et recherchez les erreurs d’authentification renvoyées par le relais. Les causes les plus fréquentes sont:

- Nom d’utilisateur ou mot de passe incorrect
- Le relais ne prend pas en charge ou n’autorise pas SMTP AUTH sur le port configuré
- L’hôte ou le port de l’**Outbound relay** est incorrect

## Modifier ou supprimer les identifiants

- **Changer le mot de passe:** lorsque le côté destinataire change le mot de passe, saisissez le nouveau dans le champ **Password** et cliquez sur **Save**. D’ici là, l’authentification des messages envoyés au relais échoue.
- **Désactiver l’authentification:** cliquez sur **Require authentication** pour qu’il affiche **Inactive**, puis cliquez sur **Save**. HIN Gateway se connecte alors au relais sans authentification.
