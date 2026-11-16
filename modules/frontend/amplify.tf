# Next.js SSR app connected to GitHub. access_token (GitHub PAT) is used only to create
# the app (webhook + deploy key); later changes to it are ignored.
resource "aws_amplify_app" "this" {
  name                 = var.name
  repository           = var.repository
  access_token         = var.access_token
  platform             = "WEB_COMPUTE"
  iam_service_role_arn = var.service_role_arn
  build_spec           = file("${path.module}/templates/amplify.yml")

  environment_variables = var.environment_variables

  enable_branch_auto_build    = false
  enable_branch_auto_deletion = false
  enable_auto_branch_creation = false

  custom_rule {
    source = "/<*>"
    target = "/index.html"
    status = "404-200"
  }

  cache_config {
    type = "AMPLIFY_MANAGED_NO_COOKIES"
  }

  job_config {
    build_compute_type = "STANDARD_8GB"
  }

  tags = {
    Name    = var.name
    Service = "frontend"
  }

  lifecycle {
    # Can't be recreated without a GitHub token; build history and webhooks are lost
    prevent_destroy = true
    ignore_changes  = [access_token]
  }
}

resource "aws_amplify_branch" "this" {
  for_each = var.branches

  app_id            = aws_amplify_app.this.id
  branch_name       = each.key
  stage             = each.value.stage
  enable_auto_build = each.value.enable_auto_build

  tags = {
    Name    = "${var.name}-${each.key}"
    Service = "frontend"
  }
}

resource "aws_amplify_domain_association" "this" {
  app_id                 = aws_amplify_app.this.id
  domain_name            = var.domain_name
  enable_auto_sub_domain = false

  # DNS records live outside this stack (Cloudflare)
  wait_for_verification = false

  certificate_settings {
    type = "AMPLIFY_MANAGED"
  }

  dynamic "sub_domain" {
    for_each = var.branches

    content {
      branch_name = aws_amplify_branch.this[sub_domain.key].branch_name
      prefix      = sub_domain.value.subdomain
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}
