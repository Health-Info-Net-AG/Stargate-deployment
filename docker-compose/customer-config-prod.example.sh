#!/bin/bash
# ==============================================================================
# Stargate Customer Configuration - TEMPLATE
# ==============================================================================
# Copy this file to customer-config.sh and fill in your values:
#   cp customer-config-prod.example.sh customer-config.sh
#
# IMPORTANT: Replace ALL placeholder values below with your actual configuration!
# ==============================================================================

# ==============================================================================
# REQUIRED: Server Network Configuration
# ==============================================================================

# Static IP address of this VM/server.
# This is the single network identity for the deployment - used to derive:
#   - WireGuard local IP (unique tunnel address)
#   - MXEngine address
#   - Keycloak and Dashboard public URLs
# Can be a private IP if the VM is behind NAT. Auto-detected if left empty.
SERVER_STATIC_IP=""

# ==============================================================================
# REQUIRED: Customer Identification
# ==============================================================================

# Customer/Organization name (used for identification and logging)
CUSTOMER_NAME="Production"

# Deployment name (used for log labels and identification)
DEPLOYMENT_NAME="stargate"

# ==============================================================================
# OPTIONAL: MXEngine public address
# ==============================================================================

# MXEngine public address (for seal strategy callbacks)
# Auto-derived from SERVER_STATIC_IP if left empty: http://<SERVER_STATIC_IP>:8084
# Override only if behind a reverse proxy or using a custom hostname.
MXENGINE_PUBLIC_ADDRESS=""

# ==============================================================================
# REQUIRED: S/MIME Certificate Configuration
# ==============================================================================

# CA IRIS AGENT domain for certificate issuance via WireGuard tunnel
CERT_CA_IRISAGENT_DOMAIN="hin"

# ==============================================================================
# AUTO-GENERATED: Vault Configuration
# ==============================================================================
# The Vault root token is auto-generated during first installation.
# After install.sh runs, this value will be populated automatically.
# DO NOT set this manually - Vault 1.19+ does not support custom root tokens.
# The token is saved here so it persists across VM recreations.

VAULT_TOKEN=""

# ==============================================================================
# OPTIONAL: Database Configuration
# ==============================================================================
# Leave empty to auto-generate secure passwords

POSTGRES_USER=""
POSTGRES_PASSWORD=""

# ==============================================================================
# OPTIONAL: Object Storage Configuration (SeaweedFS)
# ==============================================================================
# Leave empty to auto-generate secure passwords

S3_ACCESS_KEY=""
S3_SECRET_KEY=""
S3_BUCKET_NAME="stargate-bucket"

# ==============================================================================
# OPTIONAL: KERI topology (idagent)
# ==============================================================================
# Points at the shared HIN production witness pool over its public https endpoints.
#
# KERI_WITNESSES: a JSON ARRAY of the pool's OOBI objects, SINGLE-quoted so the inner
# double-quotes survive in .env. Each element is a FULL OOBI object {eid, scheme, url}
# - not a bare URL. `scheme` must match the scheme the witness advertises in its
# /loc/scheme reply: idagent looks the OOBI up by the (eid, scheme) pair, so an entry
# whose scheme differs from the witness's own resolves to "No oobi" and inception fails.
# KERI_WITNESS_THRESHOLD: receipts required at inception; must be <= the number of
# witnesses. IMPORTANT: with threshold > 0 the pool MUST be reachable before idagent's
# FIRST start, or inception fails without receipts and the container will not come up.
# Set both to '[]' / "0" for a local-only deployment with no witnesses.
KERI_WITNESSES='[{"eid":"BMGbBCw5I-zLanhgJdRXQ-EU4G61P7M8jTpFrstK5ArZ","scheme":"https","url":"https://witness-1.verify-mail.hin-infra.ch/"},{"eid":"BJGVotztVGSfp5mJbr4zUgd5X0fOh3OVMrhoAWLODR4O","scheme":"https","url":"https://witness-2.verify-mail.hin-infra.ch/"},{"eid":"BEq3J1mCOXGj-Pe9FFXIga16BiTSFwU0TS4SLfCCorBZ","scheme":"https","url":"https://witness-3.verify-mail.hin-infra.ch/"}]'
KERI_WITNESS_THRESHOLD="2"
#
# KERI_WATCHER_OOBI: a SINGLE watcher OOBI object (one {eid, scheme, url}, NOT an
# array), SINGLE-quoted. Only needed to verify OTHER orgs' anchors - enable the
# per-deployment watcher via `--profile keri-watcher`; leave empty otherwise.
# Example: KERI_WATCHER_OOBI='{"eid":"BF2t...","scheme":"http","url":"http://watcher-host:3235/"}'
KERI_WATCHER_OOBI=''

# ==============================================================================
# OPTIONAL: Advanced Mail Configuration
# ==============================================================================

# Sealer MX domain for outbound seal delivery
OUTBOUND_SEALER_MX_DOMAIN="hin"

# SMTP host for outbound delivery (default: stalwart)
# Override only if using an external MTA
OUTBOUND_SMTP_HOST=""
# External SMTP port for outbound delivery (default: 10026)
OUTBOUND_SMTP_PORT=""

