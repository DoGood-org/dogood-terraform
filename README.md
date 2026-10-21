# dogood-terraform

IaaC for deploying the DoGood AWS infrastructure (ECS Fargate + RDS PostgreSQL) with a module-based layout.

## Structure

- `main.tf` wires the modules together and keeps the root module thin.
- `modules/networking` owns the VPC, public/private subnets, security groups, the DB subnet group and VPC endpoints (S3 gateway; ECR, CloudWatch Logs, Secrets Manager interface endpoints).
- `modules/database` owns the PostgreSQL RDS instance. The master password is managed by RDS in Secrets Manager.
- `modules/application` owns the ECS cluster and Fargate service, the ALB and the Secrets Manager secret with app environment variables.
- `modules/monitoring` owns the Grafana ECS service (CloudWatch data source), its security group, IAM roles and admin secret. Enabled per stage with `monitoring_enabled`.
- `modules/cloudflare` owns the DNS record pointing the stage subdomain at the ALB. **Not wired in yet**: enabling it needs the `cloudflare` provider (`~> 4.0`), `cloudflare_api_token` / `cloudflare_zone_id` variables and a `module "cloudflare"` block in `main.tf` (`zone_id`, `subdomain = var.stage`, `target = module.application.load_balancer_dns_name`).

## Network model

Private subnets have **no NAT gateway**. ECS tasks reach AWS services only through VPC endpoints, and RDS directly inside the VPC. Calls to external services (OpenAI, Stripe, SMTP, …) are delegated to Lambda functions.

The task security group allows egress only to the interface endpoints (443), the S3 gateway prefix list (443, ECR image layers) and RDS (`db_port`). A new dependency (Redis, a Lambda endpoint, …) needs its own egress rule in `modules/networking/security_groups.tf`.

## Database connection

The application module receives the RDS endpoint and master secret ARN from the database module outputs and injects into the container:

- `POSTGRES_HOST`, `POSTGRES_PORT`: the instance's private endpoint (plain env vars);
- `POSTGRES_USER`, `POSTGRES_PASSWORD`: from the RDS-managed master secret;
- `PORT`: from `app_port`.

The backend is the NestJS app (`dogood-backend` branch `refactor/architecture`). The task definition overrides the image `ENTRYPOINT ["node"]` with `sh -c` and runs `modules/application/templates/start.sh`: it assembles `DATABASE_URL` (URL-encoded password, `sslmode=require`) from these variables, runs `prisma migrate deploy`, then `exec node dist/main.js`.

Any `PORT`, `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD` or `DATABASE_URL` keys in `app_secrets` are **not** passed to the container. `POSTGRES_DB` and `POSTGRES_USER` from `app_secrets` are still used to create the database.

The task definition, ECS service and execution role policy reference RDS attributes that only exist once the instance is created and available, so ECS starts after RDS. The ALB and the ECS cluster are created in parallel with RDS.

Each stage gets its own least-privilege task execution role (`<stage>-ecs-execution-role`), log group (`/aws/ecs/<stage>/dogood-backend`) and task definition family (`<stage>-dogood-backend`).

## Prerequisites (managed outside this repo)

- S3 bucket `dogood-infrastructure-terraform-state-69420` (`us-west-1`) for remote state. Its bucket policy is managed by the separate root module `bootstrap/` (own state key `bootstrap/terraform.tfstate`): object reads are denied to everyone except the AdministratorAccess holders listed there, and non-TLS requests are denied. Add a principal there before it needs to read state (e.g. a CI role running Terraform). Apply with `cd bootstrap && terraform init && terraform apply`.
- ECR repository per stage (`ecr_repository_name`, e.g. `dogood-backend-mvp`) with an image tagged `latest`. It is used only for the initial task definition; later revisions are deployed by GitHub Actions. Repositories live outside this stack so they survive the daily destroy of dev/staging.
- GitHub Actions OIDC role that deploys new task definition revisions (Terraform ignores task definition changes after the first apply).
- Cloudflare zone and API token (once the Cloudflare module is re-enabled).

