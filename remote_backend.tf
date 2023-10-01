terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "dcatcher-learning"
    workspaces {
      name = "hashicat-aws"
    }
  }
}
