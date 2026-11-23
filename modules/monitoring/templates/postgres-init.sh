# Creates (or updates) the postgres_exporter role with pg_monitor; idempotent.
# Runs as the RDS master user (PGUSER / PGPASSWORD) on every task start.
set -eu

printf '%s\n' \
  "SELECT format('CREATE ROLE %I LOGIN', :'user') WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'user')\gexec" \
  "ALTER ROLE :\"user\" WITH LOGIN PASSWORD :'password';" \
  "GRANT pg_monitor TO :\"user\";" |
  psql -X -q -v ON_ERROR_STOP=1 -v user="$MONITORING_USER" -v password="$MONITORING_PASSWORD"

echo "Role $MONITORING_USER ready"
