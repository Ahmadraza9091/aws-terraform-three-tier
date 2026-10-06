variable "vpc_id" {
  description = "VPC for the application target group"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets used by the Application Load Balancer"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets used by the application Auto Scaling group"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group attached to the Application Load Balancer"
  type        = string
}

variable "ec2_security_group_id" {
  description = "Security group attached to application instances"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the AWS EC2 key pair used to access application instances"
  type        = string
}

variable "db_host" {
  description = "Private DNS address of the RDS database"
  type        = string
}

variable "db_port" {
  description = "Port used by the RDS database"
  type        = number
}

variable "db_name" {
  description = "Application database name"
  type        = string
}

variable "db_username" {
  description = "Application database username"
  type        = string
}

variable "db_password" {
  description = "Application database password"
  type        = string
  sensitive   = true
}

variable "admin_username" {
  description = "Initial application administrator username"
  type        = string
}

variable "admin_password" {
  description = "Initial application administrator password"
  type        = string
  sensitive   = true
}

variable "session_secret" {
  description = "Secret used to sign application session cookies"
  type        = string
  sensitive   = true
}
