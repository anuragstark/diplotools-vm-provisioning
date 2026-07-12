terraform {
  backend "s3" {
    # Replace these with the actual S3 bucket and DynamoDB table you create in AWS!
    bucket         = "diplotools-ironman-terraform-state"
    key            = "vm-provisioning/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "diplotools-ironman"
    encrypt        = true
  }
}