## Workflow

Each stage is a Terraform workspace with its own `<stage>.tfvars`. The S3 backend keeps a separate state per workspace (`env:/<workspace>/dogood-terraform/terraform.tfstate`). Plans fail if `stage` in tfvars doesn't match the selected workspace.

```bash
terraform init
terraform workspace select -or-create dev
terraform validate
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

`*.tfvars` files are git-ignored because they contain secrets.

## Stage-specific settings

Each `<stage>.tfvars` has an **Infrastructure** section grouped by category and a separate **Application** section (`app_secrets`, stored in Secrets Manager and injected into the container).

| Category | Variables |
|---|---|
| General | `stage`, `aws_region`, `aws_profile` |
| Networking | `vpc_cidr_block`, `vpc_endpoints_single_az` |
| Database (RDS) | `db_instance_class`, `db_port`, `db_multi_az`, `db_read_replica_count`, `db_deletion_protection`, `db_skip_final_snapshot` (false keeps a `<stage>-db-instance-final` snapshot on delete) |
| Compute (ECS Fargate) | `ecs_single_az`, `ecs_task_cpu`, `ecs_task_memory`, `ecs_min_capacity`, `ecs_max_capacity`, `app_port`, `app_health_check_path`, `ecr_repository_name`, `app_secret_recovery_window_days` (0 for stages destroyed daily, otherwise the secret name stays reserved) |
| Monitoring | `monitoring_enabled`, `grafana_efs_enabled` |

Single-AZ mode (`db_multi_az = false`, `ecs_single_az = true`, `vpc_endpoints_single_az = true`) puts RDS, ECS tasks and interface endpoints in the first AZ. Subnets still span two AZs because the DB subnet group and the ALB require it.

## Monitoring (Grafana)

With `monitoring_enabled = true` (mvp only), Grafana runs as the `grafana` service in `<stage>-cluster`: Fargate ARM64, the official image pinned by digest, one task in the first public subnet.

- **No inbound access.** The security group has no ingress rules; the public IP is used for egress only (CloudWatch API, SSM, Docker Hub). Grafana is reached through an SSM port-forwarding session (ECS Exec), so access is controlled by IAM (`ssm:StartSession`).
- **Data source:** CloudWatch, provisioned at start-up and authenticated with the task role (read-only metrics; no CloudWatch Logs access). Metric history lives in CloudWatch, not in Grafana.
- **State (`grafana_efs_enabled`):** when `true` (mvp), `/var/lib/grafana` (SQLite: dashboards, users, alert state) is an encrypted EFS file system (elastic throughput, daily AWS Backup) mounted through an access point as uid 472, so UI changes survive task restarts. Deployments stop the old task before starting the new one (`maximum_percent = 100`, `minimum_healthy_percent = 0`) so two instances never write the SQLite file at once; Grafana is briefly unavailable during a deploy. When `false`, Grafana uses SQLite on task storage and UI dashboards are lost on every restart.
- **Admin password:** generated by Terraform as an ephemeral value and written write-only to Secrets Manager `/dogood/<stage>/grafana` (key `admin_password`), so it is never stored in state. Grafana applies it only when it creates its database; with EFS, to rotate it later, bump `secret_string_wo_version` and also run `grafana cli admin reset-admin-password` in the task.

Open the tunnel (requires the AWS CLI and the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)), then browse to http://localhost:3000:

```bash
scripts/grafana-tunnel.sh mvp            # optional second argument: local port
# Windows: .\scripts\grafana-tunnel.ps1 -Stage mvp -LocalPort 3000
aws secretsmanager get-secret-value --secret-id /dogood/mvp/grafana --query SecretString --output text
```

The ECS service has a public IP by design, so Security Hub control ECS.2 will flag it; this is an accepted exception.
