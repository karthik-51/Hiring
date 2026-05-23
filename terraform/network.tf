# ============================================================
# VPC and Network Infrastructure
# ============================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ============================================================
# Public Subnet (API Gateway)
# ============================================================

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
    Type = "Public"
  }
}

# ============================================================
# Private Subnet (Inference Worker)
# ============================================================

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-private-subnet"
    Type = "Private"
  }
}

# ============================================================
# Internet Gateway
# ============================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ============================================================
# Elastic IP for NAT Gateway (for private subnet internet access)
# ============================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# ============================================================
# NAT Gateway (allows private subnet to reach internet for downloads)
# ============================================================

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

# ============================================================
# Route Tables
# ============================================================

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# ============================================================
# Route Table Associations
# ============================================================

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ============================================================
# Security Groups
# ============================================================

# Public Security Group (API Gateway)
resource "aws_security_group" "public_sg" {
  name_prefix = "${var.project_name}-public-"
  description = "Security group for public API Gateway"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access"
  }

  # HTTP API endpoint
  ingress {
    from_port   = 3111
    to_port     = 3111
    protocol    = "tcp"
    cidr_blocks = var.allowed_api_cidrs
    description = "API Gateway inference endpoint"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-public-sg"
  }
}

# Private Security Group (Inference Worker)
resource "aws_security_group" "private_sg" {
  name_prefix = "${var.project_name}-private-"
  description = "Security group for private Inference Worker"
  vpc_id      = aws_vpc.main.id

  # RPC from API Gateway only
  ingress {
    from_port       = 49134
    to_port         = 49134
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
    description     = "RPC from API Gateway"
  }

  # SSH from Bastion only (if bastion is enabled)
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = var.enable_bastion ? [aws_security_group.bastion_sg[0].id] : []
    description     = "SSH from Bastion host"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-private-sg"
  }
}

# Bastion Security Group
resource "aws_security_group" "bastion_sg" {
  count           = var.enable_bastion ? 1 : 0
  name_prefix     = "${var.project_name}-bastion-"
  description     = "Security group for Bastion host"
  vpc_id          = aws_vpc.main.id

  # SSH access from internet
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access to Bastion"
  }

  # SSH access to private subnet
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]
    description = "SSH to private instances"
  }

  # Allow all other outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

# ============================================================
# Data Sources
# ============================================================

data "aws_availability_zones" "available" {
  state = "available"
}
