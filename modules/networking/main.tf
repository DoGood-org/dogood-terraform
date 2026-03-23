resource "aws_vpc" "primary_vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "${var.stage}-vpc"
  }
}


resource "aws_subnet" "public_subnet" {
  count             = 2
  vpc_id            = aws_vpc.primary_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, (count.index + 10) * 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.stage}-public-subnet-${count.index + 1}"
  }

}

resource "aws_subnet" "private_subnet" {
  count             = 2
  vpc_id            = aws_vpc.primary_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, (count.index + 1) * 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.stage}-private-subnet-${count.index + 1}"
  }
}


resource "aws_internet_gateway" "primary_igw" {
  vpc_id = aws_vpc.primary_vpc.id

  tags = {
    Name = "${var.stage}-igw"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.primary_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary_igw.id
  }

  tags = {
    Name = "${var.stage}-public-route-table"
  }
}

resource "aws_route_table_association" "public_rt_association" {
  count          = length(aws_subnet.public_subnet)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.primary_vpc.id

  tags = {
    Name = "${var.stage}-private-route-table"
  }
}



resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.stage}-db-subnet-group"
  subnet_ids = aws_subnet.private_subnet[*].id
  tags = {
    Name = "${var.stage}-db-subnet-group"
  }
}



resource "aws_security_group" "instance_sg" {

  name        = "${var.stage}-instance-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.primary_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = aws_subnet.public_subnet[*].cidr_block
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.stage}-instance-sg"
  }
}



resource "aws_security_group" "db_sg" {
  name        = "${var.stage}-db-sg"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.primary_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "TCP"
    cidr_blocks = aws_subnet.public_subnet[*].cidr_block
  }

    tags = {
    Name = "${var.stage}-db-sg"
  }

}

resource "aws_security_group" "alb_sg" {
  name   = "${var.stage}-alb-sg"
  vpc_id = aws_vpc.primary_vpc.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.stage}-alb-sg"
  }
}

resource "aws_security_group" "ecs_sg" {
  name   = "${var.stage}-ecs-sg"
  vpc_id = aws_vpc.primary_vpc.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.stage}-ecs-sg"
  }
}