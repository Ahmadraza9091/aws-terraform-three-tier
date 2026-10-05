resource "aws_security_group" "alb" {
  name        = "production-alb-sg"
  description = "Security group for production Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "production-alb-sg"
    Environment = "production"
    Tier        = "public"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_security_group" "ec2" {
  name        = "production-ec2-sg"
  description = "Security group for production EC2 application servers"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "production-ec2-sg"
    Environment = "production"
    Tier        = "private"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_http_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = aws_security_group.alb.id

  from_port   = 3000
  ip_protocol = "tcp"
  to_port     = 3000
}

resource "aws_vpc_security_group_egress_rule" "ec2_all" {
  security_group_id = aws_security_group.ec2.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_security_group" "rds" {
  name        = "production-rds-sg"
  description = "Security group for production RDS MySQL"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "production-rds-sg"
    Environment = "production"
    Tier        = "database"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_mysql_from_ec2" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ec2.id

  from_port   = 3306
  ip_protocol = "tcp"
  to_port     = 3306
}

resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
