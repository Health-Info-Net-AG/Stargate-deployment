#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$PROJECT_DIR/secrets"
KEYS_FILE="$SECRETS_DIR/vault-keys.json"
ENV_FILE="$PROJECT_DIR/.env"
CONFIG_FILE="$PROJECT_DIR/customer-config.sh"

# Determine Linux distribution:
if [ -f /etc/os-release ]; then
	DIST_ID=$(grep ^ID= /etc/os-release |cut -f2 -d=|sed s/\"//g)
else
	echo "File /etc/os-release not found, cannot determine Linux distribution."
	exit 1
fi

if [[ $DIST_ID == debian || $DIST_ID == ubuntu || $DIST_ID == linuxmint || $DIST_ID == kali  ]] ; then
	PKGMGR=apt
else
	PKGMGR=dnf
fi

cd "$PROJECT_DIR"

echo "============================================"
echo "  Stargate Installation"
echo "============================================"
echo ""

# Check if already installed
if [ -f "$KEYS_FILE" ]; then
  echo "ERROR: Installation already completed."
  echo "Vault keys found at: $KEYS_FILE"
  echo ""
  echo "To start services, use: ./scripts/start.sh"
  echo "To reinstall, first run: ./scripts/purge.sh"
  exit 1
fi

install_docker() {
  echo "Installing Docker from official repository..."
  if [[ $PKGMGR == apt ]] ; then
	  sudo $PKGMGR update -y && sudo $PKGMGR upgrade -y
	  sudo $PKGMGR remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc 2>/dev/null || true
	  sudo $PKGMGR install -y ca-certificates curl
	  # Add Docker's official GPG key
	  sudo install -m 0755 -d /etc/apt/keyrings
	  sudo curl -fsSL https://download.docker.com/linux/$DIST_ID/gpg -o /etc/apt/keyrings/docker.asc
	  sudo chmod a+r /etc/apt/keyrings/docker.asc
	  # Add the repository
	    echo \
		    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$DIST_ID \
		    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
		    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	  sudo $PKGMGR update -y
  else
	  sudo $PKGMGR update -y
	  sudo $PKGMGR remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman runc
	  sudo rpm --import https://download.docker.com/linux/rhel/gpg
	  sudo $PKGMGR -y install dnf-plugins-core
	  sudo $PKGMGR config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
  fi
  # Install Docker
  sudo $PKGMGR install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin jq
  echo "Docker installed successfully!"
  sudo systemctl enable --now docker
  docker --version
  docker compose version
}

check_dependencies() {
  local missing=()

  if ! command -v docker &> /dev/null; then
    missing+=("docker")
  fi

  if ! docker compose version &> /dev/null 2>&1; then
    missing+=("docker-compose-plugin")
  fi

  if ! command -v jq &> /dev/null; then
    missing+=("jq")
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing dependencies: ${missing[*]}"
    echo ""
    echo "Installing Docker and dependencies..."
    install_docker
  fi
}

# Function to update .env file with vault token
update_env_token() {
  local token="$1"
  if grep -q "^VAULT_TOKEN=" "$ENV_FILE"; then
      sed -i "s/^VAULT_TOKEN=.*/VAULT_TOKEN=\"$token\"/" "$ENV_FILE"
  else
    echo "VAULT_TOKEN=\"$token\"" >> "$ENV_FILE"
  fi
  echo "Updated VAULT_TOKEN in .env file"
}

# Generate a random password
generate_password() {
  local length=${1:-24}
  tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

# Generate UUID v7 (time-ordered UUID)
# Format: tttttttt-tttt-7xxx-yxxx-xxxxxxxxxxxx
# where t=timestamp(ms), 7=version, y=variant(8-b), x=random
generate_uuid7() {
  # Get current timestamp in milliseconds
  local ts_ms=$(date +%s%3N)
  # Convert to hex (48 bits = 12 hex chars)
  local ts_hex=$(printf '%012x' "$ts_ms")
  # Generate random bytes (need 10 bytes = 20 hex chars) using od (more portable than xxd)
  local rand=$(head -c 10 /dev/urandom | od -An -tx1 | tr -d ' \n')
  # Build UUID v7:
  # Positions: tttttttt-tttt-7rrr-Vrrr-rrrrrrrrrrrr
  # Extract parts
  local time_high="${ts_hex:0:8}"
  local time_mid="${ts_hex:8:4}"
  local rand_a="${rand:0:3}"
  local variant_byte=$((0x80 | (0x${rand:3:2} & 0x3f)))
  local variant_hex=$(printf '%02x' "$variant_byte")
  local rand_b="${rand:5:2}"
  local rand_c="${rand:7:12}"
  # Format: xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
  echo "${time_high}-${time_mid}-7${rand_a}-${variant_hex}${rand_b}-${rand_c}"
}

# ==============================================================================
# Customer Configuration Loading
# ==============================================================================

load_customer_config() {
  echo "============================================"
  echo "  Loading Customer Configuration"
  echo "============================================"
  echo ""

  # Bootstrap customer-config.sh from the example if it doesn't exist yet,
  # so a fresh deployment works with zero manual setup. The customer can edit
  # the file later to override defaults or set optional knobs (LOKI_URL,
  # OUTBOUND_SMTP_HOST, etc.). Generated values (vault token, IP, etc.) get
  # written back here as install progresses.
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "customer-config.sh not found, bootstrapping from customer-config.example..."
    cp "$PROJECT_DIR/customer-config.example" "$CONFIG_FILE"
  fi

  # Source the config file
  source "$CONFIG_FILE"

  # Sensible defaults for identification fields. Customer can override in
  # customer-config.sh; if left empty, derive from the system hostname so
  # the install completes without manual input on a fresh VM.
  CUSTOMER_NAME="${CUSTOMER_NAME:-$(hostname)}"
  DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-${CUSTOMER_NAME}-stargate}"

  # Set defaults for optional fields
  POSTGRES_USER="${POSTGRES_USER:-postgres}"
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(generate_password)}"
  MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
  MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-$(generate_password)}"
  S3_BUCKET_NAME="${S3_BUCKET_NAME:-stargate-bucket}"

  SMIMEKEYS_VERSION="${SMIMEKEYS_VERSION:-dev}"
  POLICY_VERSION="${POLICY_VERSION:-dev}"
  IRISAGENT_VERSION="${IRISAGENT_VERSION:-dev}"
  MXENGINE_VERSION="${MXENGINE_VERSION:-dev}"
  DASHBOARD_VERSION="${DASHBOARD_VERSION:-dev}"

  # Derive WG_LOCAL_IP and MXENGINE_PUBLIC_ADDRESS from SERVER_STATIC_IP
  SERVER_STATIC_IP="${SERVER_STATIC_IP:-}"
  if [ -z "$SERVER_STATIC_IP" ] && [ -n "$WG_LOCAL_IP" ] && [ "$WG_LOCAL_IP" != "10.0.0.1" ]; then
    # Backward compatibility: if SERVER_STATIC_IP not set but WG_LOCAL_IP is, use that
    SERVER_STATIC_IP="$WG_LOCAL_IP"
  fi

  # Auto-detect SERVER_STATIC_IP if still unset.
  # Uses the source IP of the default route (the VM's primary interface IP).
  # This can be a private IP if the VM is behind NAT - that's fine.
  if [ -z "$SERVER_STATIC_IP" ]; then
    SERVER_STATIC_IP=$(ip -4 route get 1.1.1.1 2>/dev/null \
      | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    if [ -n "$SERVER_STATIC_IP" ]; then
      echo "Auto-detected SERVER_STATIC_IP=$SERVER_STATIC_IP"
      # Persist back to customer-config.sh so subsequent runs are idempotent.
      if [ -f "$CONFIG_FILE" ] && grep -q '^SERVER_STATIC_IP=' "$CONFIG_FILE"; then
        sed -i "s|^SERVER_STATIC_IP=.*|SERVER_STATIC_IP=\"$SERVER_STATIC_IP\"|" "$CONFIG_FILE"
      fi
    fi
  fi

  if [ -z "$SERVER_STATIC_IP" ]; then
    echo "ERROR: SERVER_STATIC_IP is required and could not be auto-detected."
    echo "  Set it to this server's network IP address."
    echo "  Example: SERVER_STATIC_IP=\"10.0.1.50\""
    exit 1
  fi

  WG_LOCAL_IP="${WG_LOCAL_IP:-$SERVER_STATIC_IP}"
  MXENGINE_PUBLIC_ADDRESS="${MXENGINE_PUBLIC_ADDRESS:-http://${SERVER_STATIC_IP}:8084}"
  KEYCLOAK_PUBLIC_URL="${KEYCLOAK_PUBLIC_URL:-https://${SERVER_STATIC_IP}:8180}"
  DASHBOARD_PUBLIC_URL="${DASHBOARD_PUBLIC_URL:-https://${SERVER_STATIC_IP}}"

  OUTBOUND_SEALER_MX_DOMAIN="${OUTBOUND_SEALER_MX_DOMAIN:-hintest.ch}"
  CERT_CA_IRISAGENT_DOMAIN="${CERT_CA_IRISAGENT_DOMAIN:-hintest.ch}"

  OUTBOUND_SMTP_HOST="${OUTBOUND_SMTP_HOST:-stalwart}"
  OUTBOUND_SMTP_PORT="${OUTBOUND_SMTP_PORT:-10026}"
  MTACONF_VERSION="${MTACONF_VERSION:-dev}"

  # Stalwart MTA
  STALWART_ADMIN_PASSWORD="${STALWART_ADMIN_PASSWORD:-$(generate_password)}"
  MTACONF_SVC_USER="${MTACONF_SVC_USER:-mtaconf-svc}"
  MTACONF_SVC_DOMAIN="${MTACONF_SVC_DOMAIN:-${OUTBOUND_SEALER_MX_DOMAIN:-hintest.ch}}"
  MTACONF_SVC_PASSWORD="${MTACONF_SVC_PASSWORD:-$(generate_password)}"
  STALWART_HOSTNAME="${STALWART_HOSTNAME:-mail.${MTACONF_SVC_DOMAIN}}"

  LOKI_URL="${LOKI_URL:-}"

  # Keycloak / APISIX / Dashboard
  KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
  KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-$(generate_password)}"
  KEYCLOAK_APISIX_CLIENT_SECRET="${KEYCLOAK_APISIX_CLIENT_SECRET:-$(generate_password 32)}"
  KEYCLOAK_DASHBOARD_CLIENT_SECRET="${KEYCLOAK_DASHBOARD_CLIENT_SECRET:-$(generate_password 32)}"
  APISIX_ADMIN_KEY="${APISIX_ADMIN_KEY:-$(generate_password 32)}"
  DASHBOARD_SHOW_DEV_PAGES="${DASHBOARD_SHOW_DEV_PAGES:-false}"

  # WireGuard local configuration
  WG_INTERFACE_PORT="${WG_INTERFACE_PORT:-19818}"
  WG_TRANSPORT_MODE="${WG_TRANSPORT_MODE:-tcp}"
  WG_PRIVATE_KEY="${WG_PRIVATE_KEY:-}"  # Optional - if empty, irisagent will generate

  echo "Customer: $CUSTOMER_NAME"
  echo "Deployment: $DEPLOYMENT_NAME"
  echo ""
}

