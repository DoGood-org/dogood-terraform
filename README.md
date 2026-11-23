# dogood-terraform

IaaC for deploying the DoGood AWS infrastructure (ECS Fargate + RDS PostgreSQL) with a module-based layout.

## Structure

- `main.tf` wires the modules together and keeps the root module thin.
- `modules/networking` owns the VPC, public/private subnets, security groups (including the monitoring task SG and all scrape rules), the DB subnet group, the S3 gateway endpoint and the fck-nat NAT instances.
- `modules/database` owns the PostgreSQL RDS instance. The master password is managed by RDS in Secrets Manager.
- `modules/backend` owns the ECS cluster and Fargate service (plus the `ecs-exporter` sidecar with monitoring on), the ALB with its ACM certificate and listeners, and the Secrets Manager secret with app environment variables.
- `modules/monitoring` owns the monitoring stack: its own ECS cluster with one EC2 container instance, one task with Prometheus, Grafana, postgres_exporter and blackbox_exporter, IAM roles, secrets and the Grafana ALB rules. Enabled per stage with `monitoring_enabled`.
- `modules/frontend` owns the Amplify app `dogood-frontend` (Next.js SSR, `WEB_COMPUTE`), its branches and the `dogood.ink` domain association. It is used only by the separate root module `frontend/` (own state `frontend/terraform.tfstate`), never by the stage workspaces, so destroying a stage can't delete it; the app and domain also have `prevent_destroy`.
- `modules/cloudflare` owns the DNS record pointing the stage subdomain at the ALB. **Not wired in yet**: enabling it needs the `cloudflare` provider (`~> 4.0`), `cloudflare_api_token` / `cloudflare_zone_id` variables and a `module "cloudflare"` block in `main.tf` (`zone_id`, `subdomain = var.stage`, `target = module.backend.load_balancer_dns_name`).

## Network model

