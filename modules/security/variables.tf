variable "vpc_id" {
  description = "VPC in which to create the security groups"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "IPv4 CIDR allowed to connect to the bastion host over SSH"
  type        = string
}
