# Installer des outils Linux externes

**En tant qu’administrateur, puis-je installer des outils supplémentaires sur la machine virtuelle HIN Gateway ?**

Oui. Les administrateurs peuvent installer des outils Linux supplémentaires sur la machine virtuelle HIN Gateway, par exemple pour le diagnostic ou la surveillance. Avant de le faire, tenez compte des points suivants.

## Vous êtes responsable des outils que vous installez

HIN Gateway ne gère pas et ne prend pas en charge les logiciels tiers installés sur la machine virtuelle. Assurez-vous que les outils ajoutés ne consomment pas trop de CPU, de mémoire ou d’espace disque, afin que les services HIN Gateway disposent de ressources suffisantes pour fonctionner normalement.

## Les outils installés sont supprimés lors des mises à jour

Chaque mise à jour de HIN Gateway remplace l’environnement de la machine virtuelle. Les outils supplémentaires sont supprimés et vous devez les réinstaller après la mise à jour.

!!! tip "Conseil"
    Conservez un court script ou une liste des outils que vous installez, afin de pouvoir les réinstaller rapidement après chaque mise à jour. Pour en savoir plus sur le processus de mise à jour, consultez [Mise à jour et retour à une version antérieure de HIN Gateway](update-hin-gateway.md).
