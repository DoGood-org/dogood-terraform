locals {
  app_secrets_with_db_url = merge(var.app_secrets, {
    DATABASE_URL = format(
      "postgresql://%s:%s@%s:%d/%s",
      urlencode(var.app_secrets["POSTGRES_USER"]),
      urlencode(var.app_secrets["POSTGRES_PASSWORD"]),
      "localhost",
      6432,
      urlencode(var.app_secrets["POSTGRES_DB"])
    )
  })



  pgbouncer_db_url = format(
    "postgresql://%s:%s@%s:%d/%s",
    var.app_secrets["POSTGRES_USER"],
    var.app_secrets["POSTGRES_PASSWORD"],
    var.db_endpoint,
    var.db_port,
    var.app_secrets["POSTGRES_DB"]
  )
}
