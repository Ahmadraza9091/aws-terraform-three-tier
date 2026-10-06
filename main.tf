terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_key_pair" "ssh" {
  key_name_prefix = "linux-practice-"
  public_key      = file("${path.root}/linux_practice.pem.pub")
}

module "network" {
  source = "./modules/network"

  availability_zones = var.availability_zones
}

module "security" {
  source = "./modules/security"

  vpc_id           = module.network.vpc_id
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

module "bastion" {
  source = "./modules/bastion"

  public_subnet_id          = module.network.public_subnet_ids[0]
  bastion_security_group_id = module.security.bastion_security_group_id
  ssh_key_name              = aws_key_pair.ssh.key_name
}

module "application" {
  source = "./modules/application"

  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  ec2_security_group_id = module.security.ec2_security_group_id
  ssh_key_name          = aws_key_pair.ssh.key_name
  db_host               = module.database.rds_address
  db_port               = module.database.rds_port
  db_name               = "productiondb"
  db_username           = "admin"
  db_password           = var.db_password
  admin_username        = var.app_admin_username
  admin_password        = var.app_admin_password
  session_secret        = var.app_session_secret
}

module "database" {
  source = "./modules/database"

  private_subnet_ids    = module.network.private_subnet_ids
  rds_security_group_id = module.security.rds_security_group_id
  db_password           = var.db_password
}
