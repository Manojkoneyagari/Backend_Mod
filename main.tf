resource "aws_instance" "main" {
  ami                    = var.component == "frontend" ? local.frontend_ami : local.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [local.sg_id]
  subnet_id              = local.private_subnet_id
  #key_name = aws_key_pair.deployer.key_name
  key_name = data.aws_key_pair.deployer.key_name



  tags = merge(
    local.common_tags, {
      Name = "${var.project}-${var.environment}-${var.component}"
    }
  )
}

resource "terraform_data" "main" {
  triggers_replace = [
    aws_instance.main.id
  ]
  connection {
    type        = "ssh"
    host        = aws_instance.main.private_ip
    user        = "ubuntu"
    private_key = file("/home/ubuntu/.ssh/id_rsa")
    host_key = null
  }

  provisioner "file" {
    source      = "ansiblescript.sh"
    destination = "/tmp/ansiblescript.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/ansiblescript.sh",
      "sudo sh /tmp/ansiblescript.sh ${var.component}"
    ]
  }

}
/* 
  resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/id_rsa.pub")
  #public_key = file(var.pub_key_path)
}
 */

 resource "aws_ec2_instance_state" "main" {
  instance_id = aws_instance.main.id
  state       = "stopped"
  depends_on = [ terraform_data.main]
}


resource "aws_ami_from_instance" "main" {
  name               = "${local.common_name}-${var.component}-${aws_instance.main.id}"
  source_instance_id = aws_instance.main.id
  depends_on = [ aws_ec2_instance_state.main ]

  tags = merge(
    local.common_tags, {
      Name = "${local.common_name}-${var.component}-${aws_instance.main.id}",
      purpose = "ami"
    }
  )
}



resource "aws_launch_template" "main" {
  name = "${var.project}-${var.environment}-${var.component}"

  image_id = aws_ami_from_instance.main.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t3.micro"
  key_name = data.aws_key_pair.deployer.key_name
  update_default_version = true 

  vpc_security_group_ids = [local.sg_id]

  tag_specifications {
    resource_type = "instance"

    tags =merge(
    local.common_tags, {
      Name = "${local.common_name}-${var.component}-${aws_instance.main.id}",
      purpose = "launch_template"
    }
  )
}
}

resource "aws_lb_target_group" "main" {
  name        = "${var.project}-${var.environment}-${var.component}"
  port        = var.component == "frontend" ? 80 : 8080
  protocol    = "HTTP"
  target_type = "instance"  #by default it is instance, you can mention "ip" it means it targets only ip address
  vpc_id      = local.vpc_id
  deregistration_delay = 30

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    path = "/health"
    port = 8080
    protocol = "HTTP"
    interval = 20
    timeout = 5
    matcher = "200-299"

  }
}

resource "aws_autoscaling_group" "main" {
  name                      = "${var.project}-${var.environment}-${var.component}"
  max_size                  = 5
  min_size                  = 1
  health_check_grace_period = 120   #how long the Auto Scaling Group waits before checking the health of a newly launched instance.
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
  vpc_zone_identifier       = [local.private_subnet_id]
  target_group_arns = [aws_lb_target_group.main.arn] # Autoscaling launches into specific target group


  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }

    triggers = ["launch_template"]
  }


  tag {
    key                 = "Name"
    value               = "${var.project}-${var.environment}-${var.component}"
    propagate_at_launch = true
  }


 # with in 15min autoscaling should be successful to launch instances
  timeouts {
    delete = "15m"
  }
}

resource "aws_autoscaling_policy" "main" {
  autoscaling_group_name = aws_autoscaling_group.main.name
  name                   = "${var.project}-${var.environment}-${var.component}"
  adjustment_type        = "TargetTrackingScaling"
  estimated_instance_warmup = 120
   target_tracking_configuration {
      predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 75.0
   }
   }
  

resource "aws_lb_listener_rule" "main" {
  listener_arn = var.component == "frontend" ? local.frontend_alb_listener : local.backend_alb_listener
  priority     = local.rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }


  condition {
    host_header {
      #values = ["${var.component}.backend_alb.${local.domain_name}"]
      values = var.component == "frontend" ? ["${var.project}.${local.domain_name}"] : ["${var.component}.backend_alb.${local.domain_name}"]
    }
  }
}