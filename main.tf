provider "aws" {
  region = "eu-west-1"
}

 terraform {
   backend "s3" {
     bucket = "52c908b7-d4ed-d907-0586-e77bf9b04a2a-backend"
     key    = "terraform/terrasphere/terraform.tfstate"
     region = "eu-west-1"
   }
 }

provider "template" {
}

locals {
  cloud_config_config = <<-END
    #cloud-config
    ${jsonencode({
  write_files = [
    {
      path        = "/etc/index.html"
      permissions = "0777"
      owner       = "root:root"
      encoding    = "b64"
      content     = filebase64("${path.module}/index.html")
    },
  ]
})}
  END
}

data "cloudinit_config" "example" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    filename     = "index.html"
    content      = local.cloud_config_config
  }

  part {
    content_type = "text/x-shellscript"
    filename     = "example.sh"
    content      = <<-EOF
      #!/bin/bash
      cd /etc/
      nohup busybox httpd -f -p 8080 &
    EOF
  }
}

resource "aws_security_group" "instance" {
  name = "terrasphere-example-one"
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  ami                    = "ami-047bb4163c506cd98"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]
  tags = {
    Name = "Terrasphere-Example"
  }
  user_data = data.cloudinit_config.example.rendered
}

output "instance_ip" {
  value = "${aws_instance.example.*.public_ip}"
}
