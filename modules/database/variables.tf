variable "private_subnet_ids" {
  description = "Private subnets for the RDS DB subnet group"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "Security group attached to the RDS instance"
  type        = string
}

variable "db_password" {
  description = "Master password for the production RDS MySQL database"
  type        = string
  sensitive   = true
}
