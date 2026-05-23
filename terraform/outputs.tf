output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID (API Gateway)"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "Private subnet ID (Inference Worker)"
  value       = aws_subnet.private.id
}

output "api_gateway_public_ip" {
  description = "Public IP of API Gateway instance"
  value       = aws_instance.api_gateway.public_ip
}

output "api_gateway_private_ip" {
  description = "Private IP of API Gateway instance"
  value       = aws_instance.api_gateway.private_ip
}

output "inference_worker_private_ip" {
  description = "Private IP of Inference Worker instance"
  value       = aws_instance.inference_worker.private_ip
}

output "api_endpoint" {
  description = "API endpoint URL"
  value       = "http://${aws_instance.api_gateway.public_ip}:3111/v1/chat/completions"
}

output "bastion_public_ip" {
  description = "Public IP of Bastion host (if enabled)"
  value       = var.enable_bastion ? aws_instance.bastion[0].public_ip : "N/A"
}

output "bastion_ssh_command" {
  description = "SSH command to connect to Bastion"
  value       = var.enable_bastion ? "ssh -i /path/to/key.pem ubuntu@${aws_instance.bastion[0].public_ip}" : "N/A"
}

output "api_gateway_ssh_command" {
  description = "SSH command to connect to API Gateway"
  value       = "ssh -i /path/to/key.pem ubuntu@${aws_instance.api_gateway.public_ip}"
}

output "inference_worker_ssh_via_bastion" {
  description = "SSH to Inference Worker through Bastion"
  value       = var.enable_bastion ? "ssh -i /path/to/key.pem -o ProxyCommand='ssh -i /path/to/key.pem -W %h:%p ubuntu@${aws_instance.bastion[0].public_ip}' ubuntu@${aws_instance.inference_worker.private_ip}" : "Not available without bastion"
}

output "deployment_info" {
  description = "Deployment information summary"
  value = {
    api_gateway_public_ip  = aws_instance.api_gateway.public_ip
    inference_worker_ip    = aws_instance.inference_worker.private_ip
    api_endpoint           = "http://${aws_instance.api_gateway.public_ip}:3111/v1/chat/completions"
    vpc_cidr               = var.vpc_cidr
    public_subnet_cidr     = var.public_subnet_cidr
    private_subnet_cidr    = var.private_subnet_cidr
  }
}
