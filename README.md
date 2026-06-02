# Stargate Deployment Instruction

> Please refer to our documentation under: <https://health-info-net-ag.github.io/Stargate-deployment/>

> ## $\textcolor{red}{\textsf{\textbf{⚠ ACTIVE DEVELOPMENT - NOT A FINAL PRODUCT}}}$
>
> $\textcolor{red}{\textsf{\textbf{Stargate (HIN MGW) is under active development.}}}$
>
> $\textcolor{red}{\textsf{\textbf{Interfaces, configuration, and behaviour may change between releases.}}}$

Recommendations and Expectations for the Alpha Phase

* As HIN MGW is still under rapid development, you should expect periodic requests to update your instance.
* We recommend preparing and using a test domain, not a production domain, during the alpha phase.
* If you have a test environment available, please perform the initial installation there and connect it to a test email system.
* Please do not use real production traffic before the official production release date. Routing production traffic during the alpha phase is done at your own risk.
  * During the Alpha and Beta testing phases, you are allowed to register any test domain you own. During the onboarding process, a CSR request will be sent to the HIN Test CA server, and the certificate will be issued automatically.

#### Beta phase

The beta phase will be announced separately. During beta, the system will still be connected to the HIN Test CA. Real traffic testing can begin once announced.

### Applications

* **smimekeys-client** - S/MIME keys client service (port 8081)
* **policy** - Policy service (port 8082)
* **irisagent** - IRIS Agent service (port 8083, WireGuard: 19818/tcp)
* **mxengine** - MX Engine service (port 8084, SMTP: 1587)
* **stalwart** - Stalwart MTA mail server (port 25, 10026)
* **mtaconf** - MTA configuration daemon (API: 8080)
* **dashboard** - Web-based admin UI for onboarding, domain management, and monitoring (port 443)
* **policy-sync** - Syncs OPA/Rego policies from Git repository to database (runs continuously)

## Docs

Build and test docs locally:

```shell
docker run --rm -it -p 8000:8000 --entrypoint /bin/sh -v ${PWD}:/docs squidfunk/mkdocs-material -c "pip install mkdocs-glightbox mkdocs-print-site-plugin && mkdocs serve --dev-addr=0.0.0.0:8000 --livereload"
```
