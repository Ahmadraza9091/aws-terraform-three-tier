resource "aws_lb" "app" {
  name               = "production-app-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [var.alb_security_group_id]
  subnets         = var.public_subnet_ids

  tags = {
    Name        = "production-app-alb"
    Environment = "production"
    Tier        = "public"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "production-app-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health.php"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = {
    Name        = "production-app-target-group"
    Environment = "production"
    Tier        = "private"
  }
}

resource "aws_lb_listener" "app_http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  app_user_data = templatefile("${path.root}/application/deploy/apache-php-ec2-user-data.sh.tftpl", {
    index_php_gzip_b64  = base64gzip(file("${path.root}/application/public/index.php"))
    health_php_gzip_b64 = base64gzip(file("${path.root}/application/public/health.php"))
    styles_css_gzip_b64 = base64gzip(file("${path.root}/application/public/styles.css"))
    app_config_b64 = base64encode(jsonencode({
      db_host        = var.db_host
      db_port        = var.db_port
      db_name        = var.db_name
      db_username    = var.db_username
      db_password    = var.db_password
      admin_username = var.admin_username
      admin_password = var.admin_password
      session_secret = var.session_secret
    }))
  })
}

resource "aws_launch_template" "app" {
  name_prefix   = "production-app-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [var.ec2_security_group_id]

  user_data = base64encode(local.app_user_data)

  lifecycle {
    precondition {
      condition     = length(local.app_user_data) <= 16384
      error_message = "Compressed application user data exceeds the 16 KiB EC2 limit; deploy the app through an artifact bucket instead."
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "production-app-server"
      Environment = "production"
      Tier        = "private"
    }
  }

  tags = {
    Name        = "production-app-launch-template"
    Environment = "production"
  }
}

resource "aws_autoscaling_group" "app" {
  name = "production-app-asg"

  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.app.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 600

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 600
      skip_matching          = true
    }
  }

  tag {
    key                 = "Name"
    value               = "production-app-server"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "production"
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "private"
    propagate_at_launch = true
  }
}
