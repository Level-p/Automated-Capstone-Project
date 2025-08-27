locals {
  db_cred = jsondecode(aws_secretsmanager_secret_version.db_cred_version.secret_string)
}

#checkov
resource "null_resource" "checkov_scan" {
  provisioner "local-exec" {
    command     = "./checkov_scan.sh"
    interpreter = ["bash", "-c"]
  }
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f checkov_output.json"
  }
  triggers = {
    always_run = timestamp()
  }
}
output "checkov_scan_status" {
  value = "checkov scan completed check the output.json file for details"
}

#Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "steven-vpc"
  }
}

# This assumes the VPC already exists and is defined in the same workspace
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = true
  tags = {
    Name = "steven-public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-3b"
  map_public_ip_on_launch = true
  tags = {
    Name = "steven-public-subnet-2"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = true
  tags = {
    Name = "steven-private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "eu-west-3b"
  map_public_ip_on_launch = true
  tags = {
    Name = "steven-private-subnet-2"
  }
}
# Create an Internet Gateway
resource "aws_internet_gateway" "igw-steven" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "igw-steven"
  }
}

# Route table for private subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.steven-nat-gw.id
  }

  tags = {
    Name = "steven-pri-rt-1"
  }
}

# Route table for public subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-steven.id
  }

  tags = {
    Name = "steven-public-rt-1"
  }
}

# Route table association for public subnet 1
resource "aws_route_table_association" "pri_assoc-1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "pri_assoc-2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

# Route table association for public subnet 1 and 2
resource "aws_route_table_association" "pub_assoc-1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "pub_assoc-2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Elastic IP
resource "aws_eip" "steven-eip" {
  domain = "vpc"
  tags = {
    Name = "steven-eip"
  }
}

# Create Nat Gateway
resource "aws_nat_gateway" "steven-nat-gw" {
  allocation_id = aws_eip.steven-eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  tags = {
    Name = "steven-NAT"
  }
  depends_on = [aws_internet_gateway.igw-steven]
}

#creating securitygroup
resource "aws_security_group" "steven-ec2_sg" {
  name   = "steven-ec2-sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "Allow ssh inbound traffic"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow https inbound traffic"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow http inbound traffic"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "steven-ec2-sg"
  }
}

resource "aws_security_group" "steven-rds" {
  name   = "steven-rds-sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "Allow https inbound traffic"
    protocol    = "tcp"
    from_port   = 3306
    to_port     = 3306
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "steven-rds-sg"
  }
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "key" {
  content         = tls_private_key.key.private_key_pem
  filename        = "steven-key"
  file_permission = "600"
}
resource "aws_key_pair" "key" {
  key_name   = "steven-pub-key"
  public_key = tls_private_key.key.public_key_openssh
}

# IAM Role for EC2 instances
resource "aws_iam_role" "wordpress_ec2_role" {
  name = "Ste24_WordPressEC2ServiceRole"

  description = "IAM role assumed by EC2 instances in the WordPress image-sharing app for secure resource access."

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project = "WordPressImageSharing"
    Purpose = "EC2InstanceRole"
  }
}



# WordPress EC2 Instance
resource "aws_instance" "wordpress_server" {
  ami                         = var.redhat_ami
  instance_type               = var.instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public_subnet_1.id
  # depends_on                  = [null_resource.checkov_scan]
  vpc_security_group_ids = [
    aws_security_group.steven-ec2_sg.id,
    aws_security_group.steven-rds.id
  ]

  iam_instance_profile = aws_iam_instance_profile.wordpress_instance_profile.name
  key_name             = aws_key_pair.key.id
  user_data            = local.wordpress_script


  # depends_on = [null_resource.pre_scan]

  tags = {
    Name    = "steven-wordpress-server"
    Project = "WordPressImageSharing"
  }
}

# Amazon machine image (AMI) for the backend instance
resource "aws_ami_from_instance" "steven-custom_ami" {
  name                    = "steven-custom-ami"
  source_instance_id      = aws_instance.wordpress_server.id
  snapshot_without_reboot = true
  depends_on              = [aws_instance.wordpress_server, time_sleep.ami-sleep]
}

resource "time_sleep" "ami-sleep" {
  depends_on      = [aws_instance.wordpress_server]
  create_duration = "300s"
}

