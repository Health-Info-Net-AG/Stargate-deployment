# Environment preset: dev. Applied by install.sh over customer-config-prod.example.sh when the appliance is seeded
# with STARGATE_ENV=dev. Only the keys that differ from prod belong here; everything else stays on the prod template,
# so a preset never becomes a second full configuration to maintain in parallel.
#
# These are public hostnames, not secrets. Nothing credential-shaped belongs in a preset: presets are committed, and
# the seeded customer-config.sh is where generated secrets land at install time.
OUTBOUND_SEALER_MX_DOMAIN="vereign-cdn.com"
CERT_CA_IRISAGENT_DOMAIN="vereign-cdn.com"
DASHBOARD_ROOT_URL="https://apisix.k8s.vereign-cdn.com"
DASHBOARD_ROOT_DOMAIN="vereign-cdn.com"
