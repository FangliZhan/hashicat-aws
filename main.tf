terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = var.region
}

resource "aws_vpc" "hashicat-gw" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true

  tags = {
    name = "${var.prefix}-vpc-${var.region}"
    environment = "Demo"
  }
}

resource "aws_subnet" "hashicat-gw" {
  vpc_id     = aws_vpc.hashicat-gw.id
  cidr_block = var.subnet_prefix

  tags = {
    name = "${var.prefix}-subnet"
  }
}

resource "aws_security_group" "hashicat-gw" {
  name = "${var.prefix}-security-group"

  vpc_id = aws_vpc.hashicat-gw.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.prefix}-security-group"
  }
}

resource "aws_internet_gateway" "hashicat-gw" {
  vpc_id = aws_vpc.hashicat-gw.id

  tags = {
    Name = "${var.prefix}-internet-gateway"
  }
}

resource "aws_route_table" "hashicat-gw" {
  vpc_id = aws_vpc.hashicat-gw.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hashicat-gw.id
  }
}

resource "aws_route_table_association" "hashicat-gw" {
  subnet_id      = aws_subnet.hashicat-gw.id
  route_table_id = aws_route_table.hashicat-gw.id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    #values = ["ubuntu/images/hvm-ssd/ubuntu-disco-19.04-amd64-server-*"]
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_eip" "hashicat-gw" {
  instance = aws_instance.hashicat-gw.id
  vpc      = true
}

resource "aws_eip_association" "hashicat-gw" {
  instance_id   = aws_instance.hashicat-gw.id
  allocation_id = aws_eip.hashicat-gw.id
}

resource "aws_instance" "hashicat-gw" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.hashicat-gw.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.hashicat-gw.id
  vpc_security_group_ids      = [aws_security_group.hashicat-gw.id]

  tags = {
    Name = "${var.prefix}-hashicat-gw-instance"
    Department = "bv-demo"
    Billable = "yes"
  }
}

# We're using a little trick here so we can run the provisioner without
# destroying the VM. Do not do this in production.

# If you need ongoing management (Day N) of your virtual machines a tool such
# as Chef or Puppet is a better choice. These tools track the state of
# individual files and can keep them in the correct configuration.

# Here we do the following steps:
# Sync everything in files/ to the remote VM.
# Set up some environment variables for our script.
# Add execute permissions to our scripts.
# Run the deploy_app.sh script.
resource "null_resource" "configure-cat-app" {
  depends_on = [aws_eip_association.hashicat-gw]

  triggers = {
    build_number = timestamp()
  }

  provisioner "file" {
    source      = "files/"
    destination = "/home/ubuntu/"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.hashicat-gw.private_key_pem
      host        = aws_eip.hashicat-gw.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt -y update",
      "sleep 15",
      "sudo apt -y update",
      "sudo apt -y install apache2",
      "sudo systemctl start apache2",
      "sudo chown -R ubuntu:ubuntu /var/www/html",
      "chmod +x *.sh",
      "PLACEHOLDER=${var.placeholder} WIDTH=${var.width} HEIGHT=${var.height} PREFIX=${var.prefix} ./deploy_app.sh",
      "sudo apt -y install cowsay",
      "cowsay Mooooooooooo!",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.hashicat-gw.private_key_pem
      host        = aws_eip.hashicat-gw.public_ip
    }
  }
}

resource "tls_private_key" "hashicat-gw" {
  algorithm = "RSA"
}

locals {
  private_key_filename = "${var.prefix}-ssh-key.pem"
}

resource "aws_key_pair" "hashicat-gw" {
  key_name   = local.private_key_filename
  public_key = tls_private_key.hashicat-gw.public_key_openssh
}
