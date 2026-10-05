resource "aws_db_subnet_group" "mysql" {
  name       = "production-mysql-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "production-mysql-subnet-group"
    Environment = "production"
    Tier        = "database"
  }
}

resource "aws_db_instance" "mysql" {
  identifier = "production-mysql"

  engine         = "mysql"
  engine_version = "8.0"

  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "productiondb"
  username = "admin"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [var.rds_security_group_id]

  publicly_accessible     = false
  multi_az                = true
  backup_retention_period = 0

  backup_window      = "03:00-04:00"
  maintenance_window = "sun:04:00-sun:05:00"

  skip_final_snapshot = true

  tags = {
    Name        = "production-mysql"
    Environment = "production"
    Tier        = "database"
  }
}
