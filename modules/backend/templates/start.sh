set -e

# Temporary until the backend builds DATABASE_URL itself from POSTGRES_*.
export DATABASE_URL="$(node -e '
  const e = process.env, c = encodeURIComponent;
  process.stdout.write(
    "postgresql://" + c(e.POSTGRES_USER) + ":" + c(e.POSTGRES_PASSWORD) +
    "@" + e.POSTGRES_HOST + ":" + e.POSTGRES_PORT + "/" + c(e.POSTGRES_DB) + "?sslmode=require"
  )
')"

./node_modules/.bin/prisma migrate deploy

exec node dist/main.js
