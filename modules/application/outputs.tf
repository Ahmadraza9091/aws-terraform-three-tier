output "alb_dns_name" {
  description = "DNS name of the production Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "autoscaling_group_name" {
  description = "Name of the production application Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}
