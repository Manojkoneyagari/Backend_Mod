locals {

  ami_id = data.aws_ami.myami.id
  frontend_ami = "ami-05cf1e9f73fbad2e2"
  vpc_id = data.aws_ssm_parameter.vpc_id.value


  private_subnet_id = split(",", data.aws_ssm_parameter.private_subnet_ids.value)[0]
  sg_id  = var.component == "frontend" ? [data.aws_ssm_parameter.frontend_sg_ids] : [data.aws_ssm_parameter.backend_sg_ids]
  backend_alb_listener = data.aws_ssm_parameter.backend_alb_listener.arn
  frontend_alb_listener = data.aws_ssm_parameter.frontend_alb_listener.arn
  rule_priority = var.rule_priority


  


  common_tags = {
    Project     = var.project
    Environment = var.environment
    Name        = "${local.common_name}"
    Terraform   = "True"
  }

  common_name = "${var.project}-${var.environment}"
  zone_id = data.aws_route53_zone.backend.zone_id
  domain_name = data.aws_route53_zone.backend.name


}