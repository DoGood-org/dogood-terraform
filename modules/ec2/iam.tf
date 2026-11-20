resource "aws_iam_role" "this" {
  name               = "ec2-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

    tags = {
    Name    = "ec2-execution-role"
    Service = "backend"
  }
}

# Контейнер, через який роль прикріплюється до EC2-інстанса
resource "aws_iam_instance_profile" "this" {
  name = "ec2-execution-role"
  role = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  name   = "rds-and-secrets"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.inline.json
}