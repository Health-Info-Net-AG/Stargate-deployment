# Stargate Deployment Instruction

> Please refer to our documentation under: <https://health-info-net-ag.github.io/Stargate-deployment/>


### Applications

* **smimekeys-client** - S/MIME keys client service (port 8081)
* **policy** - Policy service (port 8082)
* **irisagent** - IRIS Agent service (port 8083, WireGuard: 19818/tcp)
* **mxengine** - MX Engine service (port 8084, SMTP: 1587)
* **stalwart** - Stalwart MTA mail server (port 25, 10026)
* **clamav** - ClamAV antivirus; scans mail at Stalwart's SMTP DATA stage via the milter protocol (internal port 7357)
* **mtaconf** - MTA configuration daemon (API: 8080)
* **dashboard** - Web-based admin UI for onboarding, domain management, and monitoring (port 443)
* **policy-sync** - Syncs OPA/Rego policies from Git repository to database (runs continuously)

## Building an appliance image

Images are built by the **bootc** pipeline in `svdh/almalinux-bootc`, which this repository triggers. What gets
built is decided by *how* the pipeline starts, not by anything configured per build.

### What each way of starting builds

| Trigger | Job | Configuration | Formats |
|---|---|---|---|
| Push `vX.Y.Z`, `-rcN`, `-candidate`, any tag without a QA marker | `trigger_bootc_pipeline` | `prod` | all six |
| **New pipeline** on `main` | `trigger_bootc_pipeline` | `prod` | all six |
| **New pipeline** on any other branch | `build_test_image` | from the form | from the form |
| **New pipeline** on a tag containing `-test` or `-dev` | `build_test_image` | from the form | from the form |
| Push a tag containing `-test` or `-dev` | none — no pipeline is created | — | — |
| Push any branch | none — no pipeline is created | — | — |

On the two production rows the values are fixed in the pipeline, not read from the form, so a leftover
selection cannot reach a production build.

### Building a test image

**1. Create the tag.** Code → Tags → New tag, with `-test` or `-dev` in the name, e.g. `v0.5.9-testX`. The
marker is case-sensitive and needs the hyphen. **No pipeline starts** — that is deliberate: the environment is
selected when the pipeline is started, and a tag push carries no selection.

**2. Start the pipeline.** CI/CD → Pipelines → New pipeline, with the tag as the ref.

| Field | Default | Notes |
|---|---|---|
| `STARGATE_ENV` | `dev` | `dev`, `dev2` or `prod`. Needs a matching `docker-compose/config/environments/<env>.sh` on that ref. `prod` applies no preset |
| `IMAGE_TARGETS` | `hetzner proxmox` | The two platforms QA deploys to. `azure`, `hyperv`, `vmware` and `all` are available; `all` adds ~15 min |

One job runs, `build_test_image`. The manifest, release-notes and legacy VM image jobs are skipped for QA tags.

**3. Read what was built.** Open the downstream bootc pipeline; `build_image` states it near the top of the log:

```
stargate: v0.5.9-testX @ <sha> — env: dev
targets: hetzner proxmox — formats:  raw qcow2
```

**4. Take the directory name from the same log**, near the end:

```
Mirrored to root@…:/data2/images/bootctest/staging/<timestamp>-v0.5.9-testX
```

Copy it verbatim — builds queue, so the timestamp is when the *job* started, not when the pipeline was created.
That string is the `SOURCE_DIR` for the `stargate-image` job in `cluster-management-infra`, with
`IMAGE_FAMILY=bootc` and `IMAGE_CHANNEL=staging`.

The directory name carries no environment marker; the files inside it do:

| Files in the directory | Configuration |
|---|---|
| `…-<tag>-dev.x86_64.raw.gz` | `dev` preset baked in |
| `…-<tag>-dev2.x86_64.raw.gz` | `dev2` |
| `…-<tag>.x86_64.raw.gz` | `prod` |

A partial build ships only what its targets boot from, so a `hetzner proxmox` directory holds exactly
`CHECKSUM`, one `.raw.gz` and one `.qcow2`. The image's `io.verimesh.stargate-env` label says the same thing.

### Building a production image

Push a release tag, or run **New pipeline** on `main`. Both build `prod` with all six formats and mirror the
full artefact set.

A run from `main` publishes to the **staging** channel as `<timestamp>-main`; only a bare `vX.Y.Z` tag
publishes to `stable`. It also skips the manifest, release-notes and legacy VM image jobs, which require a tag,
so it produces a production *image* rather than a release.

## Docs

[![documentation](https://github.com/Health-Info-Net-AG/Stargate-deployment/actions/workflows/documentation.yml/badge.svg?branch=main)](https://github.com/Health-Info-Net-AG/Stargate-deployment/actions/workflows/documentation.yml)

Build and test docs locally:

<details>
<summary>Serve with live reload</summary>

You will be able to open documentation under http://localhost:8000

```shell
docker run --rm -it -p 8000:8000 --entrypoint /bin/sh -v ${PWD}:/docs squidfunk/mkdocs-material -c "pip install mkdocs-glightbox mkdocs-print-site-plugin && mkdocs serve --dev-addr=0.0.0.0:8000 --livereload -f config_docs/en/mkdocs.yml"
```

</details>

<details>
<summary>Multi languages build</summary>

```shell
docker run --rm -it -p 8000:8000 --entrypoint /bin/sh -v ${PWD}:/docs squidfunk/mkdocs-material -c "pip install mkdocs-glightbox mkdocs-print-site-plugin && mkdocs build -f config_docs/en/mkdocs.yml" && \
docker run --rm -it -p 8000:8000 --entrypoint /bin/sh -v ${PWD}:/docs squidfunk/mkdocs-material -c "pip install mkdocs-glightbox mkdocs-print-site-plugin && mkdocs build -f config_docs/de/mkdocs.yml" && \
docker run --rm -it -p 8000:8000 --entrypoint /bin/sh -v ${PWD}:/docs squidfunk/mkdocs-material -c "pip install mkdocs-glightbox mkdocs-print-site-plugin && mkdocs build -f config_docs/fr/mkdocs.yml" && \
docker run --rm -it -p 8000:8000 --entrypoint /bin/sh -v ${PWD}:/docs squidfunk/mkdocs-material -c "pip install mkdocs-glightbox mkdocs-print-site-plugin && mkdocs build -f config_docs/it/mkdocs.yml"
```

</details>
