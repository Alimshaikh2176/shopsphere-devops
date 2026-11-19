output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  value = data.aws_region.current.region
}

output "ec2_instance_id" {
  value = data.aws_instance.shopsphere.id
}

output "ec2_instance_type" {
  value = data.aws_instance.shopsphere.instance_type
}

output "ec2_public_ip" {
  value = data.aws_instance.shopsphere.public_ip
}

output "ec2_private_ip" {
  value = data.aws_instance.shopsphere.private_ip
}

output "vpc_id" {
  value = data.aws_vpc.shopsphere.id
}

output "vpc_cidr" {
  value = data.aws_vpc.shopsphere.cidr_block
}

output "subnet_id" {
  value = data.aws_subnet.shopsphere.id
}

output "subnet_cidr" {
  value = data.aws_subnet.shopsphere.cidr_block
}

output "availability_zone" {
  value = data.aws_subnet.shopsphere.availability_zone
}

output "security_group_id" {
  value = data.aws_security_group.shopsphere.id
}

output "security_group_name" {
  value = data.aws_security_group.shopsphere.name
}
