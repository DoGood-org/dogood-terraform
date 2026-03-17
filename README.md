# dogood-terraform

IaaC for deploying the DoGood AWS infrastructure with a module-based layout.

## Structure

- `main.tf` wires the modules together and keeps the root module thin.
- `modules/networking` owns VPC, subnets, route tables, and security groups.
- `modules/database` owns the PostgreSQL RDS instance.
- `modules/application` owns the ECS/EC2 application stack, load balancer, autoscaling, SSH key pair, and Secrets Manager secret.

## Root files

- `providers.tf` defines the Terraform and AWS provider requirements.
- `variables.tf` contains root input variables.
- `outputs.tf` re-exports the important module outputs.
- `terraform.tfvars` provides environment-specific values.

## Workflow

```bash
terraform init
terraform validate
terraform plan
```

## Notes

- Existing AWS IAM roles referenced by the app module must already exist: `ecsExecutionRole` and `EC2AccessToECR`.
- The SSH public key path in `terraform.tfvars` must point to a real local public key file.
