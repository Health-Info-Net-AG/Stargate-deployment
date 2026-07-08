# Troubleshooting & Diagnostics

A structured guide to diagnosing a Stargate appliance from the command line: what to check, where the logs are, and safe recovery actions.

!!! info "Where to run these commands"
    Run everything below from the **deployment directory** - the folder containing `docker-compose.yml` and `scripts/` (on VM images this is typically `/root/stargate-deployment/docker-compose`, or the directory you installed into). All `docker compose` and `./scripts/*` commands assume that working directory.

    ```bash
    cd /root/stargate-deployment/docker-compose   # adjust to your install path
    ```

---

## 1. Start here: the health check

One command summarizes the whole appliance:

=== "Quick"

    ```bash
    ./scripts/health-check.sh
    ```

=== "Verbose"

    ```bash
    ./scripts/health-check.sh -v
    ```

It reports pass/fail for: **containers** (running/healthy), **liveness** endpoints (smimekeys, policy, irisagent, mxengine), **Vault** seal status, **PostgreSQL** connectivity + databases, **SeaweedFS**, the **WireGuard** tunnel + peer handshakes, **Stalwart** MTA (ports 25 / 10026), **Prometheus** metrics endpoints, and **disk / memory**.

!!! tip
    Run this first. A single `FAIL` line usually points you straight at the section below.

---

## 2. Where the logs are

| Layer | Command | What it shows |
|-------|---------|---------------|
| Boot / first-install / auto-start | `sudo journalctl -u stargate -n 200 --no-pager` | The systemd service that runs `start.sh` on boot and the first-boot install |
| Update runs | `cat ../update.log` (deployment root, one level above `docker-compose/`) | Output of the last dashboard/host-triggered `update.sh` |
| A single service | `docker logs stargate-<service> --tail 100` | e.g. `stargate-dashboard`, `stargate-mxengine`, `stargate-keycloak` |
| Follow one service live | `docker logs -f stargate-mxengine` | Real-time |
| All containers live | `docker ps -a --format '{{.Names}}' \| xargs -I{} sh -c 'docker logs --timestamps -f {} 2>&1 \| sed "s/^/[{}] /"'` | Merged, prefixed by container |
| Web log viewer | Dozzle at `https://<SERVER_IP>:8190` (Keycloak login) | Browse all container logs in a UI |

