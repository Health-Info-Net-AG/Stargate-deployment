# Migrating a Compose Deployment to a bootc Appliance

This guide walks through moving an existing standard-Compose Stargate installation (a `git clone` on a plain VM) onto a new **bootc appliance** VM - the immutable, image-based deployment that runs the same Compose stack read-only from `/usr` with all state on a dedicated `/var/data` Data Disk.

Migration reuses the same backup/restore tooling used for disaster recovery: back up the old VM, provision the new appliance, and restore the archive onto it. The one step no script can do for you is re-pointing the CA-side WireGuard registration at the new VM's public IP - budget time for that with your HIN contact.

!!! danger "Restore replaces ALL data on the target"
    `restore.sh` resets Vault, PostgreSQL, and object storage on the machine it runs on, then re-imports everything from the archive. Only run it against the **new** appliance, never against a VM you still need.

## Overview

1. On the **old VM**: back it up with `./scripts/backup.sh --label pre-bootc` and copy the archive off the machine.
2. Provision and boot the **bootc appliance** - it fresh-installs itself and comes up healthy but empty.
3. Copy the archive onto the appliance's restore drop zone, `/var/data/restore/`.
4. Run `restore.sh --yes` against the archive - this resets the appliance's fresh install and re-imports the old VM's data.
5. **Update the CA-side WireGuard peer registration** to the appliance's new public IP (required manual step, done with your HIN contact).
6. Verify the stack is healthy, mail flows, and certificate issuance works.

## Step 1: Back up the old VM

On the VM you are migrating **from**:

```bash
cd stargate-deployment/docker-compose   # or /root/stargate-deployment/docker-compose
./scripts/backup.sh --label pre-bootc
```

`backup.sh` prints the archive's full path in its own summary output (`Archive: ...`) - read it from there rather than assuming a location. Depending on how old the install is, the archive lands either under `/var/data/backups/` (already relocated per the [Data Layout](Docker-advanced.md#data-layout) doc) or the older `docker-compose/backups/` path. Either way, the printed path is authoritative.

Copy the resulting `.tar.gz` off the old machine to somewhere safe (your workstation, a jump host, or object storage) before decommissioning it:

```bash
scp <old-vm>:/path/from/backup-output/pre-bootc_*.tar.gz .
```

!!! note
    The archive contains Vault unseal keys, Vault KV secrets, the WireGuard private key, and database dumps - all unencrypted. `backup.sh` already `chmod 600`s it; keep that permission intact wherever you stage it next.

## Step 2: Provision and boot the bootc appliance

Deploy the bootc appliance image through your usual channel (see the [VM Images catalog](vm/VM-Catalog.md) and the platform-specific install guides under **Server install > VM deployment**). On first boot the appliance provisions itself automatically: Docker is already baked in, `install.sh` runs once to generate a fresh `customer-config.sh`/`.env`, and the Compose stack comes up healthy - but with no customer data. There is no S/MIME certificate, no configured mail domain, and no WireGuard peer for this new instance yet.

Wait until the appliance reaches that healthy-but-empty baseline before continuing:

```bash
docker compose ps
```

## Step 3: Copy the archive to the restore drop zone

`init-data-layout.sh` creates `/var/data/restore/` on every install (including the appliance's own first boot) as the designated drop zone for restore archives. Copy the archive there:

```bash
scp pre-bootc_*.tar.gz root@<new-appliance-ip>:/var/data/restore/
```

## Step 4: Run the restore

On the appliance:

```bash
sudo ./scripts/restore.sh --yes /var/data/restore/pre-bootc_*.tar.gz
```

`--yes` (or `-y`) skips the interactive confirmation prompt, which is required here since `restore.sh` refuses to run non-interactively without it.

This **replaces all data on the appliance**: it stops the running (fresh) stack, resets `/var/data/{vault,postgres,seaweedfs}`, then re-imports from the archive - the full PostgreSQL dump, Vault unseal keys and KV secrets, S3/object-storage contents, S/MIME CSR and certificates, and `customer-config.sh` (including the WireGuard private key). IP-derived settings such as `KEYCLOAK_PUBLIC_URL`, `DASHBOARD_PUBLIC_URL`, and `MXENGINE_PUBLIC_ADDRESS` are re-derived from the **new** appliance's own IP, not copied from the old VM. On success, `restore.sh` moves the consumed archive to `/var/data/restore/restored/` so a re-run won't trigger on it again.

## Step 5: CA-side WireGuard re-registration (required manual step)

The appliance has a **new public IP**. `restore.sh` restores the old WireGuard private key (so the tunnel's identity is unchanged), but the corresponding peer record on the CA side - endpoint, allowed IPs, and WireGuard IP - still points at the **old** VM's IP address. Until that record is updated, the WireGuard tunnel to HIN will not come up, and certificate issuance will fail.

!!! warning "This step cannot be automated by the appliance or the customer"
    Contact your HIN network operations / account contact and provide the new public IP (and the WireGuard port, if changed) so they can update the peer registration - endpoint, allowed IPs, and WireGuard IP - to match the new appliance. Do this as part of the migration window; mail flow and certificate renewal are blocked until it's done.

## Step 6: Verify

```bash
docker compose ps
./scripts/health-check.sh -v
```

Confirm:

- All containers report `healthy`.
- The WireGuard tunnel is up and handshaking (shown by `health-check.sh -v`).
- A test message flows through the gateway end to end (send through the appliance, confirm sealed delivery at the recipient).
- Certificate issuance succeeds - check the S/MIME certificate status in the dashboard, or confirm the CSR/certificate exchange over the tunnel completed.

## Pre-staged migration (becomes turnkey once the bootc first-boot hook lands)

Instead of waiting for the appliance to fresh-install and then running Steps 3-4 by hand, you can drop the backup archive into `/var/data/restore/` **before** first boot completes (for example, by staging it on the Data Disk during provisioning). Today this still requires manually invoking `restore.sh --yes` once the appliance's own first-boot install has finished, exactly as in Steps 3-4 above - the first-boot sequence does not yet look for a pre-staged archive on its own.

A planned first-boot hook (tracked in the almalinux-bootc project's Data Disk plan) will make this automatic: if an archive is already present in `/var/data/restore/` at first boot, the appliance will run `restore.sh --yes <archive>` in place of the fresh `install.sh`, skipping the empty-baseline install entirely since there's nothing to reset yet. Once that lands, a pre-staged migration collapses to Steps 1-2 (back up, stage the archive, boot) plus the still-manual Step 5 (CA-side WireGuard re-registration), which remains a required step regardless of how the restore was triggered.
