# VM Images Catalog

Here you can find a current VM Catalog for different platforms. Please do not forget to check the SHA-256 hash of downloaded images. You can use the <https://images.hin.ch/vm-images/SHA256SUMS> file to compare it.

??? info "How to perform SHA256 hash check locally"

    You can calculate the SHA256 hash of downloaded files with the following command and then compare it with the values in the table below.

    === "Linux and macOS"

        Open Terminal and execute:

        ```bash
        sha256sum <File Name>
        ```

        As a more advanced variant, you can execute the following command and paste the predefined checksum as `SHA256_VALUE` and the file name as `IMAGE_NAME`:

        ```bash
        SHA256_VALUE="" \
        IMAGE_NAME="" \
        echo "$SHA256_VALUE  $IMAGE_NAME" | sudo sha256sum --check --status
        ```

    === "Windows"

        Open PowerShell and execute:

        ```powershell
        Get-FileHash "<File Name>"
        ```

        You can add the `-Algorithm SHA256` argument to force SHA256 use.

| Image Name | Image Type | Image Größe | Link | SHA256 Checksum |
| :--------- | :--------: | :--------- | :--: | :-------------- |
--8<-- "docs/assets/VM-Catalog-with-links.md"
