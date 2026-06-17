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
# OPTIONAL: Application Versions
# ==============================================================================
# Use "dev" for the latest development builds,
# or specify exact versions like "v0.0.3"

SMIMEKEYS_VERSION="v0.0.22"
POLICY_VERSION="v0.0.8"
IRISAGENT_VERSION="v0.0.7"
MXENGINE_VERSION="v0.0.47"
POLICY_SYNC_VERSION="latest"
DASHBOARD_VERSION="v0.0.85-test"
MTACONF_VERSION="v0.0.5"
OPS_AGENT_VERSION="dev"

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
POLICY_SYNC_VERSION="dev"

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

# APISIX admin API key (for the debug admin endpoint on port 9180)
APISIX_ADMIN_KEY=""  # Auto-generated if empty

# Public-facing URLs (must be reachable from the end-user's browser)
KEYCLOAK_PUBLIC_URL=""      # Default: https://<SERVER_STATIC_IP>:8180
DASHBOARD_PUBLIC_URL=""     # Default: https://<SERVER_STATIC_IP>

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
# Access at: http://localhost:8090
# Set to "true" to enable, "false" to disable.
# When enabled, a users.yml is auto-generated during install with the
# credentials below. Change the password after first login if desired.

DOZZLE_ENABLED="true"
DOZZLE_VERSION="v10.5.0"
DOZZLE_USERNAME="admin"
DOZZLE_PASSWORD=""

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
