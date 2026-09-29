variable "project_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "iam_instance_profile" {
  type = string
}

variable "key_name" {
  type        = string
  description = "EC2 KeyPair name for SSH access"
}

variable "root_volume_size" {
  type    = number
  default = 30
}

variable "efs_dns_name" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_host" {
  type = string
}

variable "alert_email" {
  type        = string
  description = "Email address for Let's Encrypt certbot notifications"
}