# ==============================================================================
# OPTIONAL: Policy Sync Configuration
# ==============================================================================
# policy-sync syncs OPA/Rego policies from a Git repository to the database.
# The service runs automatically and syncs at the configured interval.
# Contact Vereign for the policy repository URL and credentials.

POLICY_SYNC_REPO_URL="https://github.com/Health-Info-Net-AG/Stargate-policies.git"
POLICY_SYNC_REPO_USER=""
POLICY_SYNC_REPO_PASS=""
POLICY_SYNC_REPO_BRANCH=""
POLICY_SYNC_REPO_FOLDER=""
POLICY_SYNC_INTERVAL="1h"

# ==============================================================================
# OPTIONAL: Monitoring Configuration
# ==============================================================================

LOKI_URL=""

# ==============================================================================
# OPTIONAL: Keycloak / APISIX / Dashboard Configuration
# ==============================================================================

# Keycloak admin console credentials
KEYCLOAK_ADMIN_USER="admin"
KEYCLOAK_ADMIN_PASSWORD=""  # Auto-generated if empty

# Generate strong random values (e.g. openssl rand -hex 32).
# IMPORTANT: change from defaults before exposing Keycloak to any network.
KEYCLOAK_APISIX_CLIENT_SECRET=""    # Auto-generated if empty
KEYCLOAK_DASHBOARD_CLIENT_SECRET="" # Auto-generated if empty
KEYCLOAK_DOZZLE_CLIENT_SECRET=""    # Auto-generated if empty (Dozzle login via oauth2-proxy)
OAUTH2_PROXY_COOKIE_SECRET=""       # Auto-generated if empty (oauth2-proxy session cookie)

# APISIX admin key. Required because config.yaml references it, but the Admin API
# itself is never served: APISIX runs standalone (deployment.role: data_plane,
# config_provider: yaml), where routes come from apisix.yaml and no admin listener
# is started. Nothing reachable is protected by this value.
APISIX_ADMIN_KEY=""  # Auto-generated if empty

# Public-facing URLs (must be reachable from the end-user's browser)
KEYCLOAK_PUBLIC_URL=""      # Default: https://<SERVER_STATIC_IP>:8180
DASHBOARD_PUBLIC_URL=""     # Default: https://<SERVER_STATIC_IP>
DOZZLE_PUBLIC_URL=""        # Default: https://<SERVER_STATIC_IP>:8190

# Show developer pages in the dashboard UI
DASHBOARD_SHOW_DEV_PAGES="false"

# Root instance URL (the central APISIX gateway that this instance connects to)
DASHBOARD_ROOT_URL="https://apisix.verify-mail.hin-infra.ch"
# Root domain (used for cross-instance service discovery)
DASHBOARD_ROOT_DOMAIN="hin"

# ==============================================================================
# OPTIONAL: Stalwart MTA Configuration
# ==============================================================================
# Stalwart is the mail transfer agent (replaces postfixconf).
# Credentials are auto-generated if left empty.

# Recovery admin password (used for initial setup and CLI access)
STALWART_ADMIN_PASSWORD=""  # Auto-generated if empty

# Password for mtaconf's internal admin account (used to authenticate
# against the Stalwart management API). Auto-generated if empty.
# The account's username/domain are hardcoded synthetic values inside
# provision.sh and intentionally not exposed here. The operator's real
# mail hostname is set later via the dashboard form (mtaconf overwrites
# SystemSettings.defaultHostname on apply).
MTACONF_SVC_PASSWORD=""  # Auto-generated if empty

# ==============================================================================
# OPTIONAL: Dozzle - Real-time Log Viewer
# ==============================================================================
# Dozzle provides a web UI to view live logs from all Stargate containers.
# When enabled it is published at DOZZLE_PUBLIC_URL (default
# https://<SERVER_STATIC_IP>:8190) behind oauth2-proxy, which authenticates
# against the same Keycloak realm as the dashboard. Log in with any user from
# the "stargate" realm (e.g. sg-admin) - there are no separate Dozzle credentials.
# Set to "true" to enable, "false" to disable.

DOZZLE_ENABLED="true"

# ==============================================================================
# REQUIRED: WireGuard Configuration
# ==============================================================================
# Local WireGuard settings for this IRIS AGENT instance.
# Contact Vereign to get your assigned WireGuard IP address.

# WireGuard private key (optional - auto-generated if empty, then saved back here)
# After first install, this will be populated automatically so the key persists
# across VM recreations. KEEP THIS FILE BACKED UP!
# The public key will be printed during install — share it with the HIN team
# so they can register your instance as a peer.
WG_PRIVATE_KEY=""

# WireGuard local IP — auto-derived from SERVER_STATIC_IP if left empty.
# Override only if you need a different tunnel address.
WG_LOCAL_IP=""

# WireGuard interface port (default: 19818)
WG_INTERFACE_PORT="19818"

# WireGuard transport mode: "tcp" (default) or "udp"
# Set to "udp" only if TCP tunneling causes issues
WG_TRANSPORT_MODE=""

# ==============================================================================
# END OF CONFIGURATION
# ==============================================================================
