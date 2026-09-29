# ==========================================
# General
# ==========================================
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "qp001"
}

# ==========================================
# Network
# ==========================================
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "my_ip_cidr" {
  type        = string
  description = "Your IP address with /32 suffix for SSH access, e.g. 203.0.113.10/32"
}

# ==========================================
# EC2
# ==========================================
variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type. t3.micro is Free Tier eligible. t4g.nano is cheaper but not Free Tier eligible."
}

variable "ec2_key_name" {
  type        = string
  description = "Name of the EC2 KeyPair for SSH access (create in AWS Console beforehand)"
}

# ==========================================
# RDS
# ==========================================
variable "db_password" {
  type        = string
  sensitive   = true
  description = "RDS master password (at least 8 chars)"
}

variable "db_name" {
  type    = string
  default = "wordpress"
}

variable "db_username" {
  type    = string
  default = "wordpress_user"
}

# ==========================================
# Route53
# ==========================================
variable "domain_name" {
  type    = string
  default = "qp001.blog"
}

# ==========================================
# Budgets
# ==========================================
variable "budget_limit_usd" {
  type    = number
  default = 35.0
}

variable "alert_email" {
  type        = string
  description = "Email address for budget alerts and Let's Encrypt notifications"
}
