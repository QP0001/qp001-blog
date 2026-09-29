variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "my_ip_cidr" {
  type        = string
  description = "Your IP with /32, e.g. 1.2.3.4/32"
}
