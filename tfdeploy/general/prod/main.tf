locals {
  tags = {
    Terraform = "true"
    environment = "prod"
  }
  common_tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_eip" "nat" {
  count = 3
  vpc = true
}

module "vpc" {
  source = "../../module/vpc"
  name = var.name
  cidr = var.vpc_block
  azs             = var.avaiability_zone
  private_subnets = var.public_subnets_prefix_list
  public_subnets  = var.private_subnets_prefix_list
  enable_nat_gateway = true
  enable_vpn_gateway = true
  single_nat_gateway  = false
  reuse_nat_ips       = true                    # <= Skip creation of EIPs for the NAT Gateways
  external_nat_ip_ids = "${aws_eip.nat.*.id}"   # <= IPs specified here as input to the module

  enable_dns_hostnames = true
  enable_dns_support   = true
  
   # VPC Flow Logs (Cloudwatch log group and IAM role will be created)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  tags = local.tags
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}
