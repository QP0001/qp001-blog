variable "project_name" {
  type = string
}

variable "limit_amount" {
  type        = number
  description = "Monthly budget limit in USD"
}

variable "alert_email" {
  type = string
}

variable "time_period_start" {
  type    = string
  default = "2026-10-01_00:00"
}
