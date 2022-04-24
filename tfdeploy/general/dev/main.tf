locals {
  tags = {
    Terraform = "true"
    environment = "dev"
  }
  common_tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_eip" "nat" {
  count = 3
  vpc = true
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source = "../../module/vpc"
  name = "${var.prefix}-vpc"
  cidr = var.vpc_block
  azs             = var.avaiability_zone
  private_subnets = var.private_subnets_prefix_list
  public_subnets  = var.public_subnets_prefix_list
  database_subnets = var.database_subnets_prefix_list
  enable_nat_gateway = true
  enable_vpn_gateway = true
  single_nat_gateway  = false
  reuse_nat_ips       = true                    # <= Skip creation of EIPs for the NAT Gateways
  external_nat_ip_ids = "${aws_eip.nat.*.id}"   # <= IPs specified here as input to the module

  create_database_subnet_group = true
  enable_dns_hostnames = true
  enable_dns_support   = true
  
   # VPC Flow Logs (Cloudwatch log group and IAM role will be created)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

module "security_group" {
  source  = "../../module/security-group"

  name        = "${var.prefix}-sg"
  description = "Security group for usage with EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp", "ssh-tcp", "all-icmp"]
  egress_rules        = ["all-all"]

  tags = local.tags
}

resource "aws_kms_key" "this" {
}

module "key_pair" {
  source = "../../module/key-pair"

  key_name   = "ssh-access"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDMNk9HVDB1kCUg3+YGtdLBsLApR8zeEEc6e/3L2ywwcm7IfJymzUKEjY0J9Qe2RAFXLnXJEsiDJUQw6bXHp8Yd5IO/1UEDn0qy3+M9dwNh5uxUnK+NMQGwuDJiar9Jc06q4/+8/iuNd5CPs3lsvAp0THIhDWut0Mhh3GQOushWMTWRlFxfqfv90ta/utM1qnMUx2kXUfeefWnCfSiX2qTBTmJOQr4l294VhFo47T5I0uRt0erHTcrOxKzy3OQMwDMi4NoY3FqRawqJA29I1voIqbBY3YkgC8O0y//eCwz26xAhQyCr7ZLG9gPnfZr4JZa/GZWO/NjG2A4XWozi0mRYOXSz58G0X5GdAaPiGJ+yKNBnqsQONP+tbb4ZibPe//ICgevOtKhk87RTnVZWYttJ2vIPyIk9NAbV4TB+9d2pqIxruWPa2syhf7IQNULJG37h/HnUirxvB3du9gGhZkOnNnraC06FKEHwU9VscBYnVii95r3Gvuz6Pe+fOilJJR3WegITdcmKCHTnfs4OYBhq9kbPwm/L6SStWuapL2VlVFWeZmffHYBxl7GlDXxB1x8pLpwuRAzXTqYkorIcfoLPDAiB/Y9YByHeMvbKB+dT2eOt970r1R8mu9OwRKBBmyLp0e83tNSkswyRb+E6yn+9e4DLMn69mKBhxTz2SZ0vEw== faiaz.halim@gmail.com"

}

module "db_security_group" {
  source  = "../../module/security-group"

  name        = "${var.prefix}-db-sg"
  description = "Complete MySQL example security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "MySQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = local.tags
}

################################################################################
# RDS Module
################################################################################

module "db" {
  source = "../../module/rds"

  identifier = "${var.prefix}-db"

  # All available versions: http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html#MySQL.Concepts.VersionMgmt
  engine               = "mysql"
  engine_version       = "8.0.27"
  family               = "mysql8.0" # DB parameter group
  major_engine_version = "8.0"      # DB option group
  instance_class       = "db.t2.medium"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = "client"
  username = "faiaz"
  port     = 3306

  multi_az               = true
  publicly_accessible    = false # Should turn off for production
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  create_db_subnet_group = false
  subnet_ids             = module.vpc.database_subnets
  vpc_security_group_ids = [module.db_security_group.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"

  backup_retention_period = 0
  deletion_protection = false # Should turn on for production

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  ]

  tags = local.tags
}

################################################################################
# EC2 Module
################################################################################

module "ec2_complete" {
  source = "../../module/ec2"

  name = "${var.prefix}-server"

  ami                         = var.ami_id
  instance_type               = var.size
  key_name                    = tostring(module.key_pair.key_pair_key_name)
  availability_zone           = element(var.avaiability_zone, 0)
  subnet_id                   = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true

  user_data = "${file("init.sh")}"

  cpu_core_count       = 1 # default 2
  cpu_threads_per_core = 2 # default 2

  capacity_reservation_specification = {
    capacity_reservation_preference = "open"
  }

  enable_volume_tags = false
  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp3"
      throughput  = 200
      volume_size = 50
      tags = {
        Name = "dev-server-root-block"
      }
    },
  ]

  ebs_block_device = [
    {
      device_name = "/dev/sdf"
      volume_type = "gp3"
      volume_size = 50
      throughput  = 200
      encrypted   = true
      kms_key_id  = aws_kms_key.this.arn
    }
  ]

  tags = local.tags
}

resource "aws_ami_from_instance" "this" {
  name               = "${var.prefix}-ami"
  source_instance_id = module.ec2_complete.id
  depends_on         = [module.ec2_complete]
}

resource "aws_ssm_parameter" "db_host" {
  name        = "/dev/db_host"
  description = "RDS DB Host"
  type        = "String"
  value       = module.db.db_instance_address

  tags = local.tags
}

resource "aws_ssm_parameter" "db_user" {
  name        = "/dev/db_user"
  description = "RDS DB User"
  type        = "SecureString"
  value       = module.db.db_instance_username

  tags = local.tags
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/dev/db_password"
  description = "RDS DB Password"
  type        = "SecureString"
  value       = module.db.db_instance_password

  tags = local.tags
}

resource "aws_ssm_parameter" "db_name" {
  name        = "/dev/db_name"
  description = "RDS DB Name"
  type        = "String"
  value       = module.db.db_instance_name

  tags = local.tags
}