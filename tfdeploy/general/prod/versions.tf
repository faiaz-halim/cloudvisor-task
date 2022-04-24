terraform {
  backend "s3" {
    bucket         = "prod-1kdyulmsldk6d7qixab-state-bucket"
    key            = "prod-main-deployment.tfstate"
    region         = "eu-north-1"
    encrypt        = "true"
    role_arn       = "arn:aws:iam::140370042521:role/prod-1kdyulmsldk6d7qixab-tf-assume-role"
    dynamodb_table = "prod-1kdyulmsldk6d7qixab-state-lock"
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
  region ="eu-north-1"
}

