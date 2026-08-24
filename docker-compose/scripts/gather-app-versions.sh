#!/bin/sh
# Gather app versions from /liveness endpoints and write to node-exporter textfile
# This script is run by the version-collector container

set -e

OUTPUT_DIR="/textfile_collector"
TEMP_FILE=$(mktemp)

# Write header first (Prometheus format requires HELP/TYPE before metrics)
echo "# HELP app_build_info Application build information with version label" >> "$TEMP_FILE"
echo "# TYPE app_build_info gauge" >> "$TEMP_FILE"

# Function to get version from /liveness endpoint
get_version() {
    local name=$1
    local host=$2
    local port=$3
    
    # Try to get liveness response
    local response=$(wget -q -O - --timeout=5 "http://${host}:${port}/liveness" 2>/dev/null || echo "{}")
    
    # Extract version using sed (alpine-friendly, no jq dependency)
    # Handle both "version" and "Version" (irisagent uses capital V)
    local version=$(echo "$response" | sed -n 's/.*"[vV]ersion"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    
    if [ -n "$version" ]; then
        echo "app_build_info{app=\"${name}\",version=\"${version}\"} 1" >> "$TEMP_FILE"
    fi
}

# Gather from each service (using internal Docker hostnames and ports)
get_version "smimekeys-client" "smimekeys-client" "8080"
get_version "policy" "policy" "8080"
get_version "irisagent" "irisagent" "8080"
get_version "mxengine" "mxengine" "8080"
get_version "idagent" "idagent" "8080"
get_version "mailauth" "mailauth" "8080"

# Set permissions so node-exporter can read (it runs as non-root)
chmod 644 "$TEMP_FILE"

# Atomically move to output (ensures node-exporter doesn't read partial file)
mv "$TEMP_FILE" "${OUTPUT_DIR}/app_versions.prom"

echo "$(date): Updated app versions"