# Custom Policy with Least Privilege permissions for the role
resource "aws_iam_policy" "wordpress_ec2_policy" {
  name        = "Ste24_WordPressEC2LimitedPolicy1"
  description = "Policy granting EC2 instances access to essential AWS services for WordPress image sharing."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "secretsmanager:GetSecretValue"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach the Policy to the Role
resource "aws_iam_role_policy_attachment" "wordpress_role_policy_attach" {
  role       = aws_iam_role.wordpress_ec2_role.name
  policy_arn = aws_iam_policy.wordpress_ec2_policy.arn

}

# IAM Instance Profile to associate the Role with EC2 instances
resource "aws_iam_instance_profile" "wordpress_instance_profile" {
  name = "Ste24_WordPressInstanceProfile"
  role = aws_iam_role.wordpress_ec2_role.name
}



# #insert secret manager here
resource "aws_secretsmanager_secret" "db_cred1" {
  name        = "db_cred7"
  description = "Database credentials for the WordPress image-sharing application"
}

resource "aws_secretsmanager_secret_version" "db_cred_version" {
  secret_id     = aws_secretsmanager_secret.db_cred1.id
  secret_string = jsonencode(var.dbcred1)
}
#database
# First create a DB Subnet Group
resource "aws_db_subnet_group" "wordpress_db_subnet" {
  name       = "wordpress-db-subnet5"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "wordpress-db-subnet"
  }
}

#Create RDS MySQL Instance
resource "aws_db_instance" "wordpress_db" {
  identifier              = "wordpress-db"
  allocated_storage       = 20
  max_allocated_storage   = 100 #define storage auto scaling
  storage_type            = "gp2"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  username                = local.db_cred.username # DB user
  password                = local.db_cred.password # DB password
  parameter_group_name    = "default.mysql8.0"
  db_subnet_group_name    = aws_db_subnet_group.wordpress_db_subnet.name
  vpc_security_group_ids  = [aws_security_group.steven-rds.id]
  skip_final_snapshot     = true  #Whether to skip the final snapshot before deletion
  deletion_protection     = false #Prevent accidental deletion
  publicly_accessible     = false
  backup_window           = "03:00-04:00" #backups will happen between...
  db_name                 = var.db_name

  tags = {
    Name = "wordpress-db"
  }
}

#application load balancer
resource "aws_lb" "wordpress_alb" {
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.steven-ec2_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  enable_deletion_protection = false

  tags = {
    Name = "wordpress-alb"
  }
}

#application target group
resource "aws_lb_target_group" "wordpress_tg" {
  name     = "wordpress-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    path                = "/indextest.html"
    interval            = 60
    timeout             = 30
    healthy_threshold   = 3
    unhealthy_threshold = 5
    port                = 80
  }

  tags = {
    Name = "wordpress-target-group"
  }
}

# HTTTPS Target Group
resource "aws_lb_target_group" "wordpress-https_tg" {
  name     = "wordpress-https-tg"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    path                = "/indextest.html"
    interval            = 60
    timeout             = 30
    healthy_threshold   = 3
    unhealthy_threshold = 5
    port                = 433
  }

  tags = {
    Name = "wordpress-https-target-group"
  }
}

# Load balancer attachement
resource "aws_lb_target_group_attachment" "lb_attachment_http" {
  target_group_arn = aws_lb_target_group.wordpress_tg.arn
  target_id        = aws_instance.wordpress_server.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "lb_attachment_https" {
  target_group_arn = aws_lb_target_group.wordpress-https_tg.arn
  target_id        = aws_instance.wordpress_server.id
  port             = 443
}

# launch template
resource "aws_launch_template" "steven-launch-template" {
  name_prefix   = "steven-lt"
  image_id      = aws_ami_from_instance.steven-custom_ami.id
  instance_type = "t2.medium"
  key_name      = aws_key_pair.key.id
  iam_instance_profile {
    name = aws_iam_instance_profile.wordpress_instance_profile.id
  }
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.steven-ec2_sg.id]
  }
  user_data = base64encode(local.wordpress_script)
}

#auto scaling policy
resource "aws_autoscaling_policy" "scale_out" {
  name               = "scale-out-policy"
  scaling_adjustment = 1
  adjustment_type    = "ChangeInCapacity"
  cooldown           = 300

  autoscaling_group_name = aws_autoscaling_group.steven-auto-scaling-group.name
}

# Autoscaling group
resource "aws_autoscaling_group" "steven-auto-scaling-group" {
  name                      = "steven-auto-scaling-group"
  desired_capacity          = 2
  max_size                  = 5
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true


  launch_template {
    id      = aws_launch_template.steven-launch-template.id
    version = "$Latest"
  }

  vpc_zone_identifier = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]

  target_group_arns = [aws_lb_target_group.wordpress_tg.arn, aws_lb_target_group.wordpress-https_tg.arn]
}

#insert two target groups. one for http and another for https here

