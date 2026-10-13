# Configurer NTP

HIN Gateway maintient son horloge à l’heure exacte grâce à NTP (Network Time Protocol). Une horloge exacte est indispensable: la validation des certificats, la signature des messages et les sessions de connexion échouent si l’horloge dérive.

Fonctionnement:

- Par défaut, HIN Gateway synchronise son heure avec `ntp.metas.ch`
- Si votre réseau n’autorise pas le trafic NTP sortant vers Internet, ou si votre organisation exploite ses propres serveurs de temps, vous pouvez remplacer le serveur par défaut par un ou plusieurs serveurs de temps personnalisés
- Vous pouvez ajouter plusieurs serveurs de temps. Si l’un d’eux n’est pas joignable, HIN Gateway utilise le suivant

## Avant de commencer

- Vous devez avoir accès au tableau de bord HIN Gateway
- Demandez le nom d’hôte du ou des serveurs de temps à votre administrateur réseau
- Assurez-vous que HIN Gateway peut joindre le ou les serveurs de temps sur le port UDP 123

## Vérifier la synchronisation actuelle

1. Connectez-vous au tableau de bord HIN Gateway.
2. Ouvrez **Settings** et faites défiler la page jusqu’à la section **Time synchronisation**.

    ![Section Time synchronisation avec le serveur de temps par défaut](./assets/ntp-config-1.png)

    La ligne d’état indique si l’horloge est synchronisée (**In sync**), ainsi que l’adresse IP du serveur de temps utilisé, le décalage (offset) et la strate (stratum). **Time servers** indique les serveurs configurés. Sans serveur personnalisé, elle affiche **Using the default time server (ntp.metas.ch)**.

## Ajouter des serveurs de temps personnalisés

1. Dans la section **Time synchronisation**, cliquez sur **Edit**. Un champ vide apparaît pour le premier serveur de temps.

    ![Section Time synchronisation en mode édition](./assets/ntp-config-2.png)

2. Saisissez le nom d’hôte du serveur de temps (par exemple `ntp.example.com`).
3. Utilisez le commutateur à côté du champ pour choisir le type d’entrée:
    - **Server**: un seul serveur NTP
    - **Pool**: un pool NTP, c’est-à-dire un nom d’hôte qui renvoie vers plusieurs serveurs (par exemple `ch.pool.ntp.org`). HIN Gateway utilise plusieurs serveurs du pool
4. Pour ajouter un autre serveur de temps, cliquez sur **Add server** et répétez les étapes 2 et 3. Vous pouvez combiner pools et serveurs.

    ![Section Time synchronisation avec un pool et un serveur](./assets/ntp-config-3.png)

    Pour supprimer une entrée, cliquez sur l’icône moins à côté de celle-ci.

5. Cliquez sur **Save**.

HIN Gateway synchronise désormais son heure avec les serveurs de temps configurés au lieu du serveur par défaut.

## Vérifier la configuration

Contrôlez la ligne d’état de la section **Time synchronisation**. Elle doit afficher **In sync** et l’adresse IP de l’un de vos serveurs de temps. Pour forcer une synchronisation immédiate, cliquez sur **Sync now**.

## Revenir au serveur de temps par défaut

Cliquez sur **Edit**, supprimez toutes les entrées avec l’icône moins, puis cliquez sur **Save**. HIN Gateway utilise alors de nouveau `ntp.metas.ch`.
