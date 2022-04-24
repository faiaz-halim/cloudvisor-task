terraform {
  backend "s3" {
    bucket         = "dev-jau1y64hw407s7vreo2n-state-bucket"
    key            = "dev-main-deployment.tfstate"
    region         = "ap-northeast-1"
    encrypt        = "true"
    role_arn       = "arn:aws:iam::140370042521:role/dev-jau1y64hw407s7vreo2n-tf-assume-role"
    dynamodb_table = "dev-jau1y64hw407s7vreo2n-state-lock"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.73"
    }
  }
  required_version = ">= 0.13.1"
}

provider "aws" {
  region ="ap-northeast-1"
}

