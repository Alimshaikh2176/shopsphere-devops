variable "ec2_instance_id" {
  description = "Existing EC2 instance ID"
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "Existing subnet ID"
  type        = string
}

variable "security_group_id" {
  description = "Existing security group ID"
  type        = string
}
