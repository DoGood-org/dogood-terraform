set -e

# Provisioning is rendered by Terraform and passed in as env vars, so the stock
# image is used as-is. The data dir is ephemeral: dashboards created in the UI
# are lost when the task restarts.
mkdir -p "$GF_PATHS_PROVISIONING"/datasources "$GF_PATHS_PROVISIONING"/dashboards \
  "$GF_PATHS_PROVISIONING"/alerting "$GF_PATHS_PROVISIONING"/plugins
printf '%s\n' "$DATASOURCES_YAML" > "$GF_PATHS_PROVISIONING/datasources/datasources.yaml"

exec /run.sh
