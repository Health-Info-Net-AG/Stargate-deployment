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

<!-- Script will replace everything AFTER this line -->
| Image name | Image Type | Image Size | Link | SHA256 Checksum |
| :--------- | :--------: | :--------- | :--: | :-------------- |
| `Alma10-202606191155.SGprod-v0.5.1.x86_64.mf` | ![mf](https://img.shields.io/badge/Type-mf-blue) | 4.0K /<br>241 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606191155.SGprod-v0.5.1.x86_64.mf) | `dd05c22161dbd43b2287d25dbf0495b390b13d86877db77c6718fbbf1f16dff5` |
| `Alma10-202606191155.SGprod-v0.5.1.x86_64.ova` | ![ova](https://img.shields.io/badge/Type-ova-blue) | 993M /<br>1040711680 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606191155.SGprod-v0.5.1.x86_64.ova) | `1c4e3565514720a8126e6444749e69785a988f66eb8768e616e7cc7948ae4657` |
| `Alma10-202606191155.SGprod-v0.5.1.x86_64.ovf` | ![ovf](https://img.shields.io/badge/Type-ovf-blue) | 8.0K /<br>7677 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606191155.SGprod-v0.5.1.x86_64.ovf) | `95f3baf12ab792b2412d9b5238eac4a57c8939d67331b130ff83c1a9ec809976` |
| `Alma10-202606191155.SGprod-v0.5.1.x86_64.qcow2` | ![qcow2](https://img.shields.io/badge/Type-qcow2-blue) | 1.6G /<br>1677262848 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606191155.SGprod-v0.5.1.x86_64.qcow2) | `1db8a5d77bbfa7776890d422f309b087918739b4921e306ec46ace1edfc728e4` |
| `Alma10-202606191155.SGprod-v0.5.1.x86_64.raw` | ![raw](https://img.shields.io/badge/Type-raw-blue) | 30G /<br>32212254720 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606191155.SGprod-v0.5.1.x86_64.raw) | `3b3acdcf48a86e4e644772354565010fccfb10626df179f8851ddf8bd975f4f0` |
| `Alma10-202606191155.SGprod-v0.5.1.x86_64.raw.gz` | ![raw](https://img.shields.io/badge/Type-raw-blue) ![gz](https://img.shields.io/badge/Type-gz-green) | 1001M /<br>1048767391 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606191155.SGprod-v0.5.1.x86_64.raw.gz) | `b45140c786a9fed9fb0c2d876873f4ca940d64cb6e7c4425b4b7149e83c0929b` |
| `Alma10-202606191155.SGprod-v0.5.1.x86_64.vhd` | ![vhd](https://img.shields.io/badge/Type-vhd-blue) | 31G /<br>32212255232 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606191155.SGprod-v0.5.1.x86_64.vhd) | `7855cbc7a007069ea196bbb932d10b54180ce82d89d3bf9d05093ea28015b1c6` |
| `Alma10-202606191155.SGprod-v0.5.1.x86_64.vhd.gz` | ![vhd](https://img.shields.io/badge/Type-vhd-blue) ![gz](https://img.shields.io/badge/Type-gz-green) | 1010M /<br>1058102655 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606191155.SGprod-v0.5.1.x86_64.vhd.gz) | `657a1ff82c6a372fbdbb286d9e0266ccbf2d4708ca2c5e15230c1d7e1dff0530` |
| `Alma10-202606191155.SGprod-v0.5.1.x86_64.vhdx` | ![vhdx](https://img.shields.io/badge/Type-vhdx-blue) | 2.2G /<br>2256535552 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606191155.SGprod-v0.5.1.x86_64.vhdx) | `d9d6dc64530610a4be7cb1fd541a8fcd860f685a63683037f3aaec49add6ef95` |
| `Alma10-202606191155.SGprod-v0.5.1.x86_64.vmdk` | ![vmdk](https://img.shields.io/badge/Type-vmdk-blue) | 993M /<br>1040696832 bytes | [Download](https://images.hin.ch/vm-images/Alma10-202606191155.SGprod-v0.5.1.x86_64.vmdk) | `db5eb37c4c4a1c08baedec8ba6865b4a25059a0dff995a6e7538c3fb85d61078` |
| `SHA256SUMS` | ![Checksum](https://img.shields.io/badge/Type-SHA256_checksum-blue) | 4.0K /<br>1139 bytes | [Download](https://images.hin.ch/vm-images/SHA256SUMS) | `67d250dae063e7b736c37de344c97da7d0b793869e900324ef8b9ea41f01e763` |

<!-- Script will replace everything BEFORE this line -->
