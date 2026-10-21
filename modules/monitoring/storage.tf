# Grafana data
resource "aws_efs_file_system" "grafana" {
  count = var.efs_enabled ? 1 : 0

  creation_token  = "${var.stage}-grafana"
  encrypted       = true
  throughput_mode = "elastic"

  tags = {
    Name    = "${var.stage}-grafana-efs"
    Service = "monitoring"
  }
}

resource "aws_efs_backup_policy" "grafana" {
  count = var.efs_enabled ? 1 : 0

  file_system_id = aws_efs_file_system.grafana[0].id

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_mount_target" "grafana" {
  count = var.efs_enabled ? 1 : 0

  file_system_id  = aws_efs_file_system.grafana[0].id
  subnet_id       = var.subnet_id
  security_groups = [module.efs_sg.id]
}

# grafana user (uid 472)
resource "aws_efs_access_point" "grafana" {
  count = var.efs_enabled ? 1 : 0

  file_system_id = aws_efs_file_system.grafana[0].id

  posix_user {
    uid = 472
    gid = 0
  }

  root_directory {
    path = "/grafana"

    creation_info {
      owner_uid   = 472
      owner_gid   = 0
      permissions = "0750"
    }
  }

  tags = {
    Name    = "${var.stage}-grafana-efs-ap"
    Service = "monitoring"
  }
}
