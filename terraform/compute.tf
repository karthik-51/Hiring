# ============================================================
# AMI Data Source (Ubuntu 22.04 LTS)
# ============================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================
# API Gateway Instance (Public Subnet)
# ============================================================

resource "aws_instance" "api_gateway" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.api_gateway_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  
  # User data script to deploy caller-worker
  user_data = base64encode(templatefile("${path.module}/user_data_api.sh", {
    github_repo        = "https://github.com/yourusername/hiring"  # Replace with actual repo
    inference_worker_ip = aws_instance.inference_worker.private_ip
  }))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-api-gw-volume"
    }
  }

  monitoring = true

  tags = {
    Name = "${var.project_name}-api-gateway"
    Role = "APIGateway"
  }

  depends_on = [aws_instance.inference_worker]
}

# ============================================================
# Inference Worker Instance (Private Subnet)
# ============================================================

resource "aws_instance" "inference_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.inference_instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  # User data script to deploy inference-worker
  user_data = base64encode(templatefile("${path.module}/user_data_inference.sh", {
    github_repo = "https://github.com/yourusername/hiring"  # Replace with actual repo
  }))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50  # Larger for model storage
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-inference-volume"
    }
  }

  monitoring = true

  tags = {
    Name = "${var.project_name}-inference-worker"
    Role = "InferenceWorker"
  }
}

# ============================================================
# Bastion Host (Optional - for accessing private instances)
# ============================================================

resource "aws_instance" "bastion" {
  count                  = var.enable_bastion ? 1 : 0
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"  # Minimal instance
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion_sg[0].id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-bastion-volume"
    }
  }

  tags = {
    Name = "${var.project_name}-bastion-host"
    Role = "Bastion"
  }
}