# ==============================================================================
# Environment File Generation
# ==============================================================================

generate_env_file() {
  echo "============================================"
  echo "  Generating Environment File"
  echo "============================================"
  echo ""

  cat > "$ENV_FILE" << EOF
# ==============================================================================
# Stargate Environment Configuration
# ==============================================================================
# Generated from customer-config.sh on $(date)
# Customer: $CUSTOMER_NAME
# Deployment: $DEPLOYMENT_NAME
# ==============================================================================

# Deployment Identity
CUSTOMER_NAME="$CUSTOMER_NAME"
DEPLOYMENT_NAME="$DEPLOYMENT_NAME"

# PostgreSQL
POSTGRES_USER="$POSTGRES_USER"
POSTGRES_PASSWORD="$POSTGRES_PASSWORD"

# Vault (auto-populated after initialization)
VAULT_TOKEN=

# MinIO (S3)
MINIO_ROOT_USER="$MINIO_ROOT_USER"
MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD"
S3_BUCKET_NAME="$S3_BUCKET_NAME"

# Application Versions
SMIMEKEYS_VERSION="$SMIMEKEYS_VERSION"
POLICY_VERSION="$POLICY_VERSION"
IRISAGENT_VERSION="$IRISAGENT_VERSION"
MXENGINE_VERSION="$MXENGINE_VERSION"
DASHBOARD_VERSION="$DASHBOARD_VERSION"
MTACONF_VERSION="$MTACONF_VERSION"

# Stalwart MTA
STALWART_ADMIN_PASSWORD="$STALWART_ADMIN_PASSWORD"
MTACONF_SVC_USER="$MTACONF_SVC_USER"
MTACONF_SVC_DOMAIN="$MTACONF_SVC_DOMAIN"
MTACONF_SVC_PASSWORD="$MTACONF_SVC_PASSWORD"
STALWART_HOSTNAME="$STALWART_HOSTNAME"

# Mail Outbound Path
SERVER_STATIC_IP="$SERVER_STATIC_IP"
MXENGINE_PUBLIC_ADDRESS="$MXENGINE_PUBLIC_ADDRESS"
OUTBOUND_SEALER_MX_DOMAIN="$OUTBOUND_SEALER_MX_DOMAIN"
CERT_CA_IRISAGENT_DOMAIN="$CERT_CA_IRISAGENT_DOMAIN"
OUTBOUND_SMTP_HOST="$OUTBOUND_SMTP_HOST"
OUTBOUND_SMTP_PORT="$OUTBOUND_SMTP_PORT"

# Logging (Alloy -> Loki)
LOKI_URL="$LOKI_URL"
ALLOY_HOSTNAME="$DEPLOYMENT_NAME"

# Policy Sync (optional - syncs policies from Git repo)
# To enable: docker compose --profile policy-sync up -d
POLICY_SYNC_VERSION="${POLICY_SYNC_VERSION:-dev}"
POLICY_SYNC_REPO_URL="${POLICY_SYNC_REPO_URL:-https://github.com/Health-Info-Net-AG/Stargate-policies.git}"
POLICY_SYNC_REPO_USER="${POLICY_SYNC_REPO_USER:-}"
POLICY_SYNC_REPO_PASS="${POLICY_SYNC_REPO_PASS:-}"
POLICY_SYNC_REPO_BRANCH="${POLICY_SYNC_REPO_BRANCH:-}"
POLICY_SYNC_REPO_FOLDER="${POLICY_SYNC_REPO_FOLDER:-}"
POLICY_SYNC_INTERVAL="${POLICY_SYNC_INTERVAL:-1h}"

# Keycloak / APISIX / Dashboard
KEYCLOAK_ADMIN_USER="$KEYCLOAK_ADMIN_USER"
KEYCLOAK_ADMIN_PASSWORD="$KEYCLOAK_ADMIN_PASSWORD"
KEYCLOAK_APISIX_CLIENT_SECRET="$KEYCLOAK_APISIX_CLIENT_SECRET"
KEYCLOAK_DASHBOARD_CLIENT_SECRET="$KEYCLOAK_DASHBOARD_CLIENT_SECRET"
APISIX_ADMIN_KEY="$APISIX_ADMIN_KEY"
KEYCLOAK_PUBLIC_URL="$KEYCLOAK_PUBLIC_URL"
DASHBOARD_PUBLIC_URL="$DASHBOARD_PUBLIC_URL"
DASHBOARD_SHOW_DEV_PAGES="$DASHBOARD_SHOW_DEV_PAGES"
DASHBOARD_ROOT_URL="$DASHBOARD_ROOT_URL"
DASHBOARD_ROOT_DOMAIN="$DASHBOARD_ROOT_DOMAIN"

# WireGuard Local Configuration
WG_LOCAL_IP="$WG_LOCAL_IP"
WG_INTERFACE_PORT="$WG_INTERFACE_PORT"
WG_TRANSPORT_MODE="$WG_TRANSPORT_MODE"

# WireGuard Private Key (optional - if set, written to Vault for irisagent)
WG_PRIVATE_KEY="${WG_PRIVATE_KEY:-}"
EOF

  echo "Environment file created: $ENV_FILE"
  echo ""
}

