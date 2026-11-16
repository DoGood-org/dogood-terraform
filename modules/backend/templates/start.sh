set -e

# Temporary until the backend builds DATABASE_URL itself from POSTGRES_*.
export DATABASE_URL="$(node -e '
  const e = process.env, c = encodeURIComponent;
  process.stdout.write(
    "postgresql://" + c(e.POSTGRES_USER) + ":" + c(e.POSTGRES_PASSWORD) +
    "@" + e.POSTGRES_HOST + ":" + e.POSTGRES_PORT + "/" + c(e.POSTGRES_DB) + "?sslmode=require"
  )
')"

npx --no prisma migrate deploy

# The current image compiles to dist/src/ (prisma/seed.ts is included in the build).
# Switch back to dist/main.js once the backend excludes prisma/ from tsconfig.build.json.
exec node dist/src/main.js
