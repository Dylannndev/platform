output "vpc_id" {
  value       = aws_vpc.platform_vpc.id
  description = "ID of the platform VPC"
}

output "public_subnet_ids" {
  value       = [aws_subnet.public_az_a.id, aws_subnet.public_az_b.id]
  description = "IDs of the public subnets"
}

output "private_subnet_ids" {
  value       = [aws_subnet.private_az_a.id, aws_subnet.private_az_b.id]
  description = "IDs of the private subnets"
}

output "security_group_id" {
    value = aws_security_group.nat_instance_sg.id
    description = "ID of the security group"
}