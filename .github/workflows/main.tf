provider "aws" {
    region       = "us-east-1"
    access_key   = "AKIAQM2DYDNK2Q4N4PVE"
    secret_key   = "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"
  }

resource "aws_instance" "webapp-1" {
ami                     = "ami-04505e74c0741db8d" 
instance_type           = "t2.micro"
key_name                = "Webapp"
availability_zone       = "us-east-1a"
vpc_security_group_ids  = [aws_security_group.my_sg.id]
depends_on = [aws_db_instance.Demo-mysql-database]
user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y 
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c "echo  1st web server  > /var/www/html/index.html"
EOF

tags = {
    Name = "1st-web-server"
    }
}

resource "aws_instance" "webapp-2" {
ami                     = "ami-04505e74c0741db8d" 
instance_type           = "t2.micro"
key_name                = "Webapp"
availability_zone       = "us-east-1a"
vpc_security_group_ids  = [aws_security_group.my_sg.id]
depends_on = [aws_db_instance.Demo-mysql-database]
user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y 
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c "echo 2nd web server > /var/www/html/index.html"
EOF

tags = {
    Name = "2st-web-server"
    }
}

resource "aws_default_vpc" "my_vpc" {
    tags = {
        Name = "my_vpc_VPC"
    }
}
resource "aws_security_group" "my_sg" {
    name        = "alb"
    description = "Allow inbound traffic"
    vpc_id      = "${aws_default_vpc.my_vpc.id}"
    
ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    ="tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

ingress {
    description = "tomcat port from VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
 
ingress {
    description = "TLC from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
 
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}
 
    tags = {
        Name = "allow_protocol"
    }
}
data "aws_subnet" "aws_subnet" {
    vpc_id = "${aws_default_vpc.my_vpc.id}"
    id     = "subnet-0cd1ffdb6c9668b9f"
}

resource "aws_lb_target_group" "ApplicationLoadBalancerTargetGroup" {
    target_type = "instance"
    vpc_id      = "${aws_default_vpc.my_vpc.id}"
    protocol    = "HTTP"
    port        = 80

health_check {
    enabled             = true
    path                = "/"
    interval            = 30
    protocol            = "HTTP"
    port                = 80
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }
}
    
resource "aws_lb" "my-aws-alb" {
    name            = "webapp-test-alb"
    internal        = false
    subnets         = ["subnet-0cd1ffdb6c9668b9f","subnet-056407cc48d5f588f"]
    security_groups = [
            "${aws_security_group.my_sg.id}"
    ]
    
    tags    = {
    Name    = "appserver-test-alb"
    }
 
    ip_address_type     = "ipv4"
    load_balancer_type  = "application"
}
 
resource "aws_lb_listener" "webapp-test-alb-listner" {
load_balancer_arn        = "${aws_lb.my-aws-alb.arn}"
    port                 = 80 
    protocol             = "HTTP"
    default_action {
    target_group_arn     = "${aws_lb_target_group.ApplicationLoadBalancerTargetGroup.arn}"
    type                 = "forward"
    }
}
 
resource "aws_lb_target_group_attachment" "ec2-attach1" {
    target_group_arn    = aws_lb_target_group.ApplicationLoadBalancerTargetGroup.arn
    target_id           = aws_instance.webapp-1.id
}

resource "aws_lb_target_group_attachment" "ec2-attach2" {
    target_group_arn    = aws_lb_target_group.ApplicationLoadBalancerTargetGroup.arn
    target_id           = aws_instance.webapp-2.id
}

resource "aws_networkfirewall_firewall" "NetworkFirewall" {
  name = "network-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.FirewallPolicy.arn
  vpc_id = "${aws_default_vpc.my_vpc.id}"
  delete_protection = false
  subnet_change_protection = true
  firewall_policy_change_protection = true
  
  subnet_mapping {
    subnet_id = "subnet-056407cc48d5f588f"
  }
}
resource "aws_networkfirewall_firewall_policy" "FirewallPolicy" {
  name = "firewallpolicy"
  

firewall_policy {
  stateless_default_actions = ["aws:pass"]
  stateless_fragment_default_actions = ["aws:drop"]
  stateless_rule_group_reference {
      priority     = 1
      resource_arn = aws_networkfirewall_rule_group.firewallrule.arn
    }
  }

  tags = {
    Tag1 = "statlessrule1"
    Tag2 = "statlessrule2"
  }
}
  
resource "aws_networkfirewall_rule_group" "firewallrule" {
  capacity    = 50
  name        = "firewallrule"
  type        = "STATELESS"
  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        custom_action {
          action_definition {
            publish_metric_action {
              dimension {
                value = "2"
              }
            }
          }
          action_name = "firewallaction"
        }
        stateless_rule {
          priority = 1
          rule_definition {
            actions = ["aws:pass"]
            match_attributes {
              source {
                address_definition = "0.0.0.0/0"
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
            }
          }
        }
      }
    }
  }
   tags = {
    Tag1 = "statlessrule1"
    Tag2 = "statlessrule2"
  }
}
