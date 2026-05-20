variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "project_repo" {
  type        = string
  default     = "https://github.com/sonali091023/github-actions-demo.git"
}
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "vpc_id" {
  description = "VPC ID where security group will be created"
  type        = string
}

variable "ssh_cidr" {
  description = "Allowed CIDR for SSH access"
  type        = string
  #default     = "0.0.0.0/0"  # tighten in production
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where EC2 will be launched"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
  default     = []
}

#=================In case of dynamic value===========
variable "env" {
  description = "Environment (dev, stage, prod, qa)"
  type        = string
}

# Instance type per environment
variable "instance_type_map" {
  description = "Instance type per environment"
  type        = map(string)

  default = {
    dev   = "t3.micro"
    stage = "t3.small"
    prod  = "c7i-flex.large"
    qa = "t3.medium"
  }
}

# Key pair per environment
variable "key_pair_map" {
  description = "Key pair per environment"
  type        = map(string)

  default = {
    dev   = "de-key"
    stage = "stage-key"
    prod  = "prod-key"
    qa = "skill-pulse-key"
  }
}

#====================================================

#multiple port numbers
variable "allowed_ports" {
  description = "List of allowed inbound ports"
  type        = list(number)      #A list of numeric values
  default = [22, 80, 443, 8080, 3306]         #default: Used if you don’t override it [SSH, HTTP, HTTPS]
}

#Extra tag----------------> Here Define variable
variable "extra_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)     #Key-value pairs (both strings)
  default     = {}              #Empty map (no extra tags by default)
}