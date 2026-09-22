# Gestion des domaines routés (Routed Domains) dans HIN Gateway

HIN Gateway peut également gérer le trafic pour des domaines qui ne sont pas des domaines HIN Secure. Il s'agit d'une configuration courante pour les clients qui exploitent leur propre infrastructure de serveur de messagerie sur site.
Cette fonctionnalité est intégrée à HIN Gateway et offre aux clients la flexibilité nécessaire pour adapter précisément leur environnement de communication à leurs besoins.

Dans HIN Gateway, ces domaines sont appelés domaines **Routed**.
Un domaine Routed est un domaine dont le trafic transite par HIN Gateway sans être traité pour la messagerie sécurisée - il est principalement transmis à l'hôte de relais suivant.


### Ajouter un domaine Routed

Accédez à la page **Domains**, cliquez sur **Add domain**, saisissez le nom de domaine, puis cliquez sur **Save**.

<br> ![Screenshot](assets/routed-domains/add-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Configurer le domaine Routed

Activez le domaine et configurez-le de la même manière que tout autre domaine HIN Secure. Pour les étapes de configuration détaillées, consultez le [guide de configuration du transport de courrier](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/#step-14-configure-mail-transport).


<br> ![Screenshot](assets/routed-domains/activate-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }
