module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  # version = "2.9.0"
  version = "2.15.0"
  
  # insert the 5 required variables here
  bucket_prefix = var.prefix

  tags = {
      Environment = "test"
      Name = "rosezhan"
  }
}
