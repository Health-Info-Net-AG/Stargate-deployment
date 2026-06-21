# VM Images list

Here you can find a current VM images list for different platforms. Please do not forget to check the SHA-256 hash of downloaded images. You can use the https://images.hin.ch/vm-images/SHA256SUMS file to compare it.

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

<!-- Script will replace everything AFTER this line -->
| Image name | Image Type | Image Size | Link | SHA256 Checksum |
| :--------- | :--------: | :--------- | :--: | :-------------- |
| `Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.mf` | ![mf](https://img.shields.io/badge/Type-mf-blue) | 4.0K /<br>267 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.mf) | `b938fdfc5868555bd4f54abd19bf1ad5891b834ed59bb455023f78ee6c9057b7` |
| `Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.ovf` | ![ovf](https://img.shields.io/badge/Type-ovf-blue) | 8.0K /<br>7690 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.ovf) | `4bdde4ad2e2d082c494391c5ac7b56a5a78c006afcb14d033a381ebb3791fe49` |
| `Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.qcow2` | ![qcow2](https://img.shields.io/badge/Type-qcow2-blue) | 1.6G /<br>1680932864 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.qcow2) | `76119ed516da5f0e3764548c73395ec0fa4e717cb22e2b69649d8c9f564646c9` |
| `Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.ova` | ![ova](https://img.shields.io/badge/Type-ova-blue) | 991M /<br>1038643200 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.ova) | `73cef1c50cce0068cc66f69daa62a9ea6f7025a32c753ce623bc2fc1f0dbec60` |
| `Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.raw` | ![raw](https://img.shields.io/badge/Type-raw-blue) | 30G /<br>32212254720 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.raw) | `54426d1be410e56c65f02cb5bfc137b87ee65dd5c634dd6e73e63c5433d3687a` |
| `Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.raw.gz` | ![raw](https://img.shields.io/badge/Type-raw-blue) ![gz](https://img.shields.io/badge/Type-gz-green) | 999M /<br>1046644179 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.raw.gz) | `db109ae19e06460be78e71622bd09d0d7d4a9608feaef9edeaa15b16c8f2ce16` |
| `Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.vhd` | ![vhd](https://img.shields.io/badge/Type-vhd-blue) | 31G /<br>32212255232 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.vhd) | `2138192b327839179422634a4329bc89ff59e580158f27b29c01d63b40a14736` |
| `Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.vhd.gz` | ![vhd](https://img.shields.io/badge/Type-vhd-blue) ![gz](https://img.shields.io/badge/Type-gz-green) | 1007M /<br>1055379729 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.vhd.gz) | `df72f108499459a0662f01755c3f5f7cef6412556b1f2fb92789c1ff828f4d4b` |
| `Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.vhdx` | ![vhdx](https://img.shields.io/badge/Type-vhdx-blue) | 2.2G /<br>2256535552 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.vhdx) | `33c9edc4a2d505e4e5779dc694db80f768f21c109f1730688143d16c2f753a5f` |
| `Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.vmdk` | ![vmdk](https://img.shields.io/badge/Type-vmdk-blue) | 991M /<br>1038627328 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606211259.SGprod-v0.5.0-all-app-tags.x86_64.vmdk) | `cbf15e5d67c0e6394720b57c36ead50b6575b0fd23f4fe9b20ccd958be48e5cf` |
| `SHA256SUMS` | ![Checksum](https://img.shields.io/badge/Type-SHA256_checksum-blue) | 4.0K /<br>1269 bytes | [Download](https://images.hin.ch/vm-images/SHA256SUMS) | `ea9a40ed7c3d77f1ed974eb0476281fa3ead051993831937c0035e58f3c663ae` |

<!-- Script will replace everything BEFORE this line -->
