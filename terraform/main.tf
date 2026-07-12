provider "aws" {
  region = var.aws_region
}

# 1. The ECR Repository for the Docker images
resource "aws_ecr_repository" "app_repo" {
  name                 = "ironman-app-${var.environment}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 2. IAM Role for EC2 so it can use Systems Manager (SSM) and read ECR/SSM parameters
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ironman-ec2-ssm-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "ironman-app-profile-${var.environment}"
  role = aws_iam_role.ec2_ssm_role.name
}

# 3. Security Group (Only HTTP/HTTPS allowed, NO SSH Port 22)
resource "aws_security_group" "app_sg" {
  name        = "ironman-sg-${var.environment}"
  description = "Allow HTTP and HTTPS traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
}

# 4. The EC2 Instance
resource "aws_instance" "app_server" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.app_profile.name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # This reads our cloud-init file from the outer directory!
  user_data = file("${path.module}/../cloud-init/${var.environment}.yml")

  tags = {
    Name = "ironman-app-server-${var.environment}"
    Environment = var.environment
  }
}
