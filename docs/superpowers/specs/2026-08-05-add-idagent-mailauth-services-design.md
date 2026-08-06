# Design: add `idagent` + `mailauth` services to the Stargate deployment

Date: 2026-08-05
Branch: `idagent+mailauth-integration`
Status: approved (direction), pending spec review

## 1. Goal

Add two new application services to the Docker Compose based Stargate mail
gateway, fully wired and default-on:

- **`idagent`** - a KERI decentralized-identity / anchoring service.
- **`mailauth`** - an email-authentication (SPF/DKIM/DMARC/ARC) gateway that
  plugs into Stalwart as a DATA-stage MTA hook.

"Fully wired" = compose service definitions, databases, Vault mounts, a
persistent volume, install/backup/health scripts, and the Stalwart MTA-hook
that actually routes mail through mailauth. Both start with the rest of the
stack (no opt-in profile).

## 2. What the two services are

### idagent (repo `code.vereign.com/svdh/idagent`, Go + cgo)

NOT the WireGuard agent. The name collides with `irisagent` ("formerly
idagent") but they share no code, ports, or purpose and coexist trivially.

- Incepts and manages a single Autonomic Identifier (AID); seals its Ed25519
  seeds in Vault; keeps a Key Event Log (KEL); exposes anchor/verify API
  (`POST /v1/anchor`, `POST /v1/anchor/verify`, `GET /v1/identity[...]`).
- Called by the **dashboard** to anchor DKIM public keys into the KEL. It is
  NOT part of the inline SMTP path.
- Single HTTP port 8080. Needs **two Postgres DBs** (identity + KEL), **Vault
  KV2**, and a **persistent local dir** `/data/keri` (redb cache, uid 1001).
- Self-creates its DBs and self-runs golang-migrate at startup; we pre-create
  the DBs anyway (see decision D1). glibc/Debian image (cgo links
  `libdkms_go.so`). No S3/NATS/metrics. `/liveness` + `/readiness`.

### mailauth (repo `code.vereign.com/svdh/mailauth`, Rust, stateless)

Email authentication, NOT user/API auth.

- Plugs into **Stalwart as a DATA-stage MTA hook over HTTP** (`POST /hook`).
  Inbound (unauthenticated): verify SPF/DKIM/DMARC/ARC, stamp
  `Authentication-Results`, ARC-seal. Outbound (authenticated submission):
  **DKIM-sign** (rsa-2048 only). Direction is decided by presence of a
  non-empty SASL login in the hook payload.
- Single HTTP port 8080. **No database.** Reads DKIM/ARC private keys from
  **Vault KV2** on every request (never cached). Per-domain config is a JSON
  document pulled from the **dashboard** on boot (`MAILAUTH_DASHBOARD_CONFIG_URL`)
  or pushed via `POST /config`; unconfigured domains pass through untouched.
- `scratch` image, uid 10001, fully stateless. `/liveness` (always 200) +
  `/readiness` (200 only if Vault reachable). No `/metrics`.

## 3. Target mail flow (mailauth)

```
external  --> Stalwart :25   --[DATA: mailauth verify+seal -> clamav]--> mxengine :1587 --> ... --> Stalwart :10026 (reinject; mailauth NOT re-run) --> backend
submission (authenticated)   --[DATA: mailauth DKIM-sign]--> outbound
```

The MTA hook is scoped to run on every listener **except `reinject`**, so it
runs once on ingress/submission and not on the mxengine round-trip - avoiding
a duplicate `Authentication-Results` header and a double ARC seal. This mirrors
the existing ClamAV milter's listener scoping in `provision.sh`.

## 4. Compose service shapes

| Aspect | idagent | mailauth |
|---|---|---|
| Image | `healthinfonetag/idagent:${IDAGENT_VERSION:-dev}` | `healthinfonetag/mailauth:${MAILAUTH_VERSION:-dev}` |
| Host port | `8085:8080` | `8086:8080` |
| Databases | `idagent` (identity) + `idagent_keri` (KEL) | none |
| Vault mount | `secret-idagent` | `secret-mailauth` |
| Volume | `idagent_keri_data:/data/keri` (uid 1001) | none |
| S3 / NATS / metrics | none | none |
| depends_on | `postgres` (healthy), `vault-init` (completed) | `vault-init` (completed), `dashboard` (healthy) |
| Config source | env only | dashboard `?service=mailauth`, fallback `POST /config` |
| Healthcheck | none in compose (autoheal label + depends_on) | none (scratch has no shell) |

### idagent environment (concrete)

```
LOG_LEVEL: "info"
HTTP_HOST: ""
HTTP_PORT: "8080"
HTTP_IDLE_TIMEOUT: "180s"
HTTP_READ_TIMEOUT: "60s"
HTTP_WRITE_TIMEOUT: "60s"
DB_URI:  "postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/idagent"
KERI_DB_URL: "postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/idagent_keri"
KERI_DB_PATH: "/data/keri"
VAULT_ADDRESS: "http://vault:8200"
VAULT_TOKEN: "${VAULT_TOKEN}"
VAULT_MOUNT_PATH: "secret-idagent"
VAULT_KV2_MAX_VERSIONS: "2"
VAULT_KV2_CAS_REQUIRED: "false"
VAULT_KV2_DELETE_VERSION_AFTER: "0s"
KERI_WITNESSES: "[]"            # local-only KEL, no external witness pool
KERI_WITNESS_THRESHOLD: "0"
```

Volume `idagent_keri_data` mounted at `/data/keri`, plus `autoheal=true` label
and the `stargate-network`.

### mailauth environment (concrete)

```
MAILAUTH_BIND_ADDR: "0.0.0.0:8080"
MAILAUTH_MAX_BODY_MB: "50"
MAILAUTH_VAULT_ADDRESS: "http://vault:8200"
MAILAUTH_VAULT_TOKEN: "${VAULT_TOKEN}"
MAILAUTH_VAULT_MOUNT_PATH: "secret-mailauth"
MAILAUTH_DASHBOARD_CONFIG_URL: "http://dashboard:3000/api/internal/installation-config?service=mailauth"
MAILAUTH_ALLOW_UNSIGNED: "false"   # fail closed (see D2)
RUST_LOG: "info"
```

Plus `autoheal=true` and `stargate-network`. No volume, no DB.

## 5. Files to change (all in `stargate-deployment`)

1. **`docker-compose/docker-compose.yml`** - two service blocks + a new named
   volume `idagent_keri_data`.
2. **`docker-compose/init/postgres/01-create-databases.sql`** - add
   `CREATE DATABASE idagent;` and `CREATE DATABASE idagent_keri;` + matching
   `GRANT ALL PRIVILEGES ... TO postgres;` (decision D1).
3. **`docker-compose/scripts/init-vault.sh`** - add KV-v2 mounts
   `secret-idagent` and `secret-mailauth`.
4. **`docker-compose/config/stalwart/provision.sh`** - add a `create_mta_hook`
   helper and call it for mailauth, mirroring the confirmed-working workspace
   script (`workspace/mailauth/stalwart/provision.sh`): `MtaHook` with
   `url=http://mailauth:8080/hook`, `stages={"data":true}`,
   `tempFailOnError=true` (D2), `enable` scoped to `listener != 'reinject'`.
   Idempotent (identify existing hook by URL), same style as `create_milter`.
   This is the ONLY addition to `provision.sh` - listeners, routes, and the
   auth/relay stage gates remain owned by **mtaconf** (which applies dashboard
   intent via the Stalwart CLI). The `listener != 'reinject'` scope
   automatically covers whatever ingress/submission listeners mtaconf
   provisions, so mailauth signs authenticated submission and verifies
   unauthenticated ingress without provision.sh duplicating mtaconf's stage
   config. The workspace script hardcodes those stages only because it has no
   mtaconf.
5. **`docker-compose/customer-config-prod.example.sh`** and the other
   `customer-config.*` templates (`.alpha`, `-alpha-new`, `.gamma`, `.test`) -
   add `IDAGENT_VERSION` and `MAILAUTH_VERSION` **placeholder** entries with a
   comment noting the images must be published before these are pinned.
6. **`docker-compose/scripts/install.sh`** - add `IDAGENT_VERSION` /
   `MAILAUTH_VERSION` to the version defaults block (~L131) and to the `.env`
   writeout heredoc (~L273).
7. **`docker-compose/scripts/gather-app-versions.sh`** - add a `get_version`
   line for idagent (port 8080). Add mailauth only if its `/liveness` emits a
   version field (verify during implementation; the sed is harmless if absent).
8. **`docker-compose/scripts/health-check.sh`** - add both containers to the
   container list, host ports (idagent 8085, mailauth 8086) to the HTTP checks,
   and `idagent`, `idagent_keri` to the DB list. No metrics-port entries.
9. **`docker-compose/scripts/backup.sh`** - add `idagent` and `idagent_keri` to
   the `DATABASES` array (L105) and `secret-idagent`, `secret-mailauth` to the
   `VAULT_MOUNTS` array (L235).

No change needed to `manifest.sh` (its `*_VERSION` apply logic is generic, so
`update.sh --release` applies `IDAGENT_VERSION` / `MAILAUTH_VERSION`
automatically once they appear in a release manifest) or `restore.sh` (reads
the backup's own manifest, also generic).

## 6. Decisions

- **D1 - Pre-create idagent's two DBs in init SQL.** Deterministic, matches how
  every other service DB is provisioned; idagent's self-create path remains a
  harmless fallback.
- **D2 - Fail closed.** `tempFailOnError=true` on the MTA hook +
  `MAILAUTH_ALLOW_UNSIGNED=false`. If mailauth is down or a configured domain's
  signing fails, mail is deferred (451) rather than passed unsigned/unverified -
  matching the ClamAV milter's fail-closed stance.
- **D3 - `IDAGENT_VERSION` names the new KERI service.** The historical
  `IDAGENT_VERSION` (old alpha `.env`) referred to the WireGuard agent, which
  prod has since renamed to `IRISAGENT_VERSION`, freeing the name for the actual
  `idagent` repo.
- **D4 - Host ports 8085 (idagent) / 8086 (mailauth).** Both free; neither
  service exposes `/metrics`, so no metrics-port mappings.

## 7. Risks / prerequisites

- **Default-on requires the images to exist first (tracked, publishing soon).**
  `healthinfonetag/idagent` and `/mailauth` are not on Docker Hub yet. Their CI
  is being set up to publish and the maintainer expects tags soon. Until then a
  fresh `docker compose up` / `update.sh` would fail to pull them, so the
  placeholder version vars must be set to real tags before this is rolled out to
  an env. The integration is written to be correct the moment the images land.
- **Stalwart MTA-hook must be smoke-tested live.** The reference `provision.sh`
  (`workspace/mailauth/stalwart/provision.sh`) is explicitly unverified. Adapt
  the hook creation conservatively and test on a disposable box (alpha) before
  it reaches customers.
- **Outbound direction detection - RESOLVED by the devs (superseded my
  `!= reinject` approach).** My original design assumed SASL-based direction and
  scoped the hook `listener != 'reinject'`. The mailauth devs replaced that: as
  of mailauth commit `99a237b` ("remove sasl and use domains for in and out
  flow") direction is a **domain role, not SASL** - a hosted domain in the
  *sender* is outbound (DKIM-sign, deferred to the egress leg), a hosted domain
  in the *recipient* is inbound (verify + stamp + ARC-seal on ingress). The
  egress leg is identified by `server.port == reinject_port`. So mailauth must
  see **both** SMTP legs, and deployment commit `c2def5a` corrected the hook to
  scope `listener == 'smtp' || listener == 'reinject'` and added
  `MAILAUTH_REINJECT_PORT: "10026"` to the mailauth service. My `!= reinject`
  scope would have dropped all signing/sealing (signing happens on the egress
  leg). The correct wiring is now on the branch via `c2def5a`.
- **`/data/keri` volume ownership.** idagent runs as uid 1001 and its image
  creates `/data/keri` owned by 1001; Docker prepopulates a fresh named volume
  with the image dir's ownership, so this should just work. If live testing
  shows permission errors, add an `idagent-data-fixer` init container mirroring
  `vault-data-fixer`.
- **Dashboard-side work is out of scope but required for function.** For the
  feature to do anything the dashboard must expose `?service=mailauth` config,
  write DKIM keys into the `secret-mailauth` Vault mount at the advertised
  `vault_path`, and call idagent to anchor public keys. This repo can only wire
  the URLs/mounts.
- **Name reuse of the retired idagent's DB/mount (verified low-risk).** The
  KERI idagent's identity DB (`idagent`) and Vault mount (`secret-idagent`) reuse
  the exact names the retired WireGuard agent used before it was renamed to
  `irisagent`. That rename (commit `3897832`) only renamed the names *forward* in
  the init scripts; it never DROPPED the old DB/mount, and init SQL / init-vault
  run only on a fresh volume. So a box provisioned before the rename and never
  purged could still carry a stale `idagent` DB (old WireGuard tables) that the
  KERI migrations would then run against. Empirically checked 2026-08-05:
  stargate-alpha and stargate-gamma both have `irisagent` (DB + `secret-irisagent`
  mount) only, no stale `idagent` - so fresh installs and both test boxes are
  clean. Mitigation (chosen): a pre-flight collision guard in the rollout smoke
  test asserts no pre-existing non-KERI `idagent` DB before enabling idagent on a
  box (see plan Task 8 step 0). Not renaming the service's DB/mount, since the
  evidence is clean and the natural name is preferred.
- **idagent identity is stateful.** AID seeds (Vault `secret-idagent`) + KEL
  (`idagent_keri` DB) must survive backup/restore or the identity is lost - both
  covered by change #9. `/data/keri` redb is a rebuildable cache.

## 8. Verification

- `bash -n` on every changed script; `shellcheck` if available.
- `docker compose config` parses cleanly with the two new services + volume.
- On a disposable box (alpha), with the images available:
  - both containers start, `/liveness` + `/readiness` return 200 (mailauth
    readiness only once Vault is up);
  - `idagent` and `idagent_keri` DBs exist and idagent migrates cleanly;
  - `/data/keri` is writable by uid 1001;
  - Stalwart shows the mailauth MtaHook scoped off `reinject`; a test message
    through :25 gets an `Authentication-Results` header and is not double-sealed
    on the mxengine round-trip;
  - `health-check.sh` reports both green; `backup.sh` dumps both new DBs and the
    new Vault mounts.

## 9. Out of scope

- Publishing the two images (their own repos' CI).
- Dashboard endpoints, Vault key-writing, and idagent anchoring calls
  (dashboard/service repos).
- Docs updates (`docs/en/*`, translations) for the two new services - fold in
  separately if wanted.
- Any change to the WireGuard `irisagent`.

## 11. KERI witness/watcher topology (follow-on increment)

For idagent's anchored keys to be verifiable across deployments, it needs a KERI
witness/watcher infrastructure. Topology (per the idagent devs):

- **Witnesses = one shared, central pool for all deployments** (HIN infra), NOT
  per-deployment. idagent references them via `KERI_WITNESSES` + a threshold.
- **Watcher = one per deployment**, added here behind the `keri-watcher` compose
  profile (off by default). It fetches/validates external AIDs' KELs from the
  pool for idagent's `POST /v1/anchor/verify` against a foreign AID. A deployment
  that only verifies its own anchors needs no watcher.
- **keriox image** = `healthinfonetag/keriox-tools` (witness+watcher binaries),
  built from source at the keriox commit that idagent's dkms-bindings pin
  (`59d5ff5`); the published `:0.17.13` images do NOT match and fail inception
  with `AttachmentError`. Built by the separate `keriox-tools` repo/CI.

What this repo added (all default-safe / local-only unless configured):

- idagent env `KERI_WITNESSES` / `KERI_WITNESS_THRESHOLD` / `KERI_WATCHER_OOBI`
  made configurable via customer-config (empty / 0 = local-only, today's
  behavior). JSON values are single-quoted in `.env` so their quotes survive.
- `idagent-data-fixer` init (chowns `/data/keri` to uid 1001) so idagent can
  write its redb cache regardless of how the named volume was created.
- `watcher` service (profile `keri-watcher`) + `config/keri/watcher.yml.example`
  (operator copies to the gitignored `watcher.yml`, fills the fixed seed + pool
  OOBIs) + `watcher_data` volume + optional health-check entry.

**Rollout ordering (critical):** the shared witness pool must be reachable
**before** an idagent starts with a non-zero `KERI_WITNESS_THRESHOLD` - otherwise
inception fails without witness receipts. Order: stand up + verify the witness
pool → fill idagent's `KERI_WITNESSES`/threshold → then (re)start idagent. A
watcher's fixed seed is its stable identity: a new seed on restart changes its
AID and breaks every controller that designated it, so seed + persistent volume
are mandatory.

Still external / not in this repo: standing up the shared witness pool and its
OOBIs, publishing the keriox-tools image, and generating/sealing the watcher
seed. Until those exist, idagent runs local-only and the watcher profile stays
off - nothing here breaks in the meantime.
