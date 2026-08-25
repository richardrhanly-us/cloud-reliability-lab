output "vpc_id" {
  description = "ID of the Cloud Reliability Lab VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "web_security_group_id" {
  description = "ID of the web server security group."
  value       = aws_security_group.web.id
}

output "ec2_instance_id" {
  description = "ID of the Cloud Reliability Lab EC2 instance."
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "Public IPv4 address of the Cloud Reliability Lab EC2 instance."
  value       = aws_instance.app.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the Cloud Reliability Lab EC2 instance."
  value       = aws_instance.app.public_dns
}
