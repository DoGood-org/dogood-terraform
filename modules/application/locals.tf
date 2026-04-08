locals {
  app_secrets_with_db_url = merge(var.app_secrets, {
    DATABASE_URL = format(
      "postgresql://%s:%s@%s:%d/%s",
      urlencode(var.app_secrets["POSTGRES_USER"]),
      urlencode(var.app_secrets["POSTGRES_PASSWORD"]),
      var.db_proxy_endpoint,
      5432,
      urlencode(var.app_secrets["POSTGRES_DB"])
    )
  })
}