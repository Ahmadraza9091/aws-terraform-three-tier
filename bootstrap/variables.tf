variable "aws_region" {
  description = "AWS region where the Terraform state bucket is created"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
  default     = "terraform-statefile-ahmad-01102026"
}
