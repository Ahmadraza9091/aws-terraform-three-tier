moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.main
}

moved {
  from = aws_subnet.public_1
  to   = module.network.aws_subnet.public_1
}

moved {
  from = aws_subnet.public_2
  to   = module.network.aws_subnet.public_2
}

moved {
  from = aws_subnet.private_1
  to   = module.network.aws_subnet.private_1
}

moved {
  from = aws_subnet.private_2
  to   = module.network.aws_subnet.private_2
}

moved {
  from = aws_internet_gateway.main
  to   = module.network.aws_internet_gateway.main
}

moved {
  from = aws_route_table.public
  to   = module.network.aws_route_table.public
}

moved {
  from = aws_route.public_internet
  to   = module.network.aws_route.public_internet
}

moved {
  from = aws_route_table_association.public_1
  to   = module.network.aws_route_table_association.public_1
}

moved {
  from = aws_route_table_association.public_2
  to   = module.network.aws_route_table_association.public_2
}

moved {
  from = aws_eip.nat
  to   = module.network.aws_eip.nat
}

moved {
  from = aws_nat_gateway.main
  to   = module.network.aws_nat_gateway.main
}

moved {
  from = aws_route_table.private_1
  to   = module.network.aws_route_table.private_1
}

moved {
  from = aws_route_table.private_2
  to   = module.network.aws_route_table.private_2
}

moved {
  from = aws_route.private_1_nat
  to   = module.network.aws_route.private_1_nat
}

moved {
  from = aws_route.private_2_nat
  to   = module.network.aws_route.private_2_nat
}

moved {
  from = aws_route_table_association.private_1
  to   = module.network.aws_route_table_association.private_1
}

moved {
  from = aws_route_table_association.private_2
  to   = module.network.aws_route_table_association.private_2
}

moved {
  from = aws_security_group.alb
  to   = module.security.aws_security_group.alb
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_http
  to   = module.security.aws_vpc_security_group_ingress_rule.alb_http
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_https
  to   = module.security.aws_vpc_security_group_ingress_rule.alb_https
}

moved {
  from = aws_vpc_security_group_egress_rule.alb_all
  to   = module.security.aws_vpc_security_group_egress_rule.alb_all
}

moved {
  from = aws_security_group.ec2
  to   = module.security.aws_security_group.ec2
}

moved {
  from = aws_vpc_security_group_ingress_rule.ec2_http_from_alb
  to   = module.security.aws_vpc_security_group_ingress_rule.ec2_http_from_alb
}

moved {
  from = aws_vpc_security_group_egress_rule.ec2_all
  to   = module.security.aws_vpc_security_group_egress_rule.ec2_all
}

moved {
  from = aws_security_group.rds
  to   = module.security.aws_security_group.rds
}

moved {
  from = aws_vpc_security_group_ingress_rule.rds_mysql_from_ec2
  to   = module.security.aws_vpc_security_group_ingress_rule.rds_mysql_from_ec2
}

moved {
  from = aws_vpc_security_group_egress_rule.rds_all
  to   = module.security.aws_vpc_security_group_egress_rule.rds_all
}

moved {
  from = aws_lb.app
  to   = module.application.aws_lb.app
}

moved {
  from = aws_lb_target_group.app
  to   = module.application.aws_lb_target_group.app
}

moved {
  from = aws_lb_listener.app_http
  to   = module.application.aws_lb_listener.app_http
}

moved {
  from = aws_launch_template.app
  to   = module.application.aws_launch_template.app
}

moved {
  from = aws_autoscaling_group.app
  to   = module.application.aws_autoscaling_group.app
}

moved {
  from = aws_db_subnet_group.mysql
  to   = module.database.aws_db_subnet_group.mysql
}

moved {
  from = aws_db_instance.mysql
  to   = module.database.aws_db_instance.mysql
}
