# VM-Images Katalog

Hier finden Sie einen aktuellen VM-Katalog für verschiedene Plattformen. Vergessen Sie bitte nicht, den SHA-256-Hash der heruntergeladenen Images zu überprüfen. Sie können die Datei <https://images.hin.ch/vm-images/SHA256SUMS> verwenden, um ihn zu vergleichen.

??? info "So führen Sie die SHA256-Hash-Prüfung lokal durch"

    Sie können den SHA256-Hash heruntergeladener Dateien mit dem folgenden Befehl berechnen und ihn dann mit den Werten in der Tabelle unten vergleichen.

    === "Linux und macOS"

        Öffnen Sie das Terminal und führen Sie aus:

        ```bash
        sha256sum <Dateiname>
        ```

        Als erweiterte Variante können Sie den folgenden Befehl ausführen und die vordefinierte Prüfsumme als `SHA256_VALUE` und den Dateinamen als `IMAGE_NAME` einfügen:

        ```bash
        SHA256_VALUE="" \
        IMAGE_NAME="" \
        echo "$SHA256_VALUE  $IMAGE_NAME" | sudo sha256sum --check --status
        ```

    === "Windows"

        Öffnen Sie PowerShell und führen Sie aus:

        ```powershell
        Get-FileHash "<Dateiname>"
        ```

        Sie können das Argument `-Algorithm SHA256` hinzufügen, um die Verwendung von SHA256 zu erzwingen.

[![Latest Release](https://img.shields.io/endpoint?style=for-the-badge&url=https://health-info-net-ag.github.io/Stargate-deployment/badges/release.json)](https://github.com/Health-Info-Net-AG/Stargate-deployment)

| Image Name | Image Typ | Image Größe | Link | SHA256 Prüfsumme |
| :--------- | :-------: | :---------- | :--: | :--------------- |
--8<-- "docs/assets/VM-Catalog-with-links.md"