#load balancer listener
resource "aws_lb_listener" "wordpress_listener" {
  load_balancer_arn = aws_lb.wordpress_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
  }
}

# Create a listener for HTTPS
resource "aws_lb_listener" "wordpress-https_listener" {
  load_balancer_arn = aws_lb.wordpress_alb.arn
  port              = 443
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress-https_tg.arn
  }
}
#creat another target group listener for https 

#creat load balancer

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70

  alarm_description   = "Triggers when CPU exceeds 70% utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.steven-auto-scaling-group.name
  }

  alarm_actions = [
    aws_autoscaling_policy.scale_out.arn,
    aws_sns_topic.alert_topic.arn
  ]
}




#create s3 policy for log bucket. Ensure only users/roles from the AWS account can access this bucket.
# resource "aws_s3_bucket_policy" "log-policy" {
#   bucket = aws_s3_bucket.log-bucket.id
#   alarm_description   = "This alarm triggers when CPU exceeds 70%"
#   dimensions = {
#     AutoScalingGroupName = aws_autoscaling_group.steven-auto-scaling-group.name
#   }

#   alarm_actions = [aws_autoscaling_policy.scale_out.arn]
# }



# #create s3 policy for log bucket. Ensure only users/roles from the AWS account can access this bucket.
resource "aws_s3_bucket_policy" "log-policy" {
  bucket = aws_s3_bucket.logs_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "AllowLoggingRoleAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" 
        },
        Action = "s3:*",
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.logs_bucket.id}/*"
        ]
      }
    ]
  })
}

# #create media policy. Anyone on the internet should be able to read/download files.
resource "aws_s3_bucket_policy" "media-policy" {
  bucket = aws_s3_bucket.media-bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "AllowPublicReadForMedia",
        Effect = "Allow",
        Principal = "*",
        Action = "s3:GetObject",
        Resource = "arn:aws:s3:::${aws_s3_bucket.media.id}/*"
      }
    ]
  })
}

# data "aws_caller_identity" "current" {}
#create code policy. Ensure only users/roles from the AWS account can access this bucket.
resource "aws_s3_bucket_policy" "code_policy" {
  bucket = aws_s3_bucket.code-bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "RestrictToOrgRootAccount",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action = "s3:*",
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.code.id}/*"
        ]
      }
    ]
  })
}

# # Bucket 1: For Logs
resource "aws_s3_bucket" "logs_bucket" {
  bucket = "steven-logs-bucket"

  tags = {
    Name        = "steven-logs"
    Environment = "production"
    Purpose     = "log-storage"
  }
}

# # Bucket 2: For Code Storage
resource "aws_s3_bucket" "code-bucket" {
  bucket = "steven-code-bucket"

  tags = {
    Name        = "steven-code"
    Environment = "production"
    Purpose     = "code-storage"
  }
}

# # Bucket 3: For Image Sharing App
resource "aws_s3_bucket" "media-bucket" {
  bucket = "steven-media-bucket"

  tags = {
    Name        = "steven-images"
    Environment = "production"
    Purpose     = "image-storage"
  }
}


#Cloudwatch dashboard
resource "aws_cloudwatch_dashboard" "steven_dashboard" {
  dashboard_name = "steven-Infra-Dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        x    = 0,
        y    = 0,
        width = 6,
        height = 6,
        properties = {
          metrics = [
            [ "AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.steven-auto-scaling-group.name ]
          ],
          period = 300,
          stat   = "Average",
          title  = "CPU Utilization"
        }
      }
    ]
  })
}

# Create SNS Topic
resource "aws_sns_topic" "alert_topic" {
  name = "steven-alert-topic"
}

# Create SNS Subscription (email)
resource "aws_sns_topic_subscription" "alert_email_subscription" {
  topic_arn = aws_sns_topic.alert_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email 
}
#Policy to allow CloudWatch to publish to SNS
resource "aws_sns_topic_policy" "sns_policy" {
  arn    = aws_sns_topic.alert_topic.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        },
        Action = "sns:Publish",
        Resource = aws_sns_topic.alert_topic.arn
      }
    ]
  })
}
# Hosted Zone for Route 53
data "aws_route53_zone" "steven_zone" {
  name = "steven12.space"
  private_zone = false
}

resource "aws_route53_record" "steven_zone_record" {
  zone_id = data.aws_route53_zone.steven_zone.zone_id
  name    = "steven12.space"
  type    = "A"

  alias {
    name                   = aws_lb.wordpress_alb.dns_name
    zone_id                = aws_lb.wordpress_alb.zone_id
    evaluate_target_health = true
  }
}
