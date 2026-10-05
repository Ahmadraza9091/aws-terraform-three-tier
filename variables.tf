variable "aws_region" {
  description = "AWS region where infrastructure will be deployed"
  type        = string
  default     = "us-east-1"
}


variable "availability_zones" {
  description = "Availability zones for the production infrastructure"
  type        = list(string)

  default = [
    "us-east-1a",
    "us-east-1b"
  ]
}


variable "db_password" {
  description = "Master password for the production RDS MySQL database"
  type        = string
  sensitive   = true
}

variable "app_admin_username" {
  description = "Initial administrator username for the CRUD application"
  type        = string
  default     = "admin"
}

variable "app_admin_password" {
  description = "Initial administrator password for the CRUD application (minimum 12 characters)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.app_admin_password) >= 12
    error_message = "app_admin_password must be at least 12 characters long."
  }
}

variable "app_session_secret" {
  description = "Random secret used to sign application sessions (minimum 32 characters)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.app_session_secret) >= 32
    error_message = "app_session_secret must be at least 32 characters long."
  }
}

