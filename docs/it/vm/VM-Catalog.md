# Catalogo immagini VM

Qui puoi trovare un catalogo VM attuale per diverse piattaforme. Non dimenticare di verificare l'hash SHA-256 delle immagini scaricate. Puoi utilizzare il file <https://images.hin.ch/vm-images/SHA256SUMS> per confrontarlo.

??? info "Come eseguire il controllo dell'hash SHA256 localmente"

    Puoi calcolare l'hash SHA256 dei file scaricati con il seguente comando e poi confrontarlo con i valori nella tabella sottostante.

    === "Linux e macOS"

        Apri il Terminale ed esegui:

        ```bash
        sha256sum <Nome del file>
        ```

        Come variante più avanzata, puoi eseguire il seguente comando e incollare la somma di controllo predefinita come `SHA256_VALUE` e il nome del file come `IMAGE_NAME`:

        ```bash
        SHA256_VALUE="" \
        IMAGE_NAME="" \
        echo "$SHA256_VALUE  $IMAGE_NAME" | sudo sha256sum --check --status
        ```

    === "Windows"

        Apri PowerShell ed esegui:

        ```powershell
        Get-FileHash "<Nome del file>"
        ```

        Puoi aggiungere l'argomento `-Algorithm SHA256` per forzare l'uso di SHA256.

| Nome immagine | Tipo immagine | Dimensione immagine | Link | Somma di controllo SHA256 |
| :--------- | :--------: | :--------- | :--: | :-------------- |
--8<-- "docs/assets/VM-Catalog-with-links.md"
