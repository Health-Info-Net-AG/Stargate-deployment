# Scénario de migration multi-domaines

*MGW → HIN Gateway - architecture du flux de messagerie, déploiement par étapes et plan de retour arrière*


## Phase&nbsp;1 Début - Situation de référence (tous les domaines sur MGW)

**État de référence**

- Tous les domaines transitent par **MGW**. Exemple: domain1.ch, domain2.ch, domain3.ch, un-domain1.ch, un-domain2.ch
- Préparation du déploiement de HIN Gateway - pas encore de trafic en production
- Les enregistrements DNS MX / SPF pointent toujours vers l’**adresse IP publique A** (MGW) - ceci dans le cas où MGW serait le point d’entrée du trafic ou le dernier MTA

!!! info "Liste de contrôle préalable"
    - Établir une situation de référence pour la capacité actuelle de MGW et les journaux des flux de messagerie
    - Vérifier la connectivité de Stargate Lab avec Online Protect / Exchange Online / le serveur de messagerie sur site
    - Mettre d’accord les parties prenantes sur le calendrier de migration et le plan de communication
    - Examiner la documentation relative au pare-feu et aux ports avant l’attribution de l’adresse IP publique B (phase&nbsp;2, étape&nbsp;1)

 <br> ![Start-Baseline](assets/multi-domain-scenario/Phase1-start-baseline.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Phase&nbsp;2 Migration - exemple de migration progressive, domaine par domaine

**Étapes de la migration**

1. **Mettre en service** HIN Gateway – attribuer `Public IP B` et mettre à jour les règles du pare-feu (voir la documentation réseau pour connaître les ports requis)
2. **Créer deux connecteurs** sur Exchange Online – un connecteur entrant et un connecteur sortant – pointant vers Stargate
3. **Ajouter une règle de flux de messagerie** qui achemine les e-mails en fonction du domaine: domain1.ch → HIN Gateway, tous les autres domaines restent sur MGW
4. **Répéter progressivement** – migrer un domaine supplémentaire à la fois jusqu’à ce que tous les domaines soient sur HIN Gateway

!!! danger "Retour arrière (par domaine)"
    - Rediriger la règle de flux de messagerie du domaine concerné vers MGW
    - Laisser les connecteurs Stargate en place pour la prochaine tentative
    - Tenir à jour un **journal de toutes les modifications** apportées aux connecteurs ou aux règles, dans l’ordre – le retour arrière doit suivre cette séquence dans l’ordre inverse

!!! warning "Attention aux en-têtes spécifiques au client"
    Certains domaines utilisent des en-têtes X personnalisés (routage, listes d’autorisation anti-spam, balises de conformité). Vérifier que les connecteurs de Stargate conservent ou reproduisent ces en-têtes avant de basculer un domaine vers HIN Gateway – des en-têtes manquants peuvent entraîner des erreurs de routage ou le rejet des e-mails.

![Phase 2 Migration - gradual, domain-by-domain](assets/multi-domain-scenario/Phase2-migration-domain-by-domain.png)

## Phase&nbsp;3 Fin - migration complète vers HIN Gateway

!!! success "État final"
    - Tous les domaines transitent désormais par HIN Gateway
    - **MGW** ne prend en charge aucun trafic de production
    - Les enregistrements DNS / SPF pointent désormais vers l’**adresse IP publique B** (au cas où HIN Gateway serait le point d’entrée du trafic ou le dernier MTA)

!!! note "Liste de contrôle de finalisation"
    - Supprimer les anciens connecteurs MGW et les règles de flux de messagerie
    - Mettre hors service la VM MGW une fois que la surveillance confirme l’absence de trafic et le bon fonctionnement du flux de messagerie
    - Libérer l’**adresse IP publique A** si elle n’est plus nécessaire
    - Mettre à jour les runbooks et la documentation DNS

![Phase 3 Final - fully migrated to HIN Gateway](assets/multi-domain-scenario/Phase3-final-fully-migrated.png)

## Approche de migration recommandée selon le nombre de domaines

!!! tip "Clients avec 3 domaines ou moins"
    - HIN recommande de migrer tous les domaines en une seule fois.
    - HIN accompagnera le client dans la migration réussie du premier domaine.
    - Une fois le premier domaine migré avec succès, le client peut migrer les domaines restants de manière autonome.
    - Cette approche permet de garder la migration simple et évite la nécessité d’un environnement parallèle.

!!! note "Clients avec plus de 3 domaines"
    - HIN recommande de mettre en place un environnement parallèle à côté du MGW existant.
    - Les domaines peuvent ensuite être migrés progressivement vers le nouvel environnement.
    - HIN accompagnera le client dans la migration réussie du premier domaine.
    - Après la première migration réussie, le client peut décider comment et quand transférer les domaines restants vers le nouvel environnement.

---

!!! warning
    Avant de procéder à toute étape d’installation, vérifier que les ports exacts du pare-feu et les paramètres des connecteurs correspondent à la documentation réseau actuelle.

!!! note
    Consulter les remarques spécifiques figurant dans le [Guide d’installation du domaine](Installation-guide.md) concernant la migration multi-domaines.
