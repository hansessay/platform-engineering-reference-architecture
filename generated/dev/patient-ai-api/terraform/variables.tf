variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for EKS worker nodes"
}