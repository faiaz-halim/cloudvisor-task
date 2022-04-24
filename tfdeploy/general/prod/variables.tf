variable "aws_region" {
  type = string
}

variable "name" {
  type = string
}

variable "vpc_block" {
  type = string
}

variable "public_subnets_prefix_list" {
  type = list(string)
}

variable "private_subnets_prefix_list" {
  type = list(string)
}

variable "avaiability_zone" {
  type = list(string)
}
