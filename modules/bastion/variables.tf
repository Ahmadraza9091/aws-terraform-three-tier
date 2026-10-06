variable "public_subnet_id" {
  description = "Public subnet in which to launch the bastion host"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Security group attached to the bastion host"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the AWS EC2 key pair used to access the bastion host"
  type        = string
}
