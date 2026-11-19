variable "aws_region" {
  description = "AWS region for ShopSphere infrastructure"
  type        = string
  default     = "ap-south-1"
}

variable "ec2_instance_id" {
  description = "Existing ShopSphere EC2 instance ID"
  type        = string
  default     = "i-0100f5c58c81a1e24"
}

variable "vpc_id" {
  description = "Existing ShopSphere VPC ID"
  type        = string
  default     = "vpc-0cb7ce642fb7ddbf2"
}

variable "subnet_id" {
  description = "Existing ShopSphere subnet ID"
  type        = string
  default     = "subnet-06836d5f50d7da85e"
}

variable "security_group_id" {
  description = "Existing ShopSphere security group ID"
  type        = string
  default     = "sg-0fd48c3f68750fc44"
}
