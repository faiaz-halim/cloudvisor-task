locals {
  cloud_config = <<-END
    #cloud-config
    ${jsonencode({
      write_files = [
        {
          path        = "init.sh"
          permissions = "0644"
          owner       = "root:root"
          encoding    = "b64"
          content     = filebase64("${path.module}/init.sh")
        },
      ]
    })}
  END

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
  description = "${var.prefix}-kms"
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

module "alb_http_security_group" {
  source  = "../../module/security-group/modules/http-80"

  name        = "${var.prefix}-alb-http-sg"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for ${var.prefix}"

  ingress_cidr_blocks = ["0.0.0.0/0"]

  tags = local.tags
}

module "asg_security_group" {
  source  = "../../module/security-group"

  name        = "${var.prefix}-asg-sg"
  description = "A security group"
  vpc_id      = module.vpc.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb_http_security_group.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  egress_rules = ["all-all"]

  tags = local.tags
}

resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  description      = "A service linked role for autoscaling"
  custom_suffix    = "${var.prefix}"

  # Sometimes good sleep is required to have some IAM resources created before they can be used
  provisioner "local-exec" {
    command = "sleep 10"
  }
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.prefix}-iam-instance-profile"
  role = aws_iam_role.ssm.name
  tags = local.tags
}

resource "aws_iam_role" "ssm" {
  name = "${var.prefix}-iam-role"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
}

resource "aws_kms_grant" "this" {
  name              = "${var.prefix}-iam-role-grant"
  key_id            = aws_kms_key.this.key_id
  grantee_principal = aws_iam_service_linked_role.autoscaling.arn
  operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
}

module "alb" {
  source  = "../../module/alb"

  name = "${var.prefix}-asg-alb"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [module.alb_http_security_group.security_group_id]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      name             = var.prefix
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    },
  ]

  tags = local.tags
}

data "cloudinit_config" "ec2" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    filename     = "cloud-config.yaml"
    content      = local.cloud_config
  }

  # part {
  #   content_type = "text/x-shellscript"
  #   filename     = "example.sh"
  #   content  = <<-EOF
  #     #!/bin/bash
  #     echo "Hello World"
  #   EOF
  # }
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

################################################################################
# EC2 Autoscaling Group
################################################################################

module "ec2_asg" {
  source = "../../module/autoscaling"

  # Autoscaling group
  name            = "${var.prefix}-asg"
  use_name_prefix = false
  instance_name   = "${var.prefix}"

  ignore_desired_capacity_changes = true

  min_size                  = 0
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = module.vpc.private_subnets
  service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn

  initial_lifecycle_hooks = [
    {
      name                 = "ExampleStartupLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 60
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                 = "ExampleTerminationLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 180
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

  # Launch template
  launch_template_name        = "${var.prefix}-launch-template"
  launch_template_description = "Complete launch template example"
  update_default_version      = true

  image_id          = aws_ami_from_instance.this.id
  instance_type     = "t3.micro"
  user_data         = "${base64encode(data.cloudinit_config.ec2.rendered)}"
  ebs_optimized     = true
  enable_monitoring = true

  iam_instance_profile_arn = aws_iam_instance_profile.ssm.arn
  # # Security group is set on the ENIs below
  # security_groups          = [module.asg_sg.security_group_id]

  target_group_arns = module.alb.target_group_arns

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 50
        volume_type           = "gp3"
      }
      }, {
      device_name = "/dev/sdf"
      no_device   = 1
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 50
        volume_type           = "gp2"
      }
    }
  ]

  capacity_reservation_specification = {
    capacity_reservation_preference = "open"
  }

  cpu_options = {
    core_count       = 1
    threads_per_core = 1
  }

  credit_specification = {
    cpu_credits = "standard"
  }

  # enclave_options = {
  #   enabled = true # Cannot enable hibernation and nitro enclaves on same instance nor on T3 instance type
  # }

  # hibernation_options = {
  #   configured = true # Root volume must be encrypted & not spot to enable hibernation
  # }

  instance_market_options = {
    market_type = "spot"
  }

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 32
    instance_metadata_tags      = "enabled"
  }

  network_interfaces = [
    {
      delete_on_termination = true
      description           = "eth0"
      device_index          = 0
      security_groups       = [module.asg_security_group.security_group_id]
    },
    {
      delete_on_termination = true
      description           = "eth1"
      device_index          = 1
      security_groups       = [module.asg_security_group.security_group_id]
    }
  ]

  placement = {
    availability_zone = element(var.avaiability_zone, 0)
  }

  tags = local.tags

  # Autoscaling Schedule
  schedules = {
    night = {
      min_size         = 0
      max_size         = 0
      desired_capacity = 0
      recurrence       = "0 18 * * 1-5" # Mon-Fri in the evening
      time_zone        = "Europe/Rome"
    }

    morning = {
      min_size         = 0
      max_size         = 1
      desired_capacity = 1
      recurrence       = "0 7 * * 1-5" # Mon-Fri in the morning
    }
  }

  # Target scaling policy schedule based on average CPU load
  scaling_policies = {
    avg-cpu-policy-greater-than-50 = {
      policy_type               = "TargetTrackingScaling"
      estimated_instance_warmup = 1200
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = 50.0
      }
    },
    predictive-scaling = {
      policy_type = "PredictiveScaling"
      predictive_scaling_configuration = {
        mode                         = "ForecastAndScale"
        scheduling_buffer_time       = 10
        max_capacity_breach_behavior = "IncreaseMaxCapacity"
        max_capacity_buffer          = 10
        metric_specification = {
          target_value = 32
          predefined_scaling_metric_specification = {
            predefined_metric_type = "ASGAverageCPUUtilization"
            resource_label         = "testLabel"
          }
          predefined_load_metric_specification = {
            predefined_metric_type = "ASGTotalCPUUtilization"
            resource_label         = "testLabel"
          }
        }
      }
    }
  }
}