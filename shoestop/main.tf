provider "aws" {
  region     = "us-west-2"
  access_key = "AKIAQ2TPLKL5NCC2T2LY"
  secret_key = "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"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnet" {
  count = 2
  cidr_block = "10.0.${count.index}.0/24"
  vpc_id     = aws_vpc.my_vpc.id
}

resource "aws_security_group" "allow_all" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "react1" {
  key_name   = "React1"
  public_key = "YOUR_PUBLIC_SSH_KEY"  # Replace with your public SSH key
}

resource "aws_instance" "ec2_instances" {
  count = 2
  ami           = "ami-12345678"  # Replace with a valid AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet[count.index].id
  security_groups = [aws_security_group.allow_all.name]
  key_name      = aws_key_pair.react1.key_name
}

resource "aws_autoscaling_group" "example" {
  desired_capacity = 2
  max_size         = 5
  min_size         = 1

  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  availability_zones = aws_subnet.public_subnet[*].availability_zone
}

resource "aws_launch_template" "example" {
  name_prefix   = "example-"
  image_id      = "ami-12345678"  # Replace with a valid AMI ID
  instance_type = "t2.micro"
  key_name      = aws_key_pair.react1.key_name
  user_data     = <<-EOF
                  #!/bin/bash
                  echo "Hello from User Data!"
                  EOF
}

resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public_subnet[*].id

  enable_deletion_protection = false

  enable_http2 = true

  security_groups = [aws_security_group.allow_all.id]
}

resource "aws_lb_target_group" "example" {
  name     = "example-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
}

resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  default_action {
    target_group_arn = aws_lb_target_group.example.arn
    type             = "forward"
  }
}

resource "aws_cloudwatch_metric_alarm" "example" {
  alarm_name          = "example-ec2-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = []
  dimensions = {
    InstanceId = aws_instance.ec2_instances[count.index].id
  }
}

output "load_balancer_dns_name" {
  value = aws_lb.example.dns_name
}
