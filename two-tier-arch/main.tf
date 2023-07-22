# --- root/Terraform_projects/terraform_two_tier_architecture/main.tf

# ************************************************************
# Description: two-tier architecture with terraform
# - file name: main.tf
# - custom VPC
# - 2 public subnets in different AZs for high availability
# - 2 private subnets in different AZs
# - RDS MySQL instance (micro)
# - 1 Load balancer
# - 2 EC2 t2.micro instances function = Bastions each in public subnet
# - 2 EC2 t2.micro instances function = Kard-app each in private subnet
# - 1 EC2 t2.micro instance in each public subnet
# - 1 s3 bucket with secure access from Kard-app instances
# - Integrate SSM for ec2 access (bonus task)
# - - 1 IAM role, 1 policy attachment to enable Session Manager
# - - 1 IAM instance profile to be attached to the instance (bastion)
# - - this task security challenges with using the ec2-key/PEM
# ************************************************************

# PROVIDER BLOCK

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.23"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1"
}


# VPC BLOCK

# creating VPC
resource "aws_vpc" "custom_vpc" {
   cidr_block       = var.vpc_cidr

   tags = {
      name = "custom_vpc"
   }
}


# public subnet 1
resource "aws_subnet" "public_subnet1" {   
   vpc_id            = aws_vpc.custom_vpc.id
   cidr_block        = var.public_subnet1
   availability_zone = var.az1

   tags = {
      name = "public_subnet1"
   }
}


# public subnet 2
resource "aws_subnet" "public_subnet2" {  
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = var.public_subnet2
  availability_zone = var.az2

  tags = {
     name = "public_subnet2"
  }
}


# private subnet 1
resource "aws_subnet" "private_subnet1" {   
   vpc_id            = aws_vpc.custom_vpc.id
   cidr_block        = var.private_subnet1
   availability_zone = var.az1

   tags = {
      name = "private_subnet1"
   }
}


# private subnet 2
resource "aws_subnet" "private_subnet2" {   
   vpc_id            = aws_vpc.custom_vpc.id
   cidr_block        = var.private_subnet2
   availability_zone = var.az2

   tags = {
      name = "private_subnet2"
   }
}


# creating internet gateway 
resource "aws_internet_gateway" "igw" {
   vpc_id = aws_vpc.custom_vpc.id

   tags = {
      name = "igw"
   }
}


# creating route table
resource "aws_route_table" "rt" {
   vpc_id = aws_vpc.custom_vpc.id
   route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
      name = "rt"
  }
}


# tags are not allowed here 
# associate route table to the public subnet 1
resource "aws_route_table_association" "public_rt1" {
   subnet_id      = aws_subnet.public_subnet1.id
   route_table_id = aws_route_table.rt.id
}


# tags are not allowed here 
# associate route table to the public subnet 2
resource "aws_route_table_association" "public_rt2" {
   subnet_id      = aws_subnet.public_subnet2.id
   route_table_id = aws_route_table.rt.id
}


# tags are not allowed here 
# associate route table to the private subnet 1
resource "aws_route_table_association" "private_rt1" {
   subnet_id      = aws_subnet.private_subnet1.id
   route_table_id = aws_route_table.rt.id
}


# tags are not allowed here 
# associate route table to the private subnet 2
resource "aws_route_table_association" "private_rt2" {
   subnet_id      = aws_subnet.private_subnet2.id
   route_table_id = aws_route_table.rt.id
}



# SECURITY BLOCK

# create security groups for vpc (bastion_sg), kard-app, and database

# custom vpc security group 
resource "aws_security_group" "bastion_sg" {
   name        = "bastion_sg"
   description = "allow inbound HTTP traffic on port 443 for SSM, no ec2 PEM file, no SSH"
   vpc_id      = aws_vpc.custom_vpc.id

   # HTTP from vpc
   ingress {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]     
   }


  # outbound rules
  # internet access to anywhere
  egress {
     from_port   = 0
     to_port     = 0
     protocol    = "-1"
     cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
     name = "bastion_sg"
  }
}


# App tier security group
resource "aws_security_group" "kard_app_sg" {
  name        = "kard_app_sg"
  description = "allow inbound traffic from ALB"
  vpc_id      = aws_vpc.custom_vpc.id
  
  # allow inbound traffic from bastion only
  ingress {
     from_port       = 0
     to_port         = 65535
     protocol        = "tcp"
     security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
     from_port = "0"
     to_port   = "0"
     protocol  = "-1"
     cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
     name = "kard_app_sg"
  }
}


# database security group
resource "aws_security_group" "database_sg" {
  name        = "database_sg"
  description = "allow inbound traffic from ALB"
  vpc_id      = aws_vpc.custom_vpc.id
   
  # allow traffic from ALB 
  ingress {
     from_port   = 3306
     to_port     = 3306
     protocol    = "tcp"
     security_groups = [aws_security_group.kard_app_sg.id]
  }

  egress {
     from_port   = 32768
     to_port     = 65535
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
     name = "database_sg"
  }
}


### HA Bastion (2 ec2 instances + 2 azs (2 public subnets))
# INSTANCES BLOCK - EC2 and DATABASE

# 1st bastion instance on public subnet 1
resource "aws_instance" "kard_bastion1" {
#  name_prefix            = "kard_bastion"
  ami               = var.ec2_instance_ami
  instance_type          = var.bastion_instance_type
  associate_public_ip_address = "true"
  availability_zone       = var.az1
  subnet_id               = aws_subnet.public_subnet1.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.id

  tags = {
    Name = "kard_bastion1"
  }
}


