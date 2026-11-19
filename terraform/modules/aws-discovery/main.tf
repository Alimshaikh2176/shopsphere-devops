data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_instance" "shopsphere" {
  instance_id = var.ec2_instance_id
}

data "aws_vpc" "shopsphere" {
  id = var.vpc_id
}

data "aws_subnet" "shopsphere" {
  id = var.subnet_id
}

data "aws_security_group" "shopsphere" {
  id = var.security_group_id
}
