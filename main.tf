provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}


resource "aws_subnet" "private_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}


resource "aws_subnet" "private_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
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


resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }
}
resource "aws_db_subnet_group" "private" {
  subnet_ids =  [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

resource "aws_rds_instance" "db" {
  engine            = "mysql"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  username          = "admin"
  password          = "var.db_password"
  db_subnet_group_name = aws_db_subnet_group.private.name
  vpc_security_group_ids = [aws_security_group_rds_sg.id]
  publicly_accessible = false
  skip_final_snapshot  = true
}
resource "aws_ecs_cluster" "my_cluster" {
  name = "my-cluster"
}

resource "aws_ecs_task_definition" "my_task" {
  family                   = "my-task"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"

  container_definitions = <<DEFINITION
  [
    {
      "name": "my-container",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app",
      "memory": 512,
      "cpu": 256,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ]
    }
  ]
  DEFINITION
}

resource "aws_lb" "ecs_alb" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets            = [aws_subnet.public_1.id, : aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "ecs" {
  name     = "ecs-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
}
data "aws_ami"ecs_optimized" {
  most_recent  = true
  owners =["amazon"]
    filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm...etc"]
  }
}
}

resource "aws_launch_template" "ecs" {
  name_prefix  = "ecs-"
  image_id = data.aws_ami.ecs_optimized.id
  instance_type = "t2.micro"

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags,{
      Name = "ECS-Instance"
    })
  }
}

resource "auto_scaling_group" "ecs" {
  name = "ecs-asg"
  max_size        = 3
  min_size        = 1
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }
}

resource "aws_ecs_service" "my_service" {
  name  = "aws_ecs_service"
  cluster = aws_ecs_cluster.my_cluster.id
  task_defination = aws_ecs_task_definition.my_task.arn
  desired_count = 2
  launch_type = "EC2"

  load_balancer{
    target_group_arn = aws_lb_target_group.ecs.arn
    container_name = "my-container"
    container_port = 80
    }
  dentdepends_on = [aws_lb_listener.front_end]

}

resource "aws_s3_bucket" "app_bucket" {
  bucket = "my-app-bucket"
  acl    = "private"
}

resource "aws_budgets_budget" "monthly" {
  name              = "budget-ec2-monthly"
  budget_type       = "COST"
  limit_amount      = "100"
  limit_unit        = "USD"
  time_period_start = "2025-05-15_00:00"
  time_unit         = "MONTHLY"

notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["test@gmail.com"]
  }

resource "aws_instance" "ecs_instance" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  security_groups = [aws_security_group.ecs_sg.name]
}

#varaible
varaible "db_password"{
description = "RDS root password"
 type = string   
 sensitive = true
}

varaible "alert_email"{
description = "email budgetalert"
 type = string   
}