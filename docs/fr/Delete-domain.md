# Supprimer un domaine

Vous pouvez supprimer un domaine de HIN Gateway lorsqu’il ne doit plus envoyer ni recevoir d’e-mails via la passerelle, par exemple après la mise hors service du domaine ou son transfert vers un autre système.

Ces étapes s’appliquent aux deux types de domaines affichés sur la page **Domains** : les domaines **Secure** (domaines HIN Secure) et les domaines **Routed**. Pour en savoir plus sur les domaines Routed, consultez [Gestion des domaines routés (Routed Domains) dans HIN Gateway](Routed-domains.md).

## Avant la suppression

- Assurez-vous qu’aucun système n’envoie encore d’e-mails pour le domaine via HIN Gateway. Une fois le domaine supprimé, HIN Gateway ne traite plus les messages qui le concernent
- Décidez si le certificat du domaine doit être révoqué. La révocation est irréversible

## Supprimer le domaine

1. Connectez-vous au tableau de bord HIN Gateway.
2. Accédez à **Domains** et sélectionnez le domaine à supprimer. La page **Domain details** s’ouvre.
3. Cliquez sur l’icône rouge **Delete** (corbeille) à côté du statut du domaine.

    ![Page Domain details avec l’icône de suppression](./assets/delete-domain-1.png)

    Une fenêtre de confirmation s’ouvre.

    ![Confirmation de la suppression du domaine](./assets/delete-domain-2.png)

4. Choisissez si le certificat du domaine doit être révoqué :

    - **Revoke domain's certificate** sélectionné : le certificat du domaine est également révoqué lors de la suppression du domaine
    - **Revoke domain's certificate** non sélectionné : le domaine est supprimé, mais son certificat n’est pas révoqué

5. Cliquez sur **Yes** pour supprimer le domaine, ou sur **No** pour annuler.

Le domaine est retiré de la liste **Domains**.

!!! warning
    Si vous sélectionnez **Revoke domain's certificate**, le certificat est révoqué et ne peut plus être utilisé. La révocation est irréversible.
