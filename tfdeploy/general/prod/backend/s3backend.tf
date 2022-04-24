provider "aws" {
    region = "eu-north-1"
}

module "s3backend" {
 source = "../../../module/remote-backend/"
 namespace = "prod"
}
output "s3backend_config" {
  value = module.s3backend.config
}