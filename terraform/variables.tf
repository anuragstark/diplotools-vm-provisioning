variable "aws_region" {
  description = "The AWS region to deploy in"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "staging"
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI ID for eu-central-1"
  type        = string
  default     = "ami-0abcdef1234567890" # Example dummy ID
}
