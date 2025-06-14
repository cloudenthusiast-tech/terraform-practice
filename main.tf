provider "aws" {
  region = "us-east-1"

}

resource "aws_vpc" "customvpc" {
  cidr_block = "192.0.0.0/16"

}
resource "aws_internet_gateway" "myigw" {
vpc_id = var.aws_vpc.id

}

resource "aws_subnet" "sub1" {
  availability_zone       = "us-east-1a"
  cidr_block              = "192.0.1.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.customvpc.id

}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.customvpc.id
  availability_zone       = "us-east-1b"
  cidr_block              = "192.0.2.0/24"
  map_public_ip_on_launch = true

}
resource "aws_network_acl" "firstnacl" {
    vpc_id = aws_vpc.customvpc.id

}


resource "aws_network_acl_rule" "inboundhttp" {
    network_acl_id = aws_network_acl.firstnacl.id
    rule_number = 100
    egress = false
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_block = "0.0.0.0/0"
    rule_action = "allow"
  
}

resource "aws_network_acl_rule" "inboundssh" {
  network_acl_id = aws_network_acl.firstnacl.id
  rule_number = 120
  egress = false
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_block = "0.0.0.0/0"
  rule_action = "allow"
}

resource "aws_network_acl_rule" "remaining-ports" {
    network_acl_id = aws_network_acl.firstnacl.id
    rule_number = 130
    from_port = 1024
    to_port = 65535
    cidr_block = "0.0.0.0/0"
    egress = false
    rule_action = "allow"
    protocol = "tcp"
  
}


resource "aws_network_acl_rule" "outbounthttp" {
  network_acl_id = aws_network_acl.firstnacl.id
  egress = true
  rule_action = "allow"
  rule_number = 100
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_block = "0.0.0.0/0"

}

resource "aws_network_acl_rule" "outboundssh" {
  network_acl_id = aws_network_acl.firstnacl.id
  egress = true
  rule_action = "allow"
  rule_number = 110
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_block = "0.0.0.0/0"
}


resource "aws_network_acl_rule" "outbount-al-ports" {
  network_acl_id = aws_network_acl.firstnacl.id
  egress = true
  rule_action = "allow"
  rule_number = 120
  from_port = 1024
  to_port = 65535
  protocol = "tcp"
  cidr_block = "0.0.0.0/0"
}

resource "aws_network_acl_association" "first-association" {
    network_acl_id = aws_network_acl.firstnacl.id
    subnet_id = aws_subnet.sub1.id
}

resource "aws_network_acl_association" "second-association" {
    network_acl_id = aws_network_acl.firstnacl.id
    subnet_id = aws_subnet.sub2.id
}





resource "aws_route_table" "myrt" {
  vpc_id = aws_vpc.customvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id

  }
}

resource "aws_route_table_association" "myrta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.myrt.id

}

resource "aws_route_table_association" "myrta2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.myrt.id
}

resource "aws_security_group" "sg" {
  name   = "websg"
  vpc_id = aws_vpc.customvpc.id


  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {

    description = "ssh"
    from_port   = 22
    to_port     = 22
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
    name = "sgtag"
  }
}

resource "aws_instance" "my_1st_instance" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.sub1.id
  vpc_security_group_ids = [aws_security_group.sg.id]
  iam_instance_profile = aws_iam_instance_profile.iamprofile.name
  depends_on = [ aws_iam_role_policy.s3policy ]
  user_data = base64encode(file("userdata.sh"))

}

resource "aws_instance" "my_2nd_instance" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.sub2.id
  vpc_security_group_ids = [aws_security_group.sg.id]
  iam_instance_profile = aws_iam_instance_profile.iamprofile.name
  depends_on = [ aws_iam_role_policy.s3policy ]
  user_data = base64encode(file("userdata1.sh"))

}

resource "aws_iam_role" "ec2role" {
  name = "s3role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
  


resource "aws_iam_instance_profile" "iamprofile" {
  role = aws_iam_role.ec2role.id
  
}

resource "aws_iam_role_policy" "s3policy" {
  name = "s3-policy"
  role = aws_iam_role.ec2role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:*"
        Resource = "*"
      }
    ]
  })

  depends_on = [aws_s3_bucket.rolebucket]
}



resource "aws_s3_bucket" "rolebucket" {
  bucket = "nanonacho-v1-9618-prod"
  
  
}


resource "aws_lb" "mylb" {
  load_balancer_type = "application"
  internal           = false
  name               = "apllilb"

  security_groups = [aws_security_group.sg.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id]

}

resource "aws_lb_target_group" "lbtarget" {
  port     = 80
  protocol = "HTTP"
  name     = "mytarget"
  vpc_id   = aws_vpc.customvpc.id

  health_check {
    port = "traffic-port"
    path = "/"
  }

}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.lbtarget.arn
  target_id        = aws_instance.my_1st_instance.id

}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.lbtarget.arn
  target_id        = aws_instance.my_2nd_instance.id

}

resource "aws_lb_listener" "listener" {
  port              = 80
  load_balancer_arn = aws_lb.mylb.arn
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.lbtarget.arn
    type             = "forward"
  }
}
output "lb_dns" {
  value = aws_lb.mylb.dns_name

}
