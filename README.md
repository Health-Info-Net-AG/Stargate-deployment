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

## Docs

[![documentation](https://github.com/Health-Info-Net-AG/Stargate-deployment/actions/workflows/documentation.yml/badge.svg?branch=main)](https://github.com/Health-Info-Net-AG/Stargate-deployment/actions/workflows/documentation.yml)

Build and test docs locally:

<details>
<summary>Serve with live reload</summary>

```shell
docker run --rm -it -p 8000:8000 --entrypoint /bin/sh -v ${PWD}:/docs squidfunk/mkdocs-material -c "pip install mkdocs-glightbox mkdocs-print-site-plugin && mkdocs serve --dev-addr=0.0.0.0:8000 --livereload"
```

</details>

<details>
<summary>Multi languages build</summary>

```shell
docker run --rm -it -p 8000:8000 --entrypoint /bin/sh -v ${PWD}:/docs squidfunk/mkdocs-material -c "pip install mkdocs-glightbox mkdocs-print-site-plugin && mkdocs build -f config_docs/en/mkdocs.yml" && docker run --rm -it -p 8000:8000 --entrypoint /bin/sh -v ${PWD}:/docs squidfunk/mkdocs-material -c "pip install mkdocs-glightbox mkdocs-print-site-plugin && mkdocs build -f config_docs/de/mkdocs.yml" && docker run --rm -it -p 8000:8000 --entrypoint /bin/sh -v ${PWD}:/docs squidfunk/mkdocs-material -c "pip install mkdocs-glightbox mkdocs-print-site-plugin && mkdocs build -f config_docs/fr/mkdocs.yml" && docker run --rm -it -p 8000:8000 --entrypoint /bin/sh -v ${PWD}:/docs squidfunk/mkdocs-material -c "pip install mkdocs-glightbox mkdocs-print-site-plugin && mkdocs build -f config_docs/it/mkdocs.yml"
```

</details>
