variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "inference-deployment"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet (API Gateway)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet (Inference Worker)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "api_gateway_instance_type" {
  description = "EC2 instance type for API Gateway"
  type        = string
  default     = "t3.small"
}

variable "inference_instance_type" {
  description = "EC2 instance type for Inference Worker"
  type        = string
  default     = "t3.medium"
}

variable "enable_bastion" {
  description = "Whether to create a bastion host for private subnet access"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # CHANGE THIS to your IP in production!
}

variable "allowed_api_cidrs" {
  description = "CIDR blocks allowed for API access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
