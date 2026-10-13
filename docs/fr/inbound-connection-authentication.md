# Authentification des connexions entrantes

L’authentification des connexions entrantes permet à un système externe, tel qu’un relais de messagerie, une application ou un client de messagerie, d’envoyer des e-mails pour l’un de vos domaines via HIN Gateway en se connectant avec un nom d’utilisateur et un mot de passe. C’est utile lorsque l’expéditeur ne peut pas être autorisé uniquement sur la base de son adresse IP.

Fonctionnement:

- L’expéditeur se connecte à HIN Gateway sur le port de soumission **587** et s’authentifie avec SMTP AUTH
- Les identifiants sont créés par domaine dans le tableau de bord HIN Gateway


## Avant de commencer

- Vous devez avoir accès au tableau de bord HIN Gateway
- Le domaine d’envoi doit déjà être ajouté dans HIN Gateway et activé (onboarded)
- TLS doit être activé pour le domaine. Les mots de passe ne sont acceptés que via TLS, les identifiants ne fonctionnent donc pas sans certificat TLS
- Vous devez avoir accès à la configuration du système d’envoi (MTA / application), car vous y saisirez les nouveaux identifiants

## Créer des identifiants

1. Connectez-vous au tableau de bord HIN Gateway.
2. Ouvrez **Domains** et sélectionnez le domaine d’envoi.
3. Faites défiler la page jusqu’à la section **SMTP authentication (port 587)**.

    ![Section SMTP authentication](./assets/inbound-basic-auth-1.png)

    Les identifiants qui existent déjà pour le domaine sont répertoriés ici.

    !!! warning "TLS doit être activé"
        Si le domaine n’a pas encore de certificat TLS, la section affiche le message **No TLS certificate yet**. Les identifiants ne fonctionnent qu’une fois TLS activé, car les mots de passe ne sont acceptés que via TLS.

        ![Avertissement: aucun certificat TLS](./assets/inbound-basic-auth-4.png)

        Pour activer TLS, ouvrez la section **Configure TLS** sur la même page du domaine et ajoutez un certificat, ou cliquez sur **Generate TLS certificate** pour en générer un. Revenez ensuite à cette section.

    Le commutateur **Verify a trusted network** détermine depuis où les identifiants peuvent être utilisés. Lorsqu’il est sur **Off**, les identifiants fonctionnent depuis n’importe quelle adresse IP. Activez-le si vous souhaitez limiter les connexions aux `Trusted networks`.

4. Cliquez sur **Add credential**. Un formulaire avec deux champs s’ouvre:

    ![Formulaire Add credential](./assets/inbound-basic-auth-2.png)

    Choisissez l’une des options suivantes:

    - **Générer les identifiants automatiquement (recommandé):** laissez les champs **Username** et **Password** vides. HIN Gateway génère un nom d’utilisateur et un mot de passe aléatoire robuste
    - **Définir vos propres identifiants:** saisissez **Username** et **Password**. Le mot de passe doit comporter au moins 16 caractères.

5. Cliquez sur **Create**.
6. Copiez le nom d’utilisateur et le mot de passe.

    ![Copier les nouveaux identifiants](./assets/inbound-basic-auth-3.png)

    !!! warning
        Le mot de passe n’est affiché **qu’une seule fois**. Cliquez sur **Copy** et conservez-le en lieu sûr (par exemple dans un gestionnaire de mots de passe) avant de continuer. En cas de perte du mot de passe, utilisez **Rotate password** pour en émettre un nouveau.

7. Cliquez sur **Done**. Les nouveaux identifiants apparaissent maintenant dans la liste.

## Configurer le système d’envoi

Saisissez les identifiants dans le MTA ou l’application d’envoi:

| Paramètre         | Valeur                                         |
|-------------------|------------------------------------------------|
| Serveur SMTP      | L’adresse IP de votre HIN Gateway              |
| Port              | `587`                                          |
| Chiffrement       | STARTTLS                                       |
| Authentification  | Nom d’utilisateur et mot de passe (SMTP AUTH)  |
| Nom d’utilisateur | Le nom d’utilisateur de l’étape 6              |
| Mot de passe      | Le mot de passe de l’étape 6                   |

L’adresse de l’expéditeur (`MAIL FROM`) doit appartenir au domaine pour lequel les identifiants ont été créés, sinon le message est rejeté.

## Gérer les identifiants existants

Chaque jeu d’identifiants de la section **SMTP authentication (port 587)** propose deux actions:

- **Rotate password:** génère un nouveau mot de passe. L’ancien mot de passe cesse de fonctionner, mettez donc immédiatement à jour le système d’envoi.
- **Delete:** supprime les identifiants. Tout système qui les utilise encore ne peut plus envoyer via HIN Gateway.


!!! tip
    Créez des identifiants distincts pour chaque système d’envoi. Vous pourrez ainsi renouveler ou révoquer l’accès d’un système sans affecter les autres.