# Generate a self-signed TLS certificate for the Caddy proxy.
# The cert is written to config/caddy/ssl/ and mounted read-only into the
# caddy container.  Skipped on re-runs when the cert already exists.
#
# A subjectAltName matching the server IP (or hostname) is required — modern
# browsers ignore the CN and reject certs that only have a CN with no SAN,
# showing NET::ERR_CERT_COMMON_NAME_INVALID instead of the bypassable
# NET::ERR_CERT_AUTHORITY_INVALID.
generate_tls_cert() {
  echo "============================================"
  echo "  Generating TLS Certificate"
  echo "============================================"
  echo ""

  local ssl_dir="$PROJECT_DIR/config/caddy/ssl"
  mkdir -p "$ssl_dir"

  if [ -f "$ssl_dir/server.crt" ] && [ -f "$ssl_dir/server.key" ]; then
    echo "TLS certificate already exists, skipping generation."
    echo ""
    return
  fi

  # Extract hostname/IP from KEYCLOAK_PUBLIC_URL (strip scheme and port)
  local kc_host
  kc_host=$(echo "$KEYCLOAK_PUBLIC_URL" | sed 's|https\?://||' | cut -d: -f1 | cut -d/ -f1)

  # Use IP: prefix for bare IP addresses, DNS: for hostnames.
  local san
  if [[ "$kc_host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    san="IP:${kc_host},DNS:localhost"
  else
    san="DNS:${kc_host},DNS:localhost"
  fi

  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "$ssl_dir/server.key" \
    -out    "$ssl_dir/server.crt" \
    -subj   "/CN=${kc_host}/O=Stargate" \
    -addext "subjectAltName=${san}" 2>/dev/null

  chmod 600 "$ssl_dir/server.key"
  echo "TLS certificate generated: $ssl_dir/server.crt"
  echo "  CN: $kc_host  |  SAN: $san  |  Valid: 10 years"
  echo ""
}

# Render config/keycloak/realm-stargate.json template into config/keycloak/generated/
# by substituting the two client-secret placeholders with the values from the
# customer config.  Keycloak does not resolve ${env.VAR} syntax at import time,
# so the substitution must happen before the container starts.
generate_keycloak_realm() {
  echo "============================================"
  echo "  Generating Keycloak Realm Config"
  echo "============================================"
  echo ""

  local out_dir="$PROJECT_DIR/config/keycloak/generated"
  mkdir -p "$out_dir"

  sed \
    -e "s|\${KEYCLOAK_APISIX_CLIENT_SECRET}|${KEYCLOAK_APISIX_CLIENT_SECRET}|g" \
    -e "s|\${KEYCLOAK_DASHBOARD_CLIENT_SECRET}|${KEYCLOAK_DASHBOARD_CLIENT_SECRET}|g" \
    -e "s|\${DASHBOARD_PUBLIC_URL}|${DASHBOARD_PUBLIC_URL}|g" \
    "$PROJECT_DIR/config/keycloak/realm-stargate.json" \
    > "$out_dir/realm-stargate.json"

  echo "Keycloak realm config generated: $out_dir/realm-stargate.json"
  echo ""
}

# Function to create and enable a systemd service for start/stop
setup_systemd_service() {
  local service_name="stargate"
  local service_file="/etc/systemd/system/${service_name}.service"

  echo ""
  echo "============================================"
  echo "  Setting up systemd Service"
  echo "============================================"
  echo ""

  cat > "$service_file" << EOF
[Unit]
Description=Stargate Deployment
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${PROJECT_DIR}
ExecStart=${SCRIPT_DIR}/start.sh
ExecStop=${SCRIPT_DIR}/stop.sh
TimeoutStartSec=300
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOF

  chmod 644 "$service_file"
  chcon -t bin_t "$SCRIPT_DIR"/*.sh 2>/dev/null || true
  systemctl daemon-reload
  systemctl enable --now "$service_name"

  echo "systemd service created:  $service_file"
  echo "Service enabled:          $service_name.service"
  echo ""
  echo "  Start:   sudo systemctl start $service_name"
  echo "  Stop:    sudo systemctl stop $service_name"
  echo "  Status:  sudo systemctl status $service_name"
  echo ""
}

# Function to setup backup cron job
setup_backup_cron() {
  echo ""
  echo "Setting up daily backup cron job..."

  BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"
  CRON_JOB="0 2 * * * $BACKUP_SCRIPT >> $PROJECT_DIR/backups/cron.log 2>&1"

  # Check if cron job already exists
  if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT"; then
    echo "Backup cron job already exists."
  else
    # Add cron job
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Daily backup scheduled at 2:00 AM"
  fi

  # Create backups directory
  mkdir -p "$PROJECT_DIR/backups"
}

# Function to save Vault token to customer-config.sh for persistence
save_vault_token_to_config() {
  local token="$1"

  echo ""
  echo "============================================"
  echo "  Saving Vault Token to Config"
  echo "============================================"
  echo ""

  # Check if VAULT_TOKEN is empty or missing in customer-config.sh
  if grep -q '^VAULT_TOKEN=""' "$CONFIG_FILE" || grep -q '^VAULT_TOKEN=$' "$CONFIG_FILE" || ! grep -q '^VAULT_TOKEN=' "$CONFIG_FILE"; then
    # Update or add the token
    if grep -q '^VAULT_TOKEN=' "$CONFIG_FILE"; then
      sed -i "s|^VAULT_TOKEN=.*|VAULT_TOKEN=\"$token\"|" "$CONFIG_FILE"
    else
      # Add to file if not present
      echo "" >> "$CONFIG_FILE"
      echo "VAULT_TOKEN=\"$token\"" >> "$CONFIG_FILE"
    fi
    echo "Vault token saved to customer-config.sh"
    echo ""
    echo "  Token: ${token:0:15}...${token: -10}"
    echo ""
    echo "  IMPORTANT: Back up customer-config.sh before recreating the VM!"
    echo "  The same token will be used on restore."
  else
    echo "Vault token already configured in customer-config.sh"
  fi
}

# Function to extract WireGuard key from Vault and save to customer-config.sh
save_wireguard_key_to_config() {
  echo ""
  echo "============================================"
  echo "  Saving WireGuard Key to Config"
  echo "============================================"
  echo ""

  # Wait for irisagent to generate the key (it needs a moment after start)
  echo "Waiting for IRISAgent to initialize WireGuard key..."
  sleep 5

  # Extract the WireGuard private key from Vault
  WG_KEY=$(docker exec -e VAULT_TOKEN="$ROOT_TOKEN" stargate-vault \
    vault kv get -address=http://127.0.0.1:8200 -field=wg_private_key secret-irisagent/wg_private_key 2>/dev/null || echo "")

  if [ -z "$WG_KEY" ]; then
    echo "WARNING: Could not extract WireGuard key from Vault."
    echo "IRISAgent may not have started yet. You can extract it later with:"
    echo "  docker exec stargate-vault vault kv get -address=http://127.0.0.1:8200 secret-irisagent/wg_private_key"
    return 1
  fi

  # Get the public key from irisagent logs
  WG_PUBKEY=$(docker logs stargate-irisagent 2>&1 | grep "wireguard public key:" | head -1 | sed 's/.*wireguard public key: //' | tr -d '[:space:]')

  # Check if WG_PRIVATE_KEY is already set in customer-config.sh
  if grep -q '^WG_PRIVATE_KEY=""' "$CONFIG_FILE" || grep -q "^WG_PRIVATE_KEY=\$" "$CONFIG_FILE" || ! grep -q '^WG_PRIVATE_KEY=' "$CONFIG_FILE"; then
    # Update or add the key
    if grep -q '^WG_PRIVATE_KEY=' "$CONFIG_FILE"; then
      sed -i "s|^WG_PRIVATE_KEY=.*|WG_PRIVATE_KEY=\"$WG_KEY\"|" "$CONFIG_FILE"
    else
      # Add after WireGuard Configuration section header
      sed -i "/^# Local WireGuard IP address/i WG_PRIVATE_KEY=\"$WG_KEY\"\n" "$CONFIG_FILE"
    fi
    echo "WireGuard private key saved to customer-config.sh"
    echo ""
    echo "  Private Key: ${WG_KEY:0:10}...${WG_KEY: -10}"
    echo "  Public Key:  $WG_PUBKEY"
    echo ""
    echo "  IMPORTANT: Back up customer-config.sh before recreating the VM!"
    echo "  The same key will be used on next install."
  else
    echo "WireGuard key already configured in customer-config.sh"
  fi
}

# Function to setup Dozzle log viewer
setup_dozzle() {
  if [ "$DOZZLE_ENABLED" != "true" ]; then
    return 0
  fi

  echo ""
  echo "============================================"
  echo "  Setting up Dozzle Log Viewer"
  echo "============================================"
  echo ""

  # Generate password if not set
  DOZZLE_USERNAME="${DOZZLE_USERNAME:-admin}"
  if [ -z "$DOZZLE_PASSWORD" ]; then
    DOZZLE_PASSWORD=$(generate_password 16)
    # Save generated password to customer-config.sh
    if grep -q '^DOZZLE_PASSWORD=' "$CONFIG_FILE"; then
      sed -i "s|^DOZZLE_PASSWORD=.*|DOZZLE_PASSWORD=\"$DOZZLE_PASSWORD\"|" "$CONFIG_FILE"
    else
      echo "DOZZLE_PASSWORD=\"$DOZZLE_PASSWORD\"" >> "$CONFIG_FILE"
    fi
  fi

  # Generate bcrypt hash for the password using Dozzle's built-in generator
  echo "Generating Dozzle authentication..."
  DOZZLE_DATA_DIR="$PROJECT_DIR/dozzle"
  mkdir -p "$DOZZLE_DATA_DIR"

  DOZZLE_GEN_ERROR=""
  DOZZLE_GEN_OK=false
  DOZZLE_IMAGE="amir20/dozzle:${DOZZLE_VERSION:-v10.5.0}"
  if docker run --rm "$DOZZLE_IMAGE" generate \
    "$DOZZLE_USERNAME" \
    --password "$DOZZLE_PASSWORD" \
    --name "Stargate Admin" \
    --user-filter "name=stargate" \
    > "$DOZZLE_DATA_DIR/users.yml" 2>"$DOZZLE_DATA_DIR/.gen-error.tmp"; then
    DOZZLE_GEN_OK=true
  else
    DOZZLE_GEN_ERROR=$(cat "$DOZZLE_DATA_DIR/.gen-error.tmp" 2>/dev/null || true)
    DOZZLE_GEN_ERROR="${DOZZLE_GEN_ERROR:-unknown error}"
  fi
  rm -f "$DOZZLE_DATA_DIR/.gen-error.tmp"

  if [ "$DOZZLE_GEN_OK" = true ] && [ -f "$DOZZLE_DATA_DIR/users.yml" ]; then
    echo "Dozzle authentication configured successfully"
    echo ""
    echo "  Username: $DOZZLE_USERNAME"
    echo "  Password: $DOZZLE_PASSWORD"
    echo ""
    echo "  IMPORTANT: Save these credentials - they are also stored in customer-config.sh"
    echo "  Dozzle will be available at: http://localhost:8090"
  else
    echo "WARNING: Failed to generate Dozzle users.yml"
    echo "  Error: $DOZZLE_GEN_ERROR"
    echo "  Dozzle will still work but without authentication."
  fi

  # Start Dozzle
  echo "Starting Dozzle..."
  docker compose --profile dozzle up -d
  echo "Dozzle started."
}

# ============================================
# Main Installation
# ============================================

# Allow other scripts to source this file for its functions without
# executing the installer. Usage: STARGATE_SOURCE_ONLY=1 source install.sh
if [ "${STARGATE_SOURCE_ONLY:-}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

# Check dependencies first
check_dependencies


# Load and validate customer configuration
load_customer_config

# Create directories
mkdir -p "$SECRETS_DIR"
mkdir -p "$PROJECT_DIR/backups"

# Generate .env file from customer config
generate_env_file

# Generate self-signed TLS cert for the Caddy proxy
generate_tls_cert

# Generate Keycloak realm JSON with actual client secrets substituted in
generate_keycloak_realm

# Start infrastructure services first (Vault needs to initialize before
# application services can use the token).
echo ""
echo "Starting infrastructure services..."
docker compose up -d postgres vault vault-data-fixer minio minio-init

echo ""
echo "Waiting for Vault initialization..."
docker compose up -d vault-init

# Wait for vault-init to complete.
# `docker wait` blocks until the named container exits and prints its exit
# code on stdout. The previous implementation polled
# `docker compose ps vault-init | grep -q "running"`, but `docker compose ps`
# without `-a` hides exited containers and uses "Up ..." (not "running") for
# active ones, so the loop matched nothing and exited immediately — the
# script then raced past the freshly-written vault-keys.json and failed.
echo "Waiting for vault-init container to finish..."
docker compose logs -f vault-init 2>/dev/null &
LOG_PID=$!

VAULT_INIT_EXIT=$(docker wait stargate-vault-init 2>/dev/null) || VAULT_INIT_EXIT=1

kill $LOG_PID 2>/dev/null || true
wait $LOG_PID 2>/dev/null || true

if [ "$VAULT_INIT_EXIT" != "0" ]; then
  echo ""
  echo "ERROR: vault-init exited with code $VAULT_INIT_EXIT"
  echo "Check logs: docker compose logs vault-init"
  exit 1
fi

# Check if keys were generated
if [ -f "$KEYS_FILE" ]; then
  ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE")
  update_env_token "$ROOT_TOKEN"

  echo ""
  echo "============================================"
  echo "  Vault initialized successfully!"
  echo "============================================"
  echo ""
  echo "Root Token: $ROOT_TOKEN"
  echo ""
  echo "Keys saved to: $KEYS_FILE"
  echo "IMPORTANT: Back up this file securely!"
  echo ""

  # Save Vault token to customer-config.sh for persistence across VM recreations
  save_vault_token_to_config "$ROOT_TOKEN"

  # Now start all services - VAULT_TOKEN is set in .env so application
  # services will have the correct token from the start.
  echo "Starting all services..."
  docker compose up -d
  echo "All services started."

  # Wait for services to be ready
  sleep 5

  # Onboarding (domains, S/MIME CSR, irisagent peer config) is now performed
  # via the dashboard at /installation, /onboarding, and /mail.

  # Setup backup cron job
  setup_backup_cron

  # Create and enable systemd service for auto-start on boot
  setup_systemd_service

  # Save WireGuard key to customer-config.sh for persistence
  save_wireguard_key_to_config

  # Setup Dozzle if enabled
  setup_dozzle

else
  echo "ERROR: Vault keys file not found."
  echo "Check vault-init logs: docker compose logs vault-init"
  exit 1
fi

echo ""
echo "============================================"
echo "  Checking service status..."
echo "============================================"
echo ""

sleep 3
docker compose ps

echo ""
echo "============================================"
echo "  Installation Complete!"
echo "============================================"
echo ""
echo "  Customer: $CUSTOMER_NAME"
echo "  Deployment: $DEPLOYMENT_NAME"
echo ""
echo "  Dashboard:"
echo "  ----------"
echo "  URL:               $DASHBOARD_PUBLIC_URL"
echo ""
echo "  Keycloak Admin Console:"
echo "  -----------------------"
echo "  URL:               $KEYCLOAK_PUBLIC_URL/admin"
echo "  Username:          $KEYCLOAK_ADMIN_USER"
echo "  Password:          $KEYCLOAK_ADMIN_PASSWORD"
echo "  (You will be prompted to change the password on first login)"
echo ""
echo "  Service URLs:"
echo "  -------------"
echo "  smimekeys-client:  http://localhost:8081"
echo "  policy:            http://localhost:8082"
echo "  irisagent:         http://localhost:8083"
echo "  mxengine:          http://localhost:8084"
echo "  mxengine SMTP:     localhost:1587"
echo ""
echo "  Vault UI:          http://localhost:8200"
echo "  MinIO Console:     http://localhost:9001"
echo "  PostgreSQL:        localhost:5432"
echo "  Stalwart SMTP:     localhost:25"
echo ""
echo "  Monitoring:"
echo "  -----------"
echo "  Node Exporter:     http://localhost:9100/metrics"
echo "  Alloy:             Logs -> $LOKI_URL"
if [ "${DOZZLE_ENABLED:-false}" = "true" ]; then
  echo "  Dozzle (logs):     http://localhost:8090"
fi
echo ""
echo "  Scripts:"
echo "  --------"
echo "  You can use systemctl or the scripts directly:"
echo "  systemctl {start|stop|status|restart} stargate"
echo "  ./scripts/start.sh  |  ./scripts/stop.sh"
echo "  Backup databases:  ./scripts/backup.sh"
echo "  Destroy all data:  ./scripts/purge.sh"
echo ""
echo "  Backups:"
echo "  --------"
echo "  Daily backups scheduled at 2:00 AM"
echo "  Backup location: $PROJECT_DIR/backups/"
echo ""
echo "  Configuration:"
echo "  --------------"
echo "  Customer config:   $CONFIG_FILE"
echo "  Environment file:  $ENV_FILE"
echo "  Vault keys:        $KEYS_FILE"
echo "  CSR file:          $SECRETS_DIR/signing-key.csr"
echo ""
echo "  IMPORTANT: Back up customer-config.sh before recreating the VM!"
echo "  It now contains your WireGuard private key for persistence."
echo ""
echo "  Browser TLS trust:"
echo "  ------------------"
echo "  Caddy uses a self-signed certificate for HTTPS."
echo "  Browsers will show a warning that can be bypassed via Advanced ->"
echo "  Accept the Risk (Firefox) or Proceed anyway (Chrome)."
echo "  To silence the warning permanently, import the certificate:"
echo ""
echo "    $PROJECT_DIR/config/caddy/ssl/server.crt"
echo ""
echo "  Import it into your OS/browser trust store (Keychain on macOS,"
echo "  Certificate Manager on Windows, update-ca-certificates on Debian/Ubuntu,"
echo "  update-ca-trust on RHEL/AlmaLinux). Firefox requires a separate import"
echo "  under Settings -> Privacy -> Certificates."
echo ""

# ============================================
# HIN WireGuard Peer Registration block
# ============================================
# Print the values HIN needs to register this Stargate as a WireGuard peer.
# Without this registration the WG tunnel cannot be established and S/MIME
# certificate issuance will keep failing.

WG_PUBKEY_FOR_HIN="$(docker compose logs irisagent 2>/dev/null \
  | grep -m1 'wireguard public key:' \
  | sed 's/.*wireguard public key: //' \
  | tr -d '[:space:]')"

echo "============================================"
echo "  HIN WireGuard Peer Registration"
echo "============================================"
echo ""
echo "  Send the following values to HIN ([Contact us per mail](mailto:david.grabovac@hin.ch?subject=Stargate%20Support%20Question&body=Hello%20dear%20Mr%20Grabovac,%0A%0AI%20have%20a%20Question%20regarding%20Stargate%20and%20would%20like%20to%20ask%20you%20for%20support.%20DO%20NOT%20FORGET%20TO%20ADD%20YOUR%20QUESTION){ .md-button style=\"position:relative;left:50%;transform:translate(-50%,0%);\" }"
echo "  so they can register this Stargate as a WireGuard peer."
echo "  Until the peer is registered, S/MIME cert issuance will fail."
echo ""
echo "  WireGuard Public Key: ${WG_PUBKEY_FOR_HIN:-<not yet available - run: docker compose logs irisagent | grep \"wireguard public key\">}"
echo "  DEPLOYMENT_NAME:      $DEPLOYMENT_NAME"
echo "  SERVER_STATIC_IP:     $SERVER_STATIC_IP"
echo "  WG_INTERFACE_PORT:    $WG_INTERFACE_PORT"
echo ""
echo "  After HIN confirms registration, regenerate the certificate from the dashboard."
echo ""
echo "  Recommended next steps:"
echo "    - SPF / DKIM / DMARC for your sending domains"
echo "      (see README.md → 'Post-Onboarding Recommendations')"
echo "    - Microsoft 365 / Exchange Online relay-back connectors"
echo "      (see Exchange-integration.md)"
echo ""
