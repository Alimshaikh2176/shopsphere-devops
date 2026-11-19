output "aws_account_id" {
  value = module.aws_discovery.aws_account_id
}

output "aws_region" {
  value = module.aws_discovery.aws_region
}

output "ec2_instance_id" {
  value = module.aws_discovery.ec2_instance_id
}

output "ec2_instance_type" {
  value = module.aws_discovery.ec2_instance_type
}

output "ec2_public_ip" {
  value = module.aws_discovery.ec2_public_ip
}

output "ec2_private_ip" {
  value = module.aws_discovery.ec2_private_ip
}

output "vpc_id" {
  value = module.aws_discovery.vpc_id
}

output "vpc_cidr" {
  value = module.aws_discovery.vpc_cidr
}

output "subnet_id" {
  value = module.aws_discovery.subnet_id
}

output "subnet_cidr" {
  value = module.aws_discovery.subnet_cidr
}

output "availability_zone" {
  value = module.aws_discovery.availability_zone
}

output "security_group_id" {
  value = module.aws_discovery.security_group_id
}

output "security_group_name" {
  value = module.aws_discovery.security_group_name
}
