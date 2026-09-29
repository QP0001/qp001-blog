terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ==========================================
# 1. Network Foundation
# ==========================================
module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

module "securityGroups" {
  source = "../../modules/securityGroups"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  my_ip_cidr   = var.my_ip_cidr
}

# ==========================================
# 2. IAM
# ==========================================
module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
}

# ==========================================
# 3. Data Layer (RDS & EFS)
# ==========================================
module "rds" {
  source = "../../modules/rds"

  project_name       = var.project_name
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.securityGroups.rds_sg_id]
  db_password        = var.db_password
  db_username        = var.db_username  # ← これを追加
}

module "efs" {
  source = "../../modules/efs"

  project_name       = var.project_name
  subnet_ids         = [module.vpc.private_subnet_1a_id, module.vpc.private_subnet_1b_id]
  security_group_ids = [module.securityGroups.efs_sg_id]
}

# ==========================================
# 4. Compute (EC2) - waits for RDS & EFS
# ==========================================
module "ec2" {
  source = "../../modules/ec2"

  project_name         = var.project_name
  instance_type        = var.instance_type
  subnet_id            = module.vpc.public_subnet_1a_id
  security_group_ids   = [module.securityGroups.ec2_sg_id]
  iam_instance_profile = module.iam.ec2_profile_name
  key_name             = var.ec2_key_name

  efs_dns_name = module.efs.efs_dns_name
  db_name      = var.db_name
  db_username  = var.db_username
  db_password  = var.db_password
  db_host      = module.rds.address
  alert_email  = var.alert_email

  depends_on = [module.rds, module.efs]
}

# ==========================================
# 5. DNS
# ==========================================
module "route53" {
  source = "../../modules/route53"

  domain_name = var.domain_name
  elastic_ip  = module.ec2.public_ip
}

# ==========================================
# 6. Cost Monitoring
# ==========================================
module "budgets" {
  source = "../../modules/budgets"

  project_name   = var.project_name
  limit_amount   = var.budget_limit_usd
  alert_email    = var.alert_email
}
