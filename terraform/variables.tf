variable "aws_region" {
  description = "AWS region used for the Cloud Reliability Lab."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name used to tag Cloud Reliability Lab AWS resources."
  type        = string
  default     = "cloud-reliability-lab"
}

variable "instance_type" {
  description = "EC2 instance type for the Cloud Reliability Lab."
  type        = string
  default     = "t3.micro"
}