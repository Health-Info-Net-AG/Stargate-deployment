# Catalogue des images VM

Vous trouverez ici un catalogue VM actuel pour différentes plateformes. N'oubliez pas de vérifier le hachage SHA-256 des images téléchargées. Vous pouvez utiliser le fichier <https://images.hin.ch/vm-images/SHA256SUMS> pour le comparer.

??? info "Comment effectuer une vérification du hachage SHA256 localement"

    Vous pouvez calculer le hachage SHA256 des fichiers téléchargés avec la commande suivante, puis le comparer avec les valeurs du tableau ci-dessous.

    === "Linux et macOS"

        Ouvrez le Terminal et exécutez :

        ```bash
        sha256sum <Nom du fichier>
        ```

        Comme variante plus avancée, vous pouvez exécuter la commande suivante et coller la somme de contrôle prédéfinie comme `SHA256_VALUE` et le nom du fichier comme `IMAGE_NAME` :

        ```bash
        SHA256_VALUE="" \
        IMAGE_NAME="" \
        echo "$SHA256_VALUE  $IMAGE_NAME" | sudo sha256sum --check --status
        ```

    === "Windows"

        Ouvrez PowerShell et exécutez :

        ```powershell
        Get-FileHash "<Nom du fichier>"
        ```

        Vous pouvez ajouter l'argument `-Algorithm SHA256` pour forcer l'utilisation de SHA256.

| Nom de l'image | Type d'image | Taille de l'image | Lien | Somme de contrôle SHA256 |
| :--------- | :--------: | :--------- | :--: | :-------------- |
--8<-- "docs/assets/VM-Catalog-with-links.md"
