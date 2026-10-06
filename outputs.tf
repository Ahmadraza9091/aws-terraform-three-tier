output "vpc_id" {
  description = "ID of the production VPC"
  value       = module.network.vpc_id
}


output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.network.private_subnet_ids
}


output "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer"
  value       = module.security.alb_security_group_id
}

output "ec2_security_group_id" {
  description = "Security group ID for application EC2 instances"
  value       = module.security.ec2_security_group_id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS MySQL"
  value       = module.security.rds_security_group_id
}

output "alb_dns_name" {
  description = "DNS name of the production Application Load Balancer"
  value       = module.application.alb_dns_name
}


output "autoscaling_group_name" {
  description = "Name of the production application Auto Scaling Group"
  value       = module.application.autoscaling_group_name
}

output "bastion_public_ip" {
  description = "Public IPv4 address of the SSH bastion host"
  value       = module.bastion.public_ip
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = module.database.rds_endpoint
}

output "rds_port" {
  description = "RDS MySQL port"
  value       = module.database.rds_port
}