module "s3-webapp" {
  source  = "app.terraform.io/dcatcher-learning/s3-webapp/aws"
  name   = var.name
  region = var.region
  prefix = var.prefix
  version = "1.0.1"
  
}
