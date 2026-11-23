# Separate ECS cluster with one EC2 container instance for the monitoring task.
# Prometheus and Grafana data live in Docker volumes on the instance root volume: they
# survive task restarts and redeploys, but not an instance replacement.

resource "aws_ecs_cluster" "this" {
  name = "${var.stage}-monitoring"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name    = "${var.stage}-monitoring"
    Service = "monitoring"
  }
}

module "host_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name            = "${var.stage}-monitoring-host-sg"
  description     = "Monitoring container instance (ECS agent); the task has its own SG"
  vpc_id          = var.vpc_id
  use_name_prefix = false

  # No ingress (SSM only)

  egress_rules = {
    https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "ECS, ECR, SSM, CloudWatch Logs, image registries via NAT"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = {
    Name    = "${var.stage}-monitoring-host-sg"
    Service = "monitoring"
  }
}

resource "aws_launch_template" "this" {
  name = "${var.stage}-monitoring"

  # Latest ECS-optimized AL2023; a new AMI shows up in plan, the running instance keeps
  # its AMI until it is replaced
  image_id      = nonsensitive(data.aws_ssm_parameter.ecs_ami.value)
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.host.arn
  }

  vpc_security_group_ids = [module.host_sg.id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # awsvpc tasks can't reach the instance metadata (and its role); awslogs uses the
  # task execution role instead of the instance role
  user_data = base64encode(<<-EOT
    #!/bin/bash
    cat >> /etc/ecs/ecs.config <<'EOF'
    ECS_CLUSTER=${aws_ecs_cluster.this.name}
    ECS_AWSVPC_BLOCK_IMDS=true
    ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE=true
    EOF
  EOT
  )

  dynamic "tag_specifications" {
    for_each = ["instance", "volume", "network-interface"]

    content {
      resource_type = tag_specifications.value
      tags = merge(data.aws_default_tags.current.tags, {
        Name    = "${var.stage}-monitoring"
        Service = "monitoring"
      })
    }
  }

  tags = {
    Name    = "${var.stage}-monitoring"
    Service = "monitoring"
  }
}

resource "aws_autoscaling_group" "this" {
  name                = "${var.stage}-monitoring"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  health_check_type   = "EC2"
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  tag {
    key                 = "Service"
    value               = "monitoring"
    propagate_at_launch = false
  }

  timeouts {
    delete = "15m"
  }
}
