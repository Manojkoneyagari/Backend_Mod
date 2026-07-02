data "aws_ami" "myami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.project}/${var.environment}/vpc_id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${var.project}/${var.environment}/private_subnet_ids"
}

data "aws_ssm_parameter" "backend_sg_ids" {
  name = "/${var.component}/${var.project}/${var.environment}/sg_id"
}

data "aws_ssm_parameter" "frontend_sg_ids" {
  name = "/${var.component}/${var.project}/${var.environment}/sg_id"
}

data "aws_ssm_parameter" "backend_alb_listener" {
  name = "${var.project}/${var.environment}/backend_alb_listener"
}

data "aws_ssm_parameter" "frontend_alb_listener" {
  name = "${var.project}/${var.environment}/frontend_alb_listener"
}

data "aws_route53_zone" "backend" {
  name         = "manojkoney.store" # Replace with your registered domain name
  private_zone = false
}


data "aws_key_pair" "deployer" {
  key_name = "deployer-key"
}