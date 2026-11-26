# Renouveler et révoquer les certificats de domaine

Chaque domaine dans HIN Gateway possède un certificat de domaine. HIN Gateway l’utilise pour signer et chiffrer les messages du domaine. Dans le tableau de bord, vous pouvez laisser HIN Gateway renouveler automatiquement le certificat, révoquer un certificat et en émettre un nouveau.

## Afficher les certificats de domaine

1. Connectez-vous au tableau de bord HIN Gateway
2. Accédez à **Domains** et sélectionnez le domaine
3. Accédez à la section **Domain certificates**

    ![Section Domain certificates avec un certificat au statut Good](./assets/domain-certs-1.png)

    Pour chaque certificat, la section affiche le **Serial Number**, la période de validité (**Valid from** et **Valid until**) et le **Status**.
    Un certificat qui expire bientôt est marqué **Expiring soon**, et sa date **Valid until** s’affiche en rouge.

## Filtrer les certificats par statut

Utilisez le filtre **Status** en haut à droite de la section pour choisir les certificats affichés :

- **Good :** certificats valides actuellement utilisés
- **Revoked :** certificats révoqués
- **Expired :** certificats dont la période de validité est terminée

![Certificats de domaine filtrés par statut Revoked](./assets/domain-certs-4.png)

## Activer ou désactiver le renouvellement automatique

Le commutateur **Auto renew** détermine si HIN Gateway renouvelle automatiquement le certificat :

- **Activé :** HIN Gateway renouvelle automatiquement le certificat lorsqu’il est sur le point d’expirer. Ce réglage est recommandé
- **Désactivé :** le certificat n’est pas renouvelé. Lorsqu’il expire, vous devez émettre manuellement un nouveau certificat

Cliquez sur le commutateur pour modifier le réglage.

!!! warning
    Si le renouvellement automatique est désactivé et que le certificat expire, HIN Gateway ne peut plus signer ni chiffrer de messages avec celui-ci tant que vous n’avez pas émis de nouveau certificat.

## Révoquer un certificat

Révoquez un certificat si vous ne souhaitez plus qu’il soit utilisé, par exemple si vous soupçonnez que la clé est compromise.

1. Dans la section **Domain certificates**, recherchez le certificat à révoquer
2. Cliquez sur l’icône rouge **Revoke** (cercle barré). Une fenêtre de confirmation s’ouvre

    ![Confirmation de la révocation du certificat](./assets/domain-certs-2.png)

3. Cliquez sur **Revoke** pour confirmer, ou sur **Cancel** pour conserver le certificat.

!!! warning
    La révocation d’un certificat est irréversible. Le certificat a ensuite le statut **Revoked** et apparaît sous le filtre de statut **Revoked**.

## Émettre un nouveau certificat

Vous pouvez émettre un nouveau certificat à partir d’un certificat expiré ou révoqué.

1. Dans le filtre **Status**, sélectionnez **Expired** ou **Revoked**.
2. Recherchez le certificat et cliquez sur l’icône **Renew** (horloge avec une flèche). Une fenêtre de confirmation s’ouvre.

    ![Confirmation du renouvellement du certificat](./assets/domain-certs-3.png)

3. Cliquez sur **Renew** pour confirmer, ou sur **Cancel** pour annuler.

HIN Gateway génère de nouvelles clés publique et privée et émet le nouveau certificat. Si l’ancien certificat était encore valide, il est révoqué.

!!! note
    Plusieurs heures peuvent être nécessaires pour que le nouveau certificat parvienne à tous les autres participants. Pendant ce temps, vous pouvez toujours déchiffrer les messages avec votre clé privée actuelle.

## Vérifier le nouveau certificat

Sélectionnez **Good** dans le filtre **Status**. Le nouveau certificat est affiché avec le statut **Good**, un nouveau **Serial Number** et une nouvelle période de validité.