Private subnets reach the internet through **NAT instances** ([fck-nat](https://fck-nat.dev), module `RaJiska/fck-nat/aws`, `nat_instance_type`, default `t4g.nano`):

- `nat_per_az = true` (default, prod): one instance per AZ (`<stage>-nat` in the first public subnet, `<stage>-nat-2` in the second); each private route table points at the instance in its own AZ, so losing an AZ doesn't cut egress for the other one.
- `nat_per_az = false` (dev, staging, mvp): one instance in the first public subnet for both private route tables.

`ha_mode` keeps a static ENI per instance that the route tables point at (`0.0.0.0/0`), so each one-instance ASG replaces a failed instance in ~1–2 min without route changes; egress of that AZ is down meanwhile. The public IP sits on the instance's ephemeral ENI and changes when the instance is replaced, so there is no stable egress IP (attach EIPs via `eip_allocation_ids` if a third party needs an allowlist). The S3 gateway endpoint stays (free), so ECR image layers don't go through NAT. There are no interface endpoints: ECR, CloudWatch Logs and Secrets Manager are reached through NAT too.

With `monitoring_enabled`, cloud-init also installs **node_exporter** (`:9100`, release tarball with a pinned SHA-256, systemd unit) on each NAT instance. User data only runs at boot and the module doesn't roll out launch template changes (`auto_rollout = false`), so on a running stage start an instance refresh after enabling it: `aws autoscaling start-instance-refresh --auto-scaling-group-name <stage>-nat` (egress of that AZ is down ~1–2 min).

Switching `nat_per_az` on a running stage moves the second route table to a new instance; if apply fails with `RouteAlreadyExists`, apply again.

The task security group allows egress to the internet only on `app_egress_ports` (default `[443]`; add 587/465 for SMTP) and to RDS (`db_port`). The NAT instance SG accepts all traffic from the VPC CIDR, so the task SG is the effective port allowlist. The module picks the latest fck-nat AMI, so a new AMI release shows up as a launch template change in `plan`; the running instance keeps its AMI until it is replaced.

## Ingress, TLS and DNS

DNS is in Cloudflare and stays managed by hand (the Cloudflare module isn't wired in). Terraform only prints what to create.

With `api_hostname` set (needs `alb_public_enabled`), the public ALB gets:

- an ACM certificate for `api_hostname` (+ `monitoring_hostname` as a SAN), DNS-validated;
- `:443` HTTPS with `ELBSecurityPolicy-TLS13-1-2-2021-06`; `host = api_hostname` -> backend, any other host -> 404;
- `:80` -> 301 to HTTPS.

Without `api_hostname` (and on the internal ALB) both listeners stay plain HTTP and forward everything to the backend.

**First apply with a new hostname.** `aws_acm_certificate_validation` waits (up to 75 min) until the certificate is issued, so create the certificate first, add the validation records, then apply the rest:

```bash
terraform apply -var-file=prod.tfvars -target=module.backend.aws_acm_certificate.this
terraform output acm_validation_records    # add in Cloudflare as CNAME, DNS only
terraform apply -var-file=prod.tfvars
terraform output dns_records                # api.* / monitoring.* CNAMEs to the ALB
```

ACM reuses the same validation CNAME for a hostname in this account, so after the records exist, a destroyed and recreated stage validates without DNS changes.

Cloudflare settings for the ALB records:

- `api.*`: proxied or DNS only. When proxied, SSL/TLS mode must be **Full (strict)** (the ALB has a valid ACM certificate for the name).
- `monitoring.*`: **DNS only**. The ALB rule matches the client IP; through the Cloudflare proxy the ALB would see Cloudflare IPs and answer 403 to everyone.

## Database connection

The backend module receives the RDS endpoint and master secret ARN from the database module outputs and injects into the container:

- `POSTGRES_HOST`, `POSTGRES_PORT`: the instance's private endpoint, or the RDS Proxy endpoint with `db_proxy_enabled = true` (plain env vars);
- `POSTGRES_USER`, `POSTGRES_PASSWORD`: from the RDS-managed master secret;
- `PORT`: from `app_port`.

The backend is the NestJS app (`dogood-backend` branch `refactor/architecture`). The task definition overrides the image `ENTRYPOINT ["node"]` with `sh -c` and runs `modules/backend/templates/start.sh`: it assembles `DATABASE_URL` (URL-encoded password, `sslmode=require`) from these variables, runs `prisma migrate deploy`, then `exec node dist/main.js`.

Any `PORT`, `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD` or `DATABASE_URL` keys in `app_secrets` are **not** passed to the container. `POSTGRES_DB` and `POSTGRES_USER` from `app_secrets` are still used to create the database.

With `db_proxy_enabled = true` an RDS Proxy (`<stage>-db-proxy`, TLS required, SCRAM-SHA-256) sits in both private subnets and authenticates with the RDS-managed master secret. Its security group accepts `db_port` from the task SG and reaches RDS and the Secrets Manager endpoint. Tasks keep direct RDS access so ones started before the switch still work. Because Terraform ignores task definition changes, running tasks keep the old `POSTGRES_HOST` until the next deployment (`aws ecs update-service ... --force-new-deployment`).
clear
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
| Networking | `vpc_cidr_block`, `nat_instance_type`, `nat_per_az` (one NAT instance per AZ; default `true`), `app_egress_ports` |
| Database (RDS) | `db_instance_class`, `db_port`, `db_multi_az`, `db_read_replica_count`, `db_deletion_protection`, `db_skip_final_snapshot` (false keeps a `<stage>-db-instance-final` snapshot on delete), `db_apply_immediately` (true applies version/class changes now, with downtime; false waits for the maintenance window), `db_proxy_enabled` (RDS Proxy `<stage>-db-proxy`; `POSTGRES_HOST` becomes the proxy endpoint) |
| Compute (ECS Fargate) | `ecs_single_az`, `ecs_task_cpu`, `ecs_task_memory`, `ecs_min_capacity`, `ecs_max_capacity`, `ecs_autoscaling_target_cpu_utilization` (target average CPU %, default 75), `app_port`, `app_health_check_path`, `alb_public_enabled` / `alb_internal_enabled` (internet-facing ALB `<stage>-app-lb` in the public subnets and/or internal ALB `<stage>-int-lb` in the private subnets; each has its own target group and the service registers tasks in both; at least one must be on), `ecr_repository_name`, `app_secret_recovery_window_days` (0 for stages destroyed daily, otherwise the secret name stays reserved) |
| Public hostnames | `api_hostname` (HTTPS + host routing on the public ALB), `monitoring_hostname` (Grafana on the ALB), `monitoring_allowed_cidrs` (max 4) |
| Monitoring | `monitoring_enabled`, `monitoring_instance_type` (default `t4g.small`), `monitoring_volume_size` (GiB, default 30), `prometheus_retention_time` / `prometheus_retention_size` (default `15d` / `15GB`), `backend_metrics_path` (default `/metrics`; `null` skips the app scrape) |

**Switching ALBs on a running stage.** The ECS module ignores `load_balancer` changes on an existing service (it goes with `ignore_task_definition_changes`), so Terraform creates or removes the ALB and its target group but doesn't re-register the service. After enabling or disabling an ALB, point the service at the current target groups (ECS rolls out new tasks):

```bash
aws ecs update-service --cluster <stage>-cluster --service dogood-backend --load-balancers \
  targetGroupArn=<public tg arn>,containerName=dogood-backend,containerPort=3000 \
  targetGroupArn=<internal tg arn>,containerName=dogood-backend,containerPort=3000
```

Replacing an ALB without changing the toggles (e.g. a new listener setting) keeps the target group and needs nothing.

Single-AZ mode (`db_multi_az = false`, `ecs_single_az = true`, `nat_per_az = false`) puts RDS, ECS tasks and the NAT instance in the first AZ. Subnets still span two AZs because the DB subnet group and the ALB require it.

## Monitoring (Prometheus + Grafana)

With `monitoring_enabled = true`:

- **Host:** separate ECS cluster `<stage>-monitoring` with one EC2 container instance (`monitoring_instance_type`, ECS-optimized AL2023, gp3 `monitoring_volume_size` GiB, IMDSv2, SSM, no ingress) in an ASG of 1 over the private subnets.
- **Task** (`monitoring` service, `awsvpc`, task SG `<stage>-monitoring-sg`, all containers share localhost):
  - **Prometheus** `:9090`, image pinned by digest. Discovers backend tasks through the ECS API and NAT instances through the EC2 API (built-in `aws_sd_configs`, task role, through NAT); no separate discovery sidecar. Jobs: `ecs-exporter` (`:9779`), `backend` (`app_port` + `backend_metrics_path`), `node-nat` (`:9100`), `postgres`, `blackbox-api` (probes `https://<api_hostname><app_health_check_path>` from outside through NAT), plus its own, Grafana and exporter metrics.
  - **Grafana** `:3000`, data sources Prometheus (default) and CloudWatch (task role, read-only metrics).
  - **postgres_exporter** `:9187` as role `monitoring` with `pg_monitor`. The one-shot `postgres-init` container creates/updates that role at every task start with the RDS master credentials; its password is in `/dogood/<stage>/monitoring-db` (write-only, not in state). The exporter starts even if the init failed (`pg_up = 0` then).
  - **blackbox_exporter** `:9115`, default modules (`http_2xx`).
- **Backend sidecar:** `ecs-exporter` (`:9779`) in the backend task (CPU/memory/network from the task metadata endpoint). Terraform ignores task definition changes of the backend service, so after enabling monitoring on a running stage, deploy the new revision: `aws ecs update-service --cluster <stage>-cluster --service dogood-backend --task-definition <stage>-dogood-backend`.
- **Security groups** (in `modules/networking`): monitoring SG -> backend tasks (`app_port`, 9779), RDS (`db_port`), NAT SGs (9100), 443 to the internet; ingress only Grafana `:3000` from the ALB SG.
- **Data:** Prometheus TSDB and Grafana SQLite live in Docker volumes on the instance root volume. They survive task restarts and redeploys (deploys stop the old task first), but not an instance replacement (new AMI + refresh, instance failure).
- **Grafana admin password:** generated as an ephemeral value and written write-only to `/dogood/<stage>/grafana` (key `admin_password`). Grafana applies it only when it creates its database; to rotate it later, bump `secret_string_wo_version` and run `grafana cli admin reset-admin-password` in the task.

**Access.** With `monitoring_hostname` (needs `api_hostname`): ALB rule `host = monitoring_hostname` AND source IP in `monitoring_allowed_cidrs` -> Grafana; the same host from anywhere else -> 403. The DNS record must be DNS only (see *Ingress, TLS and DNS*). Without it, or for Prometheus, use the SSM tunnel (AWS CLI + [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)):

```bash
scripts/grafana-tunnel.sh mvp              # Grafana: http://localhost:3000
scripts/grafana-tunnel.sh mvp 9090 9090    # Prometheus: http://localhost:9090
# Windows: .\scripts\grafana-tunnel.ps1 -Stage mvp -LocalPort 3000 -RemotePort 3000
aws secretsmanager get-secret-value --secret-id /dogood/mvp/grafana --query SecretString --output text
```

## Frontend (Amplify)

`frontend/` is a standalone root module: one Amplify app for all branches (`branches` in `frontend/terraform.tfvars`: git branch => subdomain of `dogood.ink`). Values live in `frontend/terraform.tfvars` (git-ignored); `api_url` becomes `NEXT_PUBLIC_API_URL`.

```bash
cd frontend
terraform init
export TF_VAR_access_token=<GitHub PAT with access to DoGood-org/dogood-frontend>   # only to create the app
terraform apply
terraform output subdomain_dns_records                 # CNAMEs for Cloudflare
terraform output certificate_verification_dns_record   # certificate validation CNAME
```

DNS is in Cloudflare: create the CNAMEs from the outputs (DNS only, not proxied, until the certificate is issued). `NEXT_PUBLIC_*` values are baked in at build time, so changing them needs a new build of the branch.