To hand logs to HIN support, use the upload script and share the returned link - see **[Provide logs to support](Docker-advanced.md#provide-logs-to-support)**:

```bash
./scripts/send-logs-to-support.sh --all          # or --since 1h  / --tail 500
```

---

## 3. Containers not running or restarting

```bash
docker compose ps -a --format 'table {{.Service}}\t{{.Status}}'
```

Read the `Status` column:

| Status | Meaning | Action |
|--------|---------|--------|
| `Up ... (healthy)` | Running fine | - |
| `Up ...` (no health) | Running; no healthcheck defined | Check its `docker logs` if you suspect trouble |
| `Restarting` | Crash-looping | `docker logs stargate-<svc>` - fix the root error (config, secret, dependency) |
| `Exited (0)` | One-shot init finished OK (e.g. `*-init`, `vault-data-fixer`) | Normal |
| `Exited (1+)` | Failed | `docker logs stargate-<svc>` - the last lines show why |
| `Created` | Never started - a dependency didn't come up | Check what it `depends_on` (usually Postgres/Vault); fix that first |

Restart a single service (safe, non-destructive):

```bash
docker compose up -d <service>          # recreate one service
docker compose restart <service>        # just restart it
```

!!! note "Startup order"
    Services wait on their dependencies (`depends_on` + healthchecks). During a full restart, brief `connection refused` / `database system is starting up` lines while Postgres/Vault come up are **normal** and clear within a minute.

---

## 4. Diagnose by symptom

### Dashboard or Keycloak won't load / can't log in

- Both are fronted by Caddy: **Dashboard** on `:443`, **Keycloak** on `:8180`.
- Check the chain: `docker logs stargate-caddy`, `stargate-dashboard`, `stargate-keycloak`, `stargate-apisix`.
- Keycloak must be **healthy** before the dashboard works: `docker compose ps keycloak`.
- TLS warning in the browser is expected (self-signed cert) - accept and proceed.
- Login redirects failing usually mean the public URL doesn't match how you reach the box - verify `KEYCLOAK_PUBLIC_URL` / `DASHBOARD_PUBLIC_URL` in `.env` point at the IP/host you actually use.

### WireGuard tunnel down / certificate issuance fails

This is the most common issue - **certificates fail when the tunnel is down**, so always fix the tunnel first.

```bash
./scripts/health-check.sh -v      # shows WireGuard peer + handshake status
docker logs stargate-irisagent | grep -iE "handshake|peer|cert|wireguard"
```

- Confirm the firewall allows **`19818` (UDP *and* TCP)** inbound/outbound.
- Verify the peer is registered on the HIN side (support step) - you supply WG public key, `DEPLOYMENT_NAME`, `SERVER_STATIC_IP`, `WG_INTERFACE_PORT`.
- Once the tunnel shows a recent handshake, retry certificate issuance from the dashboard.

### Vault sealed or init failed

```bash
docker compose exec vault vault status        # look for "Sealed: false"
docker logs stargate-vault-init
```

- Vault must be **unsealed** for smimekeys/mxengine/policy to work. Keys live in `secrets/vault-keys.json`.
- If `vault-init` exited non-zero, the keys file may be missing/corrupt - check its logs; re-running `./scripts/init-vault.sh` re-attempts unseal.

!!! danger "Do not delete `secrets/vault-keys.json`"
    Losing it means losing access to all stored secrets. Keep a backup.

### PostgreSQL / database connectivity

```bash
docker compose exec postgres pg_isready -U postgres
docker logs stargate-postgres --tail 50
```

- Transient `the database system is starting up (57P03)` right after a restart is normal - services reconnect automatically.
- Persistent auth failures usually mean `POSTGRES_PASSWORD` in `.env` drifted from the data volume - see the update/secrets notes, and avoid editing it by hand.

### Mail not flowing

- **Inbound** arrives on **`:25`** (Stalwart). Many cloud providers **block port 25** by default:

    ```bash
    nc -zv <this-server-ip> 25          # from an external host
    docker logs stargate-stalwart --tail 100
    ```

    If `25` is blocked, request an exception from your provider.
- **Outbound / sealing** goes Stalwart → **mxengine** (`:8084` seal callback, SMTP `:1587`): `docker logs stargate-mxengine`.
- **Mail loops** show as the same message cycling - check that your domain's MX does not resolve back to this appliance's own IP.
- See **[Mail relay setup](Mail-relay-setup.md)** and **[DNS setup](DNS-setup.md)** for the expected routing.

### An update failed

```bash
docker logs stargate-ops-agent --tail 40      # the update orchestrator
cat ../update.log                             # the update script output
```

- The ops-agent pulls the release manifest, writes versions to `customer-config.sh`, then runs `update.sh` on the host.
- After it finishes, confirm versions applied: `./scripts/gather-app-versions.sh` (or check `docker compose ps` image tags).
- If a service is stuck after an update, `docker compose up -d <service>` to recreate it.

### Dozzle (log viewer) not reachable

- URL is `https://<SERVER_IP>:8190`; it requires a **Keycloak login** (same realm as the dashboard) via oauth2-proxy.
- It only runs when `DOZZLE_ENABLED="true"`. Check: `docker compose ps dozzle oauth2-proxy`.
- Ensure the firewall allows **`:8190`** inbound. See **[Monitoring and Logs](Monitoring.md)**.

---

## 5. Storage & disk

```bash
df -h /                              # is the disk full?
docker system df                     # space used by images / containers / volumes
du -sh /var/lib/docker/volumes/*     # per-volume usage (Postgres, SeaweedFS, Loki, ...)
```

- Container logs are capped (json-file, 100 MB × 5 per container) so they shouldn't fill the disk, but images and volumes can.
- Reclaim space safely: `docker image prune -af` (removes unused images only). Avoid `docker system prune --volumes` - it deletes data volumes.
- Object storage is **SeaweedFS** (`stargate-seaweedfs`): `docker logs stargate-seaweedfs --tail 50`.

---

## 6. VM resources

```bash
free -h                              # memory (min 8 GB)
nproc                                # CPUs (min 4)
docker stats --no-stream             # per-container CPU/RAM
uptime                               # load average
```

Host metrics are also exported for Prometheus on **`:9100/metrics`** (see [Monitoring](Monitoring.md#prometheus-metrics)). If the box is swapping or pegged, expect healthchecks to flap and updates to be slow.

---

## 7. Network & ports

Quick reachability check for the key inbound ports:

```bash
for p in 25 443 8180 8190 8084 19818; do nc -zv <this-server-ip> $p; done
```

| Port | Service | Direction |
|------|---------|-----------|
| `25` | Stalwart SMTP (inbound mail) | inbound |
| `443` | Dashboard (HTTPS) | inbound |
| `8180` | Keycloak | inbound |
| `8190` | Dozzle (optional) | inbound |
| `8084` | mxengine seal callback | inbound |
| `19818` | WireGuard (UDP **and** TCP) | in/outbound |

Outbound access is needed to the container registry, the S/MIME CA (over the WireGuard tunnel), and any remote Loki you configured. See the full port table on the **[home page](index.md)** and **[Applications overview](Applications.md)**.

---

## 8. Recovery actions

Ordered least- to most-disruptive:

```bash
docker compose up -d <service>       # recreate one stuck service
sudo systemctl restart stargate      # restart the whole stack (via start.sh)
./scripts/stop.sh  &&  ./scripts/start.sh
```

!!! warning "Backups & destructive recovery"
    `./scripts/backup.sh` and `./scripts/restore.sh` handle data backup/restore. `./scripts/purge.sh` **deletes all data** (databases, Vault, storage) for a clean reinstall - use only as a last resort and only with a current backup. Details: [Docker Advanced configuration](Docker-advanced.md).

---

## 9. When to contact support

If the health check still shows failures after the steps above, open a ticket via **[Support / Contact us](Support.md)** and include:

- The **appliance version** (`./scripts/gather-app-versions.sh`) and **customer name**.
- The **health-check output** (`./scripts/health-check.sh -v`).
- A **log bundle** link from `./scripts/send-logs-to-support.sh` (see [Provide logs to support](Docker-advanced.md#provide-logs-to-support)).
- What you were doing when it broke, and any screenshots.

## Update Verimesh Instance

The following instructions describe how to update a Verimesh instance from v0.5.1 to v0.5.3.

*Note:* You will need to login to the VM using the Linux administrator account.

### Update Steps
1. Edit the .env file and update the ops-agent version to 0.0.3.
2. Edit the customer configuration and update the ops-agent version to 0.0.3 there as well.
3. Switch to the main branch: `git checkout main` 
4. Pull the latest changes: `git pull` 
5. Update the ops-agent container: `docker compose up -d ops-agent` 
6. Log in to the Dashboard.
6. Navigate to Settings.
7. In the Update section at the bottom of the page, enter the target version (v0.5.3) and start the update process.