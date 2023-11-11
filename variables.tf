variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "us-east-1"
}

variable "env_name" {
  default     = "hello-lambda-"
  description = "Terraform environment name"
}

variable "env_name_destination" {
  default     = "hello_lambda_destination"
  description = "Terraform environment name"
}

variable "env_bucket_name" {
  default     = "hello-bucket-teste"
  description = "Terraform environment name"
}