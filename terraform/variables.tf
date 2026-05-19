variable "my_ip" {}

variable "bucket_name" {}

#===================================================================

#variables.tf → defines structure
variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "repo_url" {
  description = "Repository URL"
  default = "https://github.com/sonali091023/github-actions-repo.git"
  type        = string
}

variable "dockerhub_username" {
  description = "dockerhub username"
  default = "sonali0910"
    type        = string
}

variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16" 
}

variable "public_subnet_cidr" {
  type = string
  default = "10.0.1.0/24" 
}

variable "private_subnet_cidr" {
  default = "10.0.2.0/24"
}

variable "instance_type" {
  type = string
  default = "t3.micro"
}

variable "project_name" {
  description = "Name of the project"
  type = string  
}

variable "key_name" {
  type = string
  default = "skill-pulse-key"
  
}

#=================In case of dynamic value===========
variable "env" {
  description = "Environment (dev, stage, prod)"
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