#!/bin/bash
# =============================================================================
# Shared library: Linux distro detection + Docker installation.
#
# Sourced by install.sh and restore.sh -- NOT meant to be executed directly.
# Call detect_distro early to populate DIST_ID and PKGMGR; install_docker()
# relies on both.
# =============================================================================

# Determine the Linux distribution and package manager, setting:
#   DIST_ID  the os-release ID (e.g. debian, ubuntu, almalinux, rhel)
#   PKGMGR   "apt" on the Debian family, otherwise "dnf"
detect_distro() {
  if [ -f /etc/os-release ]; then
    DIST_ID=$(grep ^ID= /etc/os-release | cut -f2 -d= | sed 's/"//g')
  else
    echo "File /etc/os-release not found, cannot determine Linux distribution."
    exit 1
  fi

  if [[ $DIST_ID == debian || $DIST_ID == ubuntu || $DIST_ID == linuxmint || $DIST_ID == kali ]]; then
    PKGMGR=apt
  else
    PKGMGR=dnf
  fi
}

# Install Docker CE (+ compose plugin and jq) from Docker's official repository
# and enable the docker service. Requires detect_distro to have run first.
install_docker() {
  echo "Installing Docker from official repository..."
  if [[ $PKGMGR == apt ]]; then
    sudo $PKGMGR update -y && sudo $PKGMGR upgrade -y
    sudo $PKGMGR remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc 2>/dev/null || true
    sudo $PKGMGR install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/$DIST_ID/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$DIST_ID \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo $PKGMGR update -y
  else
    sudo $PKGMGR update -y
    sudo $PKGMGR remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman runc 2>/dev/null || true
    sudo rpm --import https://download.docker.com/linux/rhel/gpg
    sudo $PKGMGR -y install dnf-plugins-core
    sudo $PKGMGR config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
  fi
  sudo $PKGMGR install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin jq
  echo "Docker installed successfully!"
  sudo systemctl enable --now docker
  docker --version
  docker compose version
}

# Ensure docker, the compose plugin, and jq are present; install Docker if not.
check_dependencies() {
  local missing=()

  if ! command -v docker &> /dev/null; then
    missing+=("docker")
  fi

  if ! docker compose version &> /dev/null; then
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
