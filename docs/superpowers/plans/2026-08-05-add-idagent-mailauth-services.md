# Add `idagent` + `mailauth` Services Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two new default-on application services - `idagent` (KERI decentralized-identity / anchoring) and `mailauth` (SPF/DKIM/DMARC/ARC email authentication) - to the Docker Compose based Stargate mail gateway, fully wired into datastores, secrets, the Stalwart mail path, and the install/backup/health tooling.

**Architecture:** `idagent` is a standalone backend (HTTP :8080, two Postgres DBs, Vault KV2, a persistent `/data/keri` volume) that the dashboard calls to anchor DKIM public keys - it is NOT in the SMTP path. `mailauth` is a stateless Rust service (HTTP :8080, Vault KV2, no DB) wired into Stalwart as a DATA-stage MTA hook that verifies inbound and DKIM-signs authenticated outbound. Both follow the existing app-service conventions in this repo.

**Tech Stack:** Docker Compose, PostgreSQL 18, HashiCorp Vault (KV v2), SeaweedFS (unused by these two), Stalwart v0.16 (MtaHook via `stalwart-cli`), POSIX `sh` / Bash provisioning + ops scripts.

## Global Constraints

- **Do NOT run `git commit` or `git push`.** The maintainer (Petar) commits manually. Each task's final step stages files and gives the intended commit message for completeness, but the executor MUST NOT run `git commit`/`git push` unless Petar explicitly authorizes it. (Standing user rule.)
- **Branch:** work on the existing `idagent+mailauth-integration` branch. Do not create or switch branches.
- **Fail closed:** the mailauth Stalwart hook uses `tempFailOnError=true` and `MAILAUTH_ALLOW_UNSIGNED=false`.
- **Images publish soon, not yet present:** `healthinfonetag/idagent` and `healthinfonetag/mailauth` are not on Docker Hub at authoring time. `docker compose pull`/`up` of these two will fail until their CI publishes tags. All non-pull verification (`docker compose config`, `bash -n`, `shellcheck`, `grep`) MUST still pass. The live pull/start smoke test (Task 8) is deferred until the images exist.
- **Placeholder version tags:** new `*_VERSION` vars are empty (`""`) in customer-config templates; compose falls back to `:dev` via `${VAR:-dev}`. Real tags get pinned before rollout.
- **Naming:** `IDAGENT_VERSION` now names the new KERI `idagent`. Any pre-existing `IDAGENT_VERSION` in a template refers to the retired WireGuard-agent meaning and must be reconciled (Task 5), not left to collide.
- **Ports:** idagent host `8085:8080`, mailauth host `8086:8080`. Neither exposes `/metrics`.
- **Spec:** `docs/superpowers/specs/2026-08-05-add-idagent-mailauth-services-design.md`.

---

## File Structure

**Modified:**
- `docker-compose/init/postgres/01-create-databases.sql` - two new DBs + grants (Task 1)
- `docker-compose/scripts/init-vault.sh` - two new KV-v2 mounts (Task 1)
- `docker-compose/docker-compose.yml` - `idagent` service + volume (Task 2), `mailauth` service (Task 3)
- `docker-compose/config/stalwart/provision.sh` - mailauth MTA hook (Task 4)
- `docker-compose/customer-config-prod.example.sh` + `customer-config.alpha` + `customer-config-alpha-new` + `customer-config.gamma` + `customer-config.test` - version placeholders (Task 5)
- `docker-compose/scripts/install.sh` - version defaults + `.env` writeout (Task 5)
- `docker-compose/scripts/gather-app-versions.sh` - idagent/mailauth version scrape (Task 6)
- `docker-compose/scripts/health-check.sh` - container/liveness/DB lists (Task 6)
- `docker-compose/scripts/backup.sh` - DB list + Vault-mount list (Task 7)

