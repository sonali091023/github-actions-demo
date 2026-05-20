#Locals improve readability + reusability + DRY principle
locals {                                       
  selected_instance_type = var.instance_type_map[var.env]   #Picks instance type based on environment
  selected_key_pair= var.key_pair_map[var.env]
  name_prefix = "${var.project_name}-${var.env}"

  common_tags = {         #Standard tags for all resources
    Project     = var.project_name
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# Latest Amazon Linux AMI, Get latest Ubuntu AMI dynamically (recommended instead of hardcoding)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
}

resource "aws_vpc" "vpc" {                       #Virtual Private Cloud (VPC)
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true                    #DNS enabled → Required for EC2 hostname resolution

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-VPC"
  })
}


#public subnet
#public subnet inside vpc
resource "aws_subnet" "public_subnet" {         #Creates a subnet inside VPC
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true                #Instances get public IP automatically

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-Public-Subnet"
  })
}

#internet gateway
#Connects vpc to the internet
resource "aws_internet_gateway" "igw" {        #Connects your VPC to the internet
  vpc_id = aws_vpc.vpc.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

#route table
#routes traffic from subnet to IGW     #Defines routing rules, 0.0.0.0/0 → IGW, It means Send all internet traffic to Internet Gateway
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

#route table association with subnet/Link route table with subnet, Subnet won’t have internet routing
resource "aws_route_table_association" "public_rt_association" {     #Links: Subnet + Route Table
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

#Security group is the Dynamic firewall SSH-22 HTTP-80
# Firewall: allow SSH & HTTP, all outbound
resource "aws_security_group" "ec2_sg" {
  name        = "SkillPulse-SG"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" { 
    for_each = var.allowed_ports     #Automatically creates rules for each port

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      #cidr_blocks = ["YOUR.IP.ADDRESS/32"]    best practice
    }
  }

  egress {
    description = "Allow all outbounds"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "SkillPulse-SG"
  })
}

resource "aws_instance" "SkillPuls_Server" {     #This launches EC2 instance inside your subnet
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_map[var.env]   #Picks instance type based on environment
  key_name                    = var.key_pair_map[var.env]
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  #Square brackets are required because Terraform expects a list, even for a single security group.

  ##This is bootstrap script, So what happen here is Installs Nginx, Starts it & Enables it on boot & Your EC2 becomes a web server automatically
  user_data = templatefile("${path.module}/scripts/script.sh.tpl", {
    repo_url = var.project_repo
})

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-server"
  })

}






