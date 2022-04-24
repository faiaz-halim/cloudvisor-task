aws_region           = "ap-northeast-1"
prefix               = "dev"
size                 = "t3.medium"
ami_id               = "ami-0a3eb6ca097b78895"
vpc_block            = "172.20.0.0/16"
avaiability_zone = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
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
database_subnets_prefix_list = [
  "172.20.96.0/20",
  "172.20.112.0/20",
  "172.20.128.0/20",
]
