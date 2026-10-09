# dogood-terraform

IaaC for deploying the DoGood AWS infrastructure (ECS Fargate + RDS PostgreSQL) with a module-based layout.

## Structure

- `main.tf` wires the modules together and keeps the root module thin.
- `modules/networking` owns the VPC, public/private subnets, security groups, the DB subnet group and VPC endpoints (S3 gateway; ECR, CloudWatch Logs, Secrets Manager interface endpoints).
- `modules/database` owns the PostgreSQL RDS instance. The master password is managed by RDS in Secrets Manager.
- `modules/application` owns the ECS cluster and Fargate service, the ALB and the Secrets Manager secret with app environment variables.
- `modules/cloudflare` owns the DNS record pointing the stage subdomain at the ALB. **Currently disabled** (commented out in `main.tf`, `providers.tf`, `variables.tf`, `outputs.tf`).

## Network model

Private subnets have **no NAT gateway**. ECS tasks reach AWS services only through VPC endpoints, and RDS directly inside the VPC. Calls to external services (OpenAI, Stripe, SMTP, …) are delegated to Lambda functions.

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

- S3 bucket `dogood-infrastructure-terraform-state-69420` (`us-west-1`) for remote state.
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
| Database (RDS) | `db_instance_class`, `db_port`, `db_multi_az`, `db_read_replica_count`, `db_deletion_protection` |
| Compute (ECS Fargate) | `ecs_single_az`, `ecs_task_cpu`, `ecs_task_memory`, `ecs_min_capacity`, `ecs_max_capacity`, `app_port`, `app_health_check_path` |

Single-AZ mode (`db_multi_az = false`, `ecs_single_az = true`, `vpc_endpoints_single_az = true`) puts RDS, ECS tasks and interface endpoints in the first AZ. Subnets still span two AZs because the DB subnet group and the ALB require it.