#resource "aws_autoscaling_group" "kard_bastion" {
#  name                = "kard_bastion"
#  vpc_zone_identifier = tolist("var.public_subnet1")
#  min_size            = 1
#  max_size            = 1
#  desired_capacity    = 1
#
 # launch_template {
 #   id      = aws_launch_template.kard_bastion.id
 #   version = "$Latest"
 # }
#}

#2nd bastion instance on public subnet 2
resource "aws_instance" "kard_bastion2" {
# name_prefix            = "kard_bastion"
  ami               = var.ec2_instance_ami
  instance_type          = var.bastion_instance_type
  associate_public_ip_address = "true"
  availability_zone       = var.az2
  subnet_id               = aws_subnet.public_subnet2.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.id

  tags = {
    Name = "kard_bastion2"
  }
}
# IAM role for ec2 to us SSM
resource "aws_iam_role" "ec2role" {
  name = "ec2roleforssm"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_role_policy_attachment" "ec2policy" {
  role       = aws_iam_role.ec2role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2role.name
}

### HA (2 App instances + 2 azs (2 private subnets)) bastion only access (see attached security_group).
# 1st Kard app instance on private subnet 1
resource "aws_instance" "kard_app_1" {
  ami                     = var.ec2_instance_ami
  instance_type           = var.ec2_instance_type
  availability_zone       = var.az1
  subnet_id               = aws_subnet.private_subnet1.id
  vpc_security_group_ids  = [aws_security_group.kard_app_sg.id] 
  iam_instance_profile = aws_iam_instance_profile.kard_app_profile.id

  tags = {
    name = "kard_app_1"
  }
}
# 2nd Kard app instance on private subnet 2
resource "aws_instance" "kard_app_2" {
  ami                     = var.ec2_instance_ami
  instance_type           = var.ec2_instance_type
  availability_zone       = var.az2
  subnet_id               = aws_subnet.private_subnet2.id
  vpc_security_group_ids  = [aws_security_group.kard_app_sg.id] 
  iam_instance_profile = aws_iam_instance_profile.kard_app_profile.id

  tags = {
    name = "kard_app_2"
  }
}

### Managed RDS database in same VPC setup as private access.
# RDS subnet group
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]

  tags = { 
     name = "rds_subnet_g"
  }
}


# RDS database on mysql engine
resource "aws_db_instance" "kard_db" {
  allocated_storage      = 10
  db_subnet_group_name   = aws_db_subnet_group.default.id
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  multi_az               = false
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.database_sg.id]
}



# ALB BLOCK

# only alpha numeric and hyphen is allowed in name
# alb target group
resource "aws_lb_target_group" "external_target_g" {
  name        = "external-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.custom_vpc.id
}


resource "aws_lb_target_group_attachment" "kard_bastion1_target_g" {
  target_group_arn  = aws_lb_target_group.external_target_g.arn
  target_id         = aws_instance.kard_bastion1.id
  port              = 80
}


resource "aws_lb_target_group_attachment" "kard_bastion2_target_g" {
  target_group_arn  = aws_lb_target_group.external_target_g.arn
  target_id         = aws_instance.kard_bastion2.id
  port              = 80
}


# ALB
resource "aws_lb" "external_alb" {
  name                = "external-ALB"
  internal            = false
  load_balancer_type  = "application"
  security_groups     = [aws_security_group.bastion_sg.id]
  subnets             = [aws_subnet.public_subnet1.id,aws_subnet.public_subnet2.id]
   
  tags = {
      name = "external-ALB"
  }
}


# create ALB listener
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.external_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type              = "forward"
    target_group_arn  = aws_lb_target_group.external_target_g.arn
  }
}
### s3 bucket task
# s3 bucket creation
resource "aws_s3_bucket" "kard_app_bucket" {
  bucket = "kard-app-bucket"
  force_destroy = true
}
# Make the s3 bucket private
resource "aws_s3_bucket_public_access_block" "kard_app_bucket_access" {
  bucket = aws_s3_bucket.kard_app_bucket.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
}
# IAM role for s3 bucket policy
resource "aws_iam_role" "kard_app_bucket_role" {
  name = "kard_app_bucket_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}
# IAM policy for s3 bucket
resource "aws_iam_policy" "bucket_policy" {
  name        = "kard-app-bucket-policy"
  path        = "/"
  description = "Allow "
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        "Resource" : [
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::kard-app-bucket"
        ]
      }
    ]
  })
}
# Attach IAM policy to the IAM role
resource "aws_iam_role_policy_attachment" "kard_app_bucket_policy" {
  role       = aws_iam_role.kard_app_bucket_role.name
  policy_arn = aws_iam_policy.bucket_policy.arn
}
# Create and connect IAM instance profile
resource "aws_iam_instance_profile" "kard_app_profile" {
  name = "kard-app-profile"
  role = aws_iam_role.kard_app_bucket_role.name
}
# OUTPUTS

# get the DNS of the load balancer 

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = "${aws_lb.external_alb.dns_name}"
}

output "db_username" {
  description = "RDS username output set to sensitive to avoid accidental logging"
  value = aws_db_instance.kard_db.username
  sensitive = true
}

output "db_password" {
  description = "RDS password output set to sensitive to avoid accidental logging"
  value = aws_db_instance.kard_db.password
  sensitive = true
}

output "db_connect_string" {
  description = "MyRDS database connection string"
  value       = "server=${aws_db_instance.kard_db.address}; database=ExampleDB; Uid=${var.db_username}; Pwd=${var.db_password}"
  sensitive   = true
}
