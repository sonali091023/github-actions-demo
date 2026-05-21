variable "project_name" {
  description = "Project name"
  type        = string
  default     = "skill-pulse-server"
}

variable "project_repo" {
  description = "GitHub repo URL"
  type        = string
  default     = "https://github.com/sonali091023/github-actions-demo.git"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "ssh_cidr" {
  description = "Allowed SSH CIDR"
  type        = string
}

variable "instance_type_map" {
  description = "EC2 instance type per environment"
  type        = map(string)

  default = {
    dev   = "m7i-flex.large"
    stage = "m7i-flex.large"
    qa    = "m7i-flex.large"
    prod  = "m7i-flex.large"
  }
}

variable "key_pair_map" {
  description = "Key pair per environment"
  type        = map(string)

  default = {
    dev   = "skill-pulse-key"
    stage = "skill-pulse-key"
    qa    = "skill-pulse-key"
    prod  = "skill-pulse-key"
  }
}

variable "env" {
  description = "Environment (dev, stage, prod, qa)"
  type        = string
}

variable "allowed_ports" {
  description = "Allowed inbound ports"
  type        = list(number)

  default = [22, 80, 443, 8080, 3306]
}

variable "extra_tags" {
  description = "Extra tags"
  type        = map(string)
  default     = {}
}