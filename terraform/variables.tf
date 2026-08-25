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