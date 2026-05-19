#variables.tf → defines structure
variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type = string
}

#=================In case of dynamic value===========
variable "env" {
  description = "Environment (dev, stage, prod, qa)"
  type        = string
}

#====================================================

#Extra tag----------------> Here Define variable
variable "extra_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)     #Key-value pairs (both strings)
  default     = {}              #Empty map (no extra tags by default)
}