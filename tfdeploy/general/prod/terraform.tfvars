aws_region           = "eu-north-1"
name                 = "prod-vpc"
vpc_block            = "172.20.0.0/16"
avaiability_zone = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
public_subnets_prefix_list = [
  "172.20.0.0/20",
  "172.20.16.0/20",
  "172.20.32.0/20",
]
private_subnets_prefix_list = [
  "172.20.48.0/20",
  "172.20.64.0/20",
  "172.20.80.0/20",
]

