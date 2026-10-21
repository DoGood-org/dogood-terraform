set -e

mkdir -p "$GF_PATHS_PROVISIONING"/datasources "$GF_PATHS_PROVISIONING"/dashboards \
  "$GF_PATHS_PROVISIONING"/alerting "$GF_PATHS_PROVISIONING"/plugins
printf '%s\n' "$DATASOURCES_YAML" > "$GF_PATHS_PROVISIONING/datasources/datasources.yaml"

exec /run.sh
