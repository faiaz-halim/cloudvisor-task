provider "aws" {
    region = "ap-northeast-1"
}

module "s3backend" {
 source = "../../../module/remote-backend/"
 namespace = "dev"
}
output "s3backend_config" {
  value = module.s3backend.config
}