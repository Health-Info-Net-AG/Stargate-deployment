# Gestion des domaines routés (Routed Domains) dans HIN Gateway

HIN Gateway peut également traiter le trafic de messagerie de domaines qui ne sont pas des domaines HIN Secure. C’est une configuration courante chez les clients qui exploitent leur propre infrastructure de serveurs de messagerie sur site.
Cette fonctionnalité est intégrée à HIN Gateway et permet aux clients d’adapter leur configuration de messagerie à leurs propres besoins.

Dans HIN Gateway, ces domaines sont appelés domaines **Routed**.
Les e-mails d’un domaine Routed transitent par HIN Gateway sans traitement pour la messagerie sécurisée : ils sont simplement transmis à l’hôte de relais suivant.


## Ajouter un domaine Routed

Accédez à la page **Domains**, cliquez sur **Add domain**, saisissez le nom de domaine, puis cliquez sur **Save**.

<br> ![Screenshot](assets/routed-domains/add-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Configurer le domaine Routed

Activez le domaine et configurez-le de la même manière qu’un domaine HIN Secure. Pour les étapes détaillées, consultez [Étape 14 - Configurer le transport du courrier](Installation-guide.md#etape-14-configurer-le-transport-du-courrier) dans le guide d’installation.


<br> ![Screenshot](assets/routed-domains/activate-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
