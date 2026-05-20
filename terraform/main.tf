locals {
  name_prefix = "${var.project_name}-${var.env}"

  common_tags = {
    Project     = var.project_name
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ---------------- VPC ----------------
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# ---------------- Public Subnet ----------------
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-subnet"
  })
}

# ---------------- Internet Gateway ----------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# ---------------- Route Table ----------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

# ---------------- Route Table Association ----------------
resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

#------------------Security Group with Dynamic Ports------------------
resource "aws_security_group" "ec2_sg" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for EC2 allowing dynamic ports"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_ports

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ingress.value == 22 ? [var.ssh_cidr] : ["0.0.0.0/0"]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg"
  })
}

# Get latest Ubuntu AMI dynamically (recommended instead of hardcoding)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
}

# ---------------- EC2 Instance ----------------
resource "aws_instance" "skill_pulse_server" {
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type_map[var.env]
  key_name      = var.key_pair_map[var.env]
  subnet_id = var.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids = var.security_group_ids

  user_data = templatefile("${path.module}/scripts/script.sh.tpl", {
      repo_url = var.project_repo                                          #This makes everything install automatically when EC2 launches.
})     

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-server"
  })
}

