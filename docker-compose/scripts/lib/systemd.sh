#!/bin/bash
# =============================================================================
# Shared library: systemd service management for the Stargate stack.
#
# Sourced by install.sh and restore.sh -- NOT meant to be executed directly.
# The sourcing script must have already set:
#   SCRIPT_DIR   absolute path to the scripts/ directory (holds start.sh/stop.sh)
#   PROJECT_DIR  absolute path to the docker-compose project root
# =============================================================================

# Create and enable the 'stargate' systemd unit so the stack auto-starts on boot
# and can be managed with `systemctl {start,stop,status,restart} stargate`.
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
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${PROJECT_DIR}
ExecStart=${SCRIPT_DIR}/start.sh
ExecStop=${SCRIPT_DIR}/stop.sh
# The first (cold) bring-up is gated by depends_on healthchecks -- notably
# clamav, whose signature-DB load alone has a 300s start_period -- so the
# oneshot can legitimately take many minutes. A reboot bypasses this (Docker's
# restart policy ignores depends_on), but `systemctl start` / a restore goes
# through the gated `docker compose up -d`. Keep the timeout well above the
# slowest dependency so it isn't killed mid-bring-up.
TimeoutStartSec=600
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
