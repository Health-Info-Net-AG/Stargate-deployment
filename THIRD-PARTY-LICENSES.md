# Third-Party Licenses

This document lists the licenses of third-party software components used in the Stargate (HIN MGW) deployment.

---

## Dozzle

- **Component:** Dozzle - Real-time Docker log viewer
- **Image:** `amir20/dozzle:v10.5.0`
- **License:** MIT License
- **Copyright:** Copyright (c) 2025 Amir Raminfar
- **Source:** https://github.com/amir20/dozzle
- **License Text:** https://github.com/amir20/dozzle/blob/master/LICENSE

---

## PostgreSQL

- **Component:** PostgreSQL Database Server
- **Image:** `postgres:18-alpine`
- **License:** PostgreSQL License (BSD-like)
- **Copyright:** Copyright (c) 1996-2024, The PostgreSQL Global Development Group
- **Source:** https://www.postgresql.org/about/licence/
- **License Text:** https://www.postgresql.org/about/licence/

---

## Prometheus Node Exporter

- **Component:** Prometheus Node Exporter - System metrics collector
- **Image:** `prom/node-exporter:latest`
- **License:** Apache License 2.0
- **Copyright:** Copyright The Prometheus Authors
- **Source:** https://github.com/prometheus/node_exporter
- **License Text:** https://github.com/prometheus/node_exporter/blob/main/LICENSE

---

## Grafana Alloy

- **Component:** Alloy - Open-source OpenTelemetry Collector distribution
- **Image:** `grafana/alloy:v1.16.1`
- **License:** Apache License 2.0
- **Copyright:** Copyright Grafana Labs
- **Source:** https://github.com/grafana/alloy
- **License Text:** https://github.com/grafana/alloy/blob/main/LICENSE

---

## MinIO

- **Component:** MinIO - S3-compatible object storage
- **Image:** `minio/minio:latest`
- **License:** GNU Affero General Public License v3.0 (AGPL v3)
- **Copyright:** Copyright (c) 2015-2024 MinIO, Inc.
- **Source:** https://github.com/minio/minio
- **License Text:** https://github.com/minio/minio/blob/master/LICENSE

---

## HashiCorp Vault

- **Component:** HashiCorp Vault - Secrets management
- **Image:** `hashicorp/vault:1.19.0`
- **License:** Business Source License 1.1 (BUSL 1.1)
- **Copyright:** Copyright (c) 2024 IBM Corp.
- **Source:** https://github.com/hashicorp/vault
- **License Text:** https://github.com/hashicorp/vault/blob/main/LICENSE

---

## Stalwart Mail Server

- **Component:** Stalwart Mail Server (MTA)
- **Image:** `stalwartlabs/stalwart:v0.16`
- **License:** GNU Affero General Public License v3.0 (AGPL-3.0)
- **Copyright:** Copyright (c) 2020-2026 Stalwart Labs Ltd.
- **Source:** https://github.com/stalwartlabs/stalwart
- **License Text:** https://github.com/stalwartlabs/stalwart/blob/main/LICENSE

---

## Alpine Linux

- **Component:** Alpine Linux - Minimal Linux distribution (used as base for version-collector)
- **Image:** `alpine:latest`
- **License:** GPL v2+ (system components); individual packages have their own licenses
- **Copyright:** Copyright (c) 2012-2024 Alpine Linux Project
- **Source:** https://alpinelinux.org/
- **License Text:** https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/main/alpine-baselayout/LICENSE

---

## Docker

- **Component:** Docker Engine & Docker Compose (runtime)
- **License:** Apache License 2.0 (Moby project); Docker Engine uses various licenses
- **Source:** https://www.docker.com/
- **Note:** Docker is a runtime dependency, not distributed with this project.

---

## Summary

| Component | License | Type |
|---|---|---|
| Dozzle | MIT | Permissive |
| PostgreSQL | PostgreSQL License | Permissive |
| Node Exporter | Apache 2.0 | Permissive |
| Alloy | Apache 2.0 | Permissive |
| MinIO | AGPL v3 | Copyleft |
| HashiCorp Vault | BUSL 1.1 | Source-available |
| Stalwart | AGPL v3 | Copyleft |
| Alpine Linux | GPL v2+ | Copyleft (base OS) |

All components are used as unmodified Docker containers. No source code from these projects has been modified or incorporated into this repository.
