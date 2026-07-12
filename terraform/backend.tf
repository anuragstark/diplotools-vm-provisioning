terraform {
  backend "s3" {
    # Replace these with the actual S3 bucket and DynamoDB table you create in AWS!
    bucket         = "diplotools-ironman-terraform-state"
    key            = "vm-provisioning/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "diplotools-ironman"
    encrypt        = true
  }
}