**No change (verified generic):** `scripts/lib/manifest.sh` (generic `*_VERSION` apply), `scripts/restore.sh` (reads backup's own manifest).

---

### Task 1: Provision backing stores (Postgres DBs + Vault mounts)

**Files:**
- Modify: `docker-compose/init/postgres/01-create-databases.sql`
- Modify: `docker-compose/scripts/init-vault.sh:108-112`

**Interfaces:**
- Produces: Postgres databases `idagent`, `idagent_keri`; Vault KV-v2 mounts `secret-idagent`, `secret-mailauth`. Consumed by the compose services in Tasks 2 and 3.

- [ ] **Step 1: Add the two databases + grants to the init SQL**

Edit `docker-compose/init/postgres/01-create-databases.sql`. After the `CREATE DATABASE stalwart;` line, add:

```sql
CREATE DATABASE idagent;
CREATE DATABASE idagent_keri;
```

After the `GRANT ALL PRIVILEGES ON DATABASE stalwart TO postgres;` line, add:

```sql
GRANT ALL PRIVILEGES ON DATABASE idagent TO postgres;
GRANT ALL PRIVILEGES ON DATABASE idagent_keri TO postgres;
```

- [ ] **Step 2: Add the two Vault mounts to init-vault.sh**

In `docker-compose/scripts/init-vault.sh`, immediately after the `secret-mtaconf` line (currently line 112), add:

```sh
  vault secrets enable -address=http://vault:8200 -path=secret-idagent kv-v2 || echo "secret-idagent already exists"
  vault secrets enable -address=http://vault:8200 -path=secret-mailauth kv-v2 || echo "secret-mailauth already exists"
```

- [ ] **Step 3: Verify the SQL and the shell syntax**

Run:
```bash
cd /home/petar/Repos/svdh/stargate-deployment/docker-compose
grep -nE "idagent|idagent_keri" init/postgres/01-create-databases.sql
bash -n scripts/init-vault.sh && echo "init-vault.sh OK"
grep -nE "secret-idagent|secret-mailauth" scripts/init-vault.sh
```
Expected: two `CREATE DATABASE` + two `GRANT` lines for the new DBs; `init-vault.sh OK`; the two new `secret-*` mount lines present.

- [ ] **Step 4: Stage (do NOT commit - see Global Constraints)**

```bash
git add docker-compose/init/postgres/01-create-databases.sql docker-compose/scripts/init-vault.sh
# Intended message (Petar commits manually):
# feat(idagent,mailauth): provision Postgres DBs + Vault mounts
```

---

### Task 2: idagent compose service + volume

**Files:**
- Modify: `docker-compose/docker-compose.yml` (insert service after the `mxengine` block ending ~line 657, before `apisix:`; add volume in the `volumes:` block ~line 1210)

**Interfaces:**
- Consumes: Postgres DBs `idagent`/`idagent_keri` and Vault mount `secret-idagent` (Task 1); `postgres`, `vault-init` services; `${POSTGRES_USER}`, `${POSTGRES_PASSWORD}`, `${VAULT_TOKEN}`, `${IDAGENT_VERSION}` from `.env`.
- Produces: service `idagent` reachable at `http://idagent:8080` on `stargate-network`, host port `8085`; named volume `idagent_keri_data`.

- [ ] **Step 1: Add the idagent service block**

In `docker-compose/docker-compose.yml`, after the `mxengine` service block (the line with `- autoheal=true` at ~657, before `  apisix:`), insert:

```yaml
  idagent:
    image: healthinfonetag/idagent:${IDAGENT_VERSION:-dev}
    container_name: stargate-idagent
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: "100m"
        max-file: "5"
    depends_on:
      postgres:
        condition: service_healthy
      vault-init:
        condition: service_completed_successfully
    environment:
      LOG_LEVEL: "info"
      HTTP_HOST: ""
      HTTP_PORT: "8080"
      HTTP_IDLE_TIMEOUT: "180s"
      HTTP_READ_TIMEOUT: "60s"
      HTTP_WRITE_TIMEOUT: "60s"

      # Databases: identity (DB_URI) + KERI Key Event Log (KERI_DB_URL)
      DB_URI: "postgres://${POSTGRES_USER:-postgres}:${POSTGRES_PASSWORD:-postgres}@postgres:5432/idagent"
      KERI_DB_URL: "postgres://${POSTGRES_USER:-postgres}:${POSTGRES_PASSWORD:-postgres}@postgres:5432/idagent_keri"
      KERI_DB_PATH: "/data/keri"

      # Vault (Ed25519 seed storage)
      VAULT_ADDRESS: "http://vault:8200"
      VAULT_TOKEN: "${VAULT_TOKEN}"
      VAULT_MOUNT_PATH: "secret-idagent"
      VAULT_KV2_MAX_VERSIONS: "2"
      VAULT_KV2_CAS_REQUIRED: "false"
      VAULT_KV2_DELETE_VERSION_AFTER: "0s"

      # KERI: local-only KEL (no external witness pool)
      KERI_WITNESSES: "[]"
      KERI_WITNESS_THRESHOLD: "0"
    volumes:
      - idagent_keri_data:/data/keri
    ports:
      - "8085:8080"
    networks:
      - stargate-network
    labels:
      - autoheal=true
```

- [ ] **Step 2: Declare the named volume**

In the top-level `volumes:` block (where `postgres_data:`, `vault_data:`, etc. are declared, ~line 1210), add:

```yaml
  idagent_keri_data:
```

- [ ] **Step 3: Verify compose parses and the service is present**

Run:
```bash
cd /home/petar/Repos/svdh/stargate-deployment/docker-compose
docker compose config >/dev/null && echo "compose config OK"
docker compose config | grep -A2 "stargate-idagent" | head
docker compose config --volumes | grep idagent_keri_data
```
Expected: `compose config OK`; the `stargate-idagent` container name shows; `idagent_keri_data` listed as a volume.

- [ ] **Step 4: Stage (do NOT commit)**

```bash
git add docker-compose/docker-compose.yml
# Intended message: feat(idagent): add KERI identity service + keri volume
```

---

### Task 3: mailauth compose service

**Files:**
- Modify: `docker-compose/docker-compose.yml` (insert service directly after the `idagent` block from Task 2)

**Interfaces:**
- Consumes: Vault mount `secret-mailauth` (Task 1); `vault-init`, `dashboard` services; `${VAULT_TOKEN}`, `${MAILAUTH_VERSION}` from `.env`.
- Produces: service `mailauth` reachable at `http://mailauth:8080` on `stargate-network`, host port `8086`; the hook endpoint `http://mailauth:8080/hook` that Task 4 registers in Stalwart.

- [ ] **Step 1: Add the mailauth service block**

In `docker-compose/docker-compose.yml`, directly after the `idagent` block added in Task 2, insert:

```yaml
  mailauth:
    image: healthinfonetag/mailauth:${MAILAUTH_VERSION:-dev}
    container_name: stargate-mailauth
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: "100m"
        max-file: "5"
    depends_on:
      vault-init:
        condition: service_completed_successfully
      dashboard:
        condition: service_healthy
    environment:
      MAILAUTH_BIND_ADDR: "0.0.0.0:8080"
      MAILAUTH_MAX_BODY_MB: "50"

      # Vault (reads DKIM/ARC private keys per request)
      MAILAUTH_VAULT_ADDRESS: "http://vault:8200"
      MAILAUTH_VAULT_TOKEN: "${VAULT_TOKEN}"
      MAILAUTH_VAULT_MOUNT_PATH: "secret-mailauth"

      # Per-domain config from the dashboard (falls back to POST /config)
      MAILAUTH_DASHBOARD_CONFIG_URL: "http://dashboard:3000/api/internal/installation-config?service=mailauth"

      # Fail closed: temp-reject (451) if a configured domain cannot be signed
      MAILAUTH_ALLOW_UNSIGNED: "false"

      RUST_LOG: "info"
    ports:
      - "8086:8080"
    networks:
      - stargate-network
    labels:
      - autoheal=true
```

- [ ] **Step 2: Verify compose parses and the service is present**

Run:
```bash
cd /home/petar/Repos/svdh/stargate-deployment/docker-compose
docker compose config >/dev/null && echo "compose config OK"
docker compose config | grep "stargate-mailauth"
```
Expected: `compose config OK`; `stargate-mailauth` shows.

- [ ] **Step 3: Stage (do NOT commit)**

```bash
git add docker-compose/docker-compose.yml
# Intended message: feat(mailauth): add SPF/DKIM/DMARC/ARC service (default-on)
```

---

### Task 4: Stalwart mailauth MTA hook (provision.sh)

**Files:**
- Modify: `docker-compose/config/stalwart/provision.sh` (add helper + call in section "2c", after the ClamAV milter creation ~line 150)

**Interfaces:**
- Consumes: `cli()` and `log()` helpers already defined in the script; the `mailauth` service from Task 3 at `http://mailauth:8080/hook`.
- Produces: a Stalwart `MtaHook` (DATA stage, `tempFailOnError=true`) scoped to every listener except `reinject`. Picked up by the existing `ReloadSettings` at the end of the script.

- [ ] **Step 1: Add the hook scope var + `create_mta_hook` helper**

In `docker-compose/config/stalwart/provision.sh`, after the `create_milter` function definition (ends ~line 115, before the `# SMTP inbound (port 25)` comment), add:

```sh
# mailauth MTA hook (HTTP, DATA stage). Runs on every listener EXCEPT
# 'reinject' (:10026), so it verifies + stamps Authentication-Results + ARC-seals
# once on ingress and DKIM-signs on authenticated submission, but does NOT re-run
# on the mxengine reinject round-trip (avoids a duplicate Authentication-Results
# header and a double ARC seal). Mirrors the ClamAV milter's listener scoping.
# NOTE: a MtaHook must be created WITHOUT an enable expression and then scoped via
# a follow-up `update` (the validated path); creating with enable inline fails
# validation. This differs from MtaMilter, which accepts enable at create time.
MAILAUTH_HOOK_URL="${MAILAUTH_HOOK_URL:-http://mailauth:8080/hook}"
MAILAUTH_HOOK_SCOPE="{\"match\":{\"0\":{\"if\":\"listener != 'reinject'\",\"then\":\"true\"}},\"else\":\"false\"}"

create_mta_hook() {
  local url="$1" hid

  # MtaHook has no settable name; identify an existing one by its URL.
  hid=$(cli query MtaHook 2>/dev/null | awk -v u="$url" 'NR>1 && index($0, u) {print $1; exit}') || true
  if [ -z "$hid" ]; then
    log "creating MTA hook: ${url} (DATA stage, all listeners except reinject)"
    cli create MtaHook \
      --field "url=${url}" \
      --field 'stages={"data":true}' \
      --field "tempFailOnError=true"
    hid=$(cli query MtaHook 2>/dev/null | awk -v u="$url" 'NR>1 && index($0, u) {print $1; exit}') || true
  else
    log "MTA hook (${url}) already exists (id=${hid}); reconciling scope"
  fi
  [ -n "$hid" ] || { log "ERROR: could not resolve MtaHook id for ${url}"; return 1; }

  log "scoping mailauth hook ${hid} to all listeners except reinject"
  cli update MtaHook "$hid" --json "{\"enable\":${MAILAUTH_HOOK_SCOPE}}"
}
```

- [ ] **Step 2: Call the helper after the ClamAV milter**

In the same file, in section `2c` immediately after the `create_milter "clamav" ...` call (currently line 150), add:

```sh

# Email authentication (mailauth MTA hook): SPF/DKIM/DMARC/ARC verify + seal
# inbound, DKIM-sign authenticated outbound. Fail-closed (tempFailOnError=true).
create_mta_hook "$MAILAUTH_HOOK_URL"
```

- [ ] **Step 3: Verify shell syntax**

Run:
```bash
cd /home/petar/Repos/svdh/stargate-deployment/docker-compose
bash -n config/stalwart/provision.sh && echo "provision.sh OK"
grep -nE "create_mta_hook|MAILAUTH_HOOK_URL|listener != 'reinject'" config/stalwart/provision.sh
command -v shellcheck >/dev/null && shellcheck -S warning config/stalwart/provision.sh || echo "shellcheck not installed - skip"
```
Expected: `provision.sh OK`; the helper definition, the call, and the scope expression all present; shellcheck (if installed) reports no new warnings on the added lines.

- [ ] **Step 4: Stage (do NOT commit)**

```bash
git add docker-compose/config/stalwart/provision.sh
# Intended message: feat(mailauth): register DATA-stage MTA hook in Stalwart provisioning
```

---

### Task 5: Version plumbing (customer-config templates + install.sh)

**Files:**
- Modify: `docker-compose/customer-config-prod.example.sh:82-89`
- Modify: `docker-compose/customer-config-alpha-new:83`
- Modify: `docker-compose/customer-config.alpha:86`
- Modify: `docker-compose/customer-config.gamma:114`
- Modify: `docker-compose/customer-config.test:87`
- Modify: `docker-compose/scripts/install.sh:138` (defaults) and `:281` (writeout)

**Interfaces:**
- Produces: `IDAGENT_VERSION` and `MAILAUTH_VERSION` defined in every customer-config template and flowed into the generated `.env`, consumed by the compose services in Tasks 2-3 via `${IDAGENT_VERSION:-dev}` / `${MAILAUTH_VERSION:-dev}`.
- Note: templates `.alpha`, `.gamma`, `.test` carry a LEGACY `IDAGENT_VERSION` that meant the retired WireGuard agent. Those lines are reconciled to the new meaning here so they don't mis-tag the KERI `idagent` image.

- [ ] **Step 1: Add placeholders to the canonical prod template**

In `docker-compose/customer-config-prod.example.sh`, after the `OPS_AGENT_VERSION="v0.0.5"` line (line 89), add:

```sh

# idagent (KERI identity) + mailauth (SPF/DKIM/DMARC/ARC). Images being
# published; leave empty to fall back to the :dev tag, pin real tags before
# rollout. IDAGENT_VERSION here is the KERI idagent, NOT the WireGuard agent
# (that is IRISAGENT_VERSION above).
IDAGENT_VERSION=""
MAILAUTH_VERSION=""
```

- [ ] **Step 2: Add placeholders to `customer-config-alpha-new`**

This file has `IRISAGENT_VERSION` and no `IDAGENT_VERSION`. After its `MXENGINE_VERSION="v0.0.39"` line (line 84), add:

```sh
IDAGENT_VERSION=""
MAILAUTH_VERSION=""
```

- [ ] **Step 3: Reconcile the legacy `IDAGENT_VERSION` in `customer-config.alpha`**

In `docker-compose/customer-config.alpha`, the line `IDAGENT_VERSION="v0.0.9"` (line 86) is the retired WireGuard-agent meaning. Replace that single line with:

```sh
# IDAGENT_VERSION now = KERI idagent (empty -> :dev). WireGuard agent is IRISAGENT_VERSION.
IDAGENT_VERSION=""
MAILAUTH_VERSION=""
```

- [ ] **Step 4: Reconcile the legacy `IDAGENT_VERSION` in `customer-config.gamma`**

In `docker-compose/customer-config.gamma`, replace the line `IDAGENT_VERSION="v0.0.6-branch"` (line 114) with:

```sh
# IDAGENT_VERSION now = KERI idagent (empty -> :dev). WireGuard agent is IRISAGENT_VERSION.
IDAGENT_VERSION=""
MAILAUTH_VERSION=""
```

- [ ] **Step 5: Reconcile the legacy `IDAGENT_VERSION` in `customer-config.test`**

In `docker-compose/customer-config.test`, replace the line `IDAGENT_VERSION="v0.0.6-branch"` (line 87) with:

```sh
# IDAGENT_VERSION now = KERI idagent (empty -> :dev). WireGuard agent is IRISAGENT_VERSION.
IDAGENT_VERSION=""
MAILAUTH_VERSION=""
```

- [ ] **Step 6: Add defaults to install.sh**

In `docker-compose/scripts/install.sh`, after the `OPS_AGENT_VERSION="${OPS_AGENT_VERSION:-dev}"` line (line 138), add:

```sh
  IDAGENT_VERSION="${IDAGENT_VERSION:-dev}"
  MAILAUTH_VERSION="${MAILAUTH_VERSION:-dev}"
```

- [ ] **Step 7: Add both to the `.env` writeout heredoc**

In `docker-compose/scripts/install.sh`, in the `# Application Versions` block of the generated `.env`, after the `OPS_AGENT_VERSION="$OPS_AGENT_VERSION"` line (line 281), add:

```sh
IDAGENT_VERSION="$IDAGENT_VERSION"
MAILAUTH_VERSION="$MAILAUTH_VERSION"
```

- [ ] **Step 8: Verify**

Run:
```bash
cd /home/petar/Repos/svdh/stargate-deployment/docker-compose
bash -n scripts/install.sh && echo "install.sh OK"
for f in customer-config-prod.example.sh customer-config-alpha-new customer-config.alpha customer-config.gamma customer-config.test; do
  echo "--- $f ---"; grep -nE "IDAGENT_VERSION|MAILAUTH_VERSION" "$f"
done
grep -nE "IDAGENT_VERSION|MAILAUTH_VERSION" scripts/install.sh
```
Expected: `install.sh OK`; every template shows `IDAGENT_VERSION=""` and `MAILAUTH_VERSION=""` (no leftover legacy `v0.0.x` value on the idagent line); install.sh shows both the default assignment and the writeout line for each.

- [ ] **Step 9: Stage (do NOT commit)**

```bash
git add docker-compose/customer-config-prod.example.sh docker-compose/customer-config-alpha-new docker-compose/customer-config.alpha docker-compose/customer-config.gamma docker-compose/customer-config.test docker-compose/scripts/install.sh
# Intended message: feat(idagent,mailauth): version vars in templates + install env
```

---

### Task 6: Observability (gather-app-versions.sh + health-check.sh)

**Files:**
- Modify: `docker-compose/scripts/gather-app-versions.sh` (after the `mxengine` scrape line)
- Modify: `docker-compose/scripts/health-check.sh:41` (running list), `:83` (liveness map), `:131` (DB loop)

**Interfaces:**
- Consumes: services `idagent` (:8080) and `mailauth` (:8080) internal hostnames; host ports 8085/8086 for liveness; DBs `idagent`/`idagent_keri`.
- Produces: `app_build_info` metric for idagent (and mailauth if it emits a version); health-check coverage of both containers, their liveness ports, and the two new DBs.

- [ ] **Step 1: Add version scrapes**

In `docker-compose/scripts/gather-app-versions.sh`, after the `get_version "mxengine" "mxengine" "8080"` line, add:

```sh
get_version "idagent" "idagent" "8080"
get_version "mailauth" "mailauth" "8080"
```
(The `get_version` helper only emits a metric when a `version`/`Version` field is present in `/liveness`; if mailauth's payload has none, the line is a harmless no-op.)

- [ ] **Step 2: Add both containers to the running list**

In `docker-compose/scripts/health-check.sh`, in the `EXPECTED_RUNNING=(` array, after the `stargate-mxengine` line (line 41), add:

```sh
  stargate-idagent
  stargate-mailauth
```

- [ ] **Step 3: Add both to the liveness map**

In the `declare -A LIVENESS_ENDPOINTS=(` block, after the `[mxengine]=8084` line (line 83), add:

```sh
  [idagent]=8085
  [mailauth]=8086
```

- [ ] **Step 4: Add the two DBs to the DB check loop**

Change the DB loop (line 131) from:

```sh
for db in smimekeys_client policy irisagent mxengine; do
```
to:
```sh
for db in smimekeys_client policy irisagent mxengine idagent idagent_keri; do
```

- [ ] **Step 5: Verify**

Run:
```bash
cd /home/petar/Repos/svdh/stargate-deployment/docker-compose
bash -n scripts/health-check.sh && echo "health-check.sh OK"
bash -n scripts/gather-app-versions.sh && echo "gather-app-versions.sh OK"
grep -nE "idagent|mailauth" scripts/gather-app-versions.sh
grep -nE "stargate-idagent|stargate-mailauth|\[idagent\]|\[mailauth\]|idagent_keri" scripts/health-check.sh
```
Expected: both scripts `OK`; the new scrape lines present; health-check shows both containers, both liveness entries, and `idagent_keri` in the DB loop.

- [ ] **Step 6: Stage (do NOT commit)**

```bash
git add docker-compose/scripts/gather-app-versions.sh docker-compose/scripts/health-check.sh
# Intended message: feat(idagent,mailauth): version scrape + health-check coverage
```

---

### Task 7: Backup integration (backup.sh)

**Files:**
- Modify: `docker-compose/scripts/backup.sh:105` (DB list), `:235` (Vault-mount list)

**Interfaces:**
- Consumes: DBs `idagent`/`idagent_keri`; Vault mounts `secret-idagent`/`secret-mailauth`.
- Produces: per-DB dumps for the two idagent databases and Vault backups of both new mounts, so idagent's KEL + seeds (identity continuity) survive backup/restore.

- [ ] **Step 1: Add the two DBs to the backup set**

In `docker-compose/scripts/backup.sh`, change the `DATABASES=(...)` line (line 105) from:

```sh
DATABASES=("smimekeys_client" "policy" "irisagent" "mxengine" "dashboard" "keycloak" "stalwart")
```
to:
```sh
DATABASES=("smimekeys_client" "policy" "irisagent" "mxengine" "idagent" "idagent_keri" "dashboard" "keycloak" "stalwart")
```

- [ ] **Step 2: Add the two Vault mounts to the backup set**

Change the `VAULT_MOUNTS=(...)` line (line 235) from:

```sh
    VAULT_MOUNTS=("secret-smimekeys-client" "secret-irisagent" "secret-policy" "secret-mxengine" "secret-mtaconf")
```
to:
```sh
    VAULT_MOUNTS=("secret-smimekeys-client" "secret-irisagent" "secret-policy" "secret-mxengine" "secret-mtaconf" "secret-idagent" "secret-mailauth")
```

- [ ] **Step 3: Verify**

Run:
```bash
cd /home/petar/Repos/svdh/stargate-deployment/docker-compose
bash -n scripts/backup.sh && echo "backup.sh OK"
grep -nE "idagent|idagent_keri|secret-idagent|secret-mailauth" scripts/backup.sh
```
Expected: `backup.sh OK`; `idagent` and `idagent_keri` in `DATABASES`; `secret-idagent` and `secret-mailauth` in `VAULT_MOUNTS`.

- [ ] **Step 4: Stage (do NOT commit)**

```bash
git add docker-compose/scripts/backup.sh
# Intended message: feat(idagent,mailauth): back up new DBs + Vault mounts
```

---

### Task 8: Full-stack validation (offline now, live smoke test deferred)

**Files:** none (verification only).

**Interfaces:**
- Consumes: all changes from Tasks 1-7.
- Produces: a green offline validation, plus a written live smoke-test checklist to run on a disposable box (alpha) once the images are published.

- [ ] **Step 1: Offline validation - everything that does not need the images**

Run:
```bash
cd /home/petar/Repos/svdh/stargate-deployment/docker-compose
docker compose config >/dev/null && echo "compose OK"
for s in scripts/init-vault.sh scripts/install.sh scripts/health-check.sh scripts/gather-app-versions.sh scripts/backup.sh config/stalwart/provision.sh; do
  bash -n "$s" && echo "bash -n $s OK"
done
command -v shellcheck >/dev/null && shellcheck -S warning scripts/provision.sh 2>/dev/null; \
  command -v shellcheck >/dev/null && shellcheck -S warning config/stalwart/provision.sh || echo "shellcheck skipped"
# Confirm the two services + volume are wired
docker compose config | grep -E "stargate-idagent|stargate-mailauth"
docker compose config --volumes | grep idagent_keri_data
```
Expected: `compose OK`; every `bash -n ... OK`; both services and the volume present.

- [ ] **Step 2: Record the deferred live smoke test (run on alpha once images exist)**

The following are NOT runnable until `healthinfonetag/idagent` + `healthinfonetag/mailauth` are published. Capture this checklist in the task's completion note / hand it to Petar:

```
On stargate-alpha, after images are published and tags pinned:
  0. PRE-FLIGHT collision guard (the KERI idagent reuses the old WireGuard-agent's
     DB/mount names `idagent` / `secret-idagent`, which the idagent->irisagent rename
     renamed-forward but never DROPPED). Before enabling idagent on ANY box, confirm
     there is no stale pre-rename `idagent` DB:
       docker exec stargate-postgres psql -U postgres -tAc \
         "SELECT 1 FROM pg_database WHERE datname='idagent'"
     If it returns 1, inspect the tables:
       docker exec stargate-postgres psql -U postgres -d idagent -c "\dt"
     KERI-shaped (an `identities` table / empty) is fine. If it holds old WireGuard
     tables (e.g. `connections`), STOP: that box predates the rename - drop/rename the
     stale DB (with Petar's OK) before enabling idagent, else the KERI migrations run
     against stale data. Same check for Vault: `vault secrets list | grep secret-idagent`
     should be absent (only `secret-irisagent`). (alpha+gamma verified clean 2026-08-05.)
  1. docker compose pull idagent mailauth   # both pull cleanly
  2. docker compose up -d idagent mailauth
  3. curl -sf localhost:8085/liveness && curl -sf localhost:8085/readiness   # idagent up
  4. curl -sf localhost:8086/liveness   # mailauth liveness always 200
     curl -s  localhost:8086/readiness  # 200 only once Vault reachable
  5. docker exec stargate-postgres psql -U postgres -d idagent      -tAc "SELECT 1"
     docker exec stargate-postgres psql -U postgres -d idagent_keri -tAc "SELECT 1"
  6. docker logs stargate-idagent | grep -iE "migrat|incept|aid"      # DB migrated + AID incepted
  7. docker exec stargate-idagent id                                  # confirms uid 1001 can write /data/keri (no perm errors in logs)
  8. Stalwart: stalwart-cli query MtaHook  -> hook http://mailauth:8080/hook present, scoped off 'reinject'
  9. Send a test message through :25 -> arrives with an Authentication-Results header, NOT double-ARC-sealed on the mxengine round-trip
 10. scripts/health-check.sh -> stargate-idagent + stargate-mailauth green, both DBs green
 11. scripts/backup.sh -> idagent + idagent_keri dumps created; secret-idagent + secret-mailauth backed up
If step 7 shows permission errors on /data/keri: add an `idagent-data-fixer` init
container mirroring `vault-data-fixer` (chown -R 1001:1001 /data/keri).
```

- [ ] **Step 3: Final stage summary (do NOT commit)**

```bash
cd /home/petar/Repos/svdh/stargate-deployment
git status --short
git diff --stat
# Hand back to Petar for review + commit. Do NOT run git commit/push.
```

---

## Self-Review

**Spec coverage** (each spec section -> task):
- §4 idagent compose (image, ports, 2 DBs, Vault, volume, deps) -> Task 2 + Task 1 (DBs/mount).
- §4 mailauth compose (image, port, Vault, dashboard URL, fail-closed) -> Task 3 + Task 1 (mount).
- §5 #2 Postgres DBs -> Task 1. #3 Vault mounts -> Task 1. #4 provision.sh hook -> Task 4. #5 templates -> Task 5. #6 install.sh -> Task 5. #7 gather-app-versions -> Task 6. #8 health-check -> Task 6. #9 backup.sh -> Task 7.
- §6 D1 pre-create DBs -> Task 1. D2 fail closed -> Task 3 (`MAILAUTH_ALLOW_UNSIGNED=false`) + Task 4 (`tempFailOnError=true`). D3 IDAGENT_VERSION naming + legacy collision -> Task 5. D4 ports 8085/8086 -> Tasks 2/3/6.
- §7 image-not-published + §8 live smoke test -> Task 8 (deferred). `/data/keri` ownership fallback -> Task 8 Step 2.
- §5 note "no change to manifest.sh/restore.sh" -> honored (File Structure).

**Placeholder scan:** no TBD/TODO/"add error handling"/"similar to Task N" - every step has the exact literal text to insert and an explicit verify command. The empty-string `""` version values are intentional placeholders per Global Constraints, not plan gaps.

**Type/name consistency:** DB names `idagent`/`idagent_keri`, Vault mounts `secret-idagent`/`secret-mailauth`, container names `stargate-idagent`/`stargate-mailauth`, host ports `8085`/`8086`, env var names `IDAGENT_VERSION`/`MAILAUTH_VERSION`, hook URL `http://mailauth:8080/hook`, and volume `idagent_keri_data` are used identically across Tasks 1-8.
