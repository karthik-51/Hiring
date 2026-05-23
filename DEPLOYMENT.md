# Distributed Inference Deployment on AWS

A production-ready Infrastructure-as-Code solution for deploying a distributed AI inference system across AWS using Terraform. This deployment spans multiple VMs in a private VPC with an isolated architecture.

## 📋 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS REGION: us-east-1                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           VPC (10.0.0.0/16)                              │   │
│  │                                                           │   │
│  │  ┌─────────────────────────────────────────────────────┐ │   │
│  │  │  Public Subnet (10.0.1.0/24)                        │ │   │
│  │  │                                                      │ │   │
│  │  │  ┌──────────────────────────────────────────────┐   │ │   │
│  │  │  │  API Gateway VM (t3.small)                   │   │ │   │
│  │  │  │  - TypeScript Caller Worker                  │   │ │   │
│  │  │  │  - Public IP: Exposed                        │   │ │   │
│  │  │  │  - Port 3111: HTTP API                       │   │ │   │
│  │  │  │  - Port 22: SSH (restricted)                 │   │ │   │
│  │  │  └──────────────────────────────────────────────┘   │ │   │
│  │  │                                                      │ │   │
│  │  │  [Internet Gateway] ↔ [NAT Gateway]                │ │   │
│  │  └─────────────────────────────────────────────────────┘ │   │
│  │           ↕ (RPC over VPC - Port 49134)                   │   │
│  │  ┌─────────────────────────────────────────────────────┐ │   │
│  │  │  Private Subnet (10.0.2.0/24)                       │ │   │
│  │  │                                                      │ │   │
│  │  │  ┌──────────────────────────────────────────────┐   │ │   │
│  │  │  │  Inference Worker VM (t3.medium)             │   │ │   │
│  │  │  │  - Python Inference Worker                   │   │ │   │
│  │  │  │  - NO public IP (private only)               │   │ │   │
│  │  │  │  - Port 49134: RPC (from API GW only)        │   │ │   │
│  │  │  │  - Port 22: SSH (from Bastion only)          │   │ │   │
│  │  │  │  - Loads Gemma 3 270M model                  │   │ │   │
│  │  │  └──────────────────────────────────────────────┘   │ │   │
│  │  │                                                      │ │   │
│  │  └─────────────────────────────────────────────────────┘ │   │
│  │                                                           │   │
│  │  [Optional: Bastion Host in Public Subnet]              │   │
│  │                                                           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│        SECURITY GROUPS (Firewall)       │
├─────────────────────────────────────────┤
│ Public SG:                              │
│  ✓ SSH 22 (from allowed_ssh_cidrs)    │
│  ✓ HTTP 3111 (from 0.0.0.0/0)         │
│                                         │
│ Private SG:                             │
│  ✓ RPC 49134 (from Public SG only)    │
│  ✓ SSH 22 (from Bastion SG only)      │
│                                         │
│ NAT allows private→internet (outbound) │
└─────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

1. **AWS Account** with free tier credits
   - Sign up: https://aws.amazon.com/free/

2. **Local Tools**
   - Terraform >= 1.0: https://www.terraform.io/downloads
   - AWS CLI: https://aws.amazon.com/cli/
   - Git

### Installation & Deployment

#### Step 1: Configure AWS Credentials
```bash
aws configure
# Enter:
# AWS Access Key ID: [from AWS Console]
# AWS Secret Access Key: [from AWS Console]
# Default region: us-east-1
# Default output format: json
```

#### Step 2: Clone Repository
```bash
git clone https://github.com/yourusername/hiring.git
cd hiring/terraform
```

#### Step 3: Customize Configuration
```bash
# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
vim terraform.tfvars
# Key changes:
#   - allowed_ssh_cidrs: Change to your IP (e.g., "203.0.113.45/32")
#   - Region, instance types, subnet sizes as needed
```

#### Step 4: Deploy Infrastructure
```bash
# Make script executable
chmod +x ../scripts/deploy.sh

# Run deployment
../scripts/deploy.sh
```

The script will:
1. ✅ Initialize Terraform
2. ✅ Validate configuration
3. ✅ Show infrastructure plan
4. ✅ Create resources
5. ✅ Output deployment details

#### Step 5: Wait for Initialization
```bash
# Instances take 2-3 minutes to initialize
# Monitor logs:
aws ec2 describe-instances --region us-east-1
```

### Testing the Deployment

#### Get API Endpoint
```bash
cd terraform
terraform output api_endpoint
# Output: http://<PUBLIC_IP>:3111/v1/chat/completions
```

#### Test API with curl
```bash
curl -X POST http://<PUBLIC_IP>:3111/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {
        "role": "user",
        "content": "What is artificial intelligence?"
      }
    ]
  }'
```

#### Expected Response
```json
{
  "status_code": 200,
  "body": {
    "result": "AI stands for Artificial Intelligence..."
  },
  "headers": {
    "Content-Type": "application/json"
  }
}
```

#### SSH to Instances
```bash
# API Gateway (public)
ssh -i ~/.ssh/id_rsa ubuntu@<PUBLIC_IP>

# Through Bastion (if enabled)
ssh -i ~/.ssh/id_rsa \
  -o ProxyCommand='ssh -i ~/.ssh/id_rsa -W %h:%p ubuntu@<BASTION_IP>' \
  ubuntu@<INFERENCE_PRIVATE_IP>
```

## 📁 Directory Structure

```
terraform/
├── main.tf                    # Main configuration (references others)
├── provider.tf               # AWS provider setup
├── variables.tf              # Input variables
├── network.tf                # VPC, subnets, security groups, IGW
├── compute.tf                # EC2 instances
├── outputs.tf                # Output values
├── user_data_api.sh          # API Gateway initialization script
├── user_data_inference.sh    # Inference Worker initialization script
├── terraform.tfvars.example  # Example variables file
└── .gitignore               # Git ignore patterns

scripts/
├── deploy.sh                 # Main deployment script
└── cleanup.sh               # Destroy infrastructure

devops/quickstart/
├── workers/
│   ├── caller-worker/        # TypeScript API Gateway
│   └── inference-worker/     # Python Inference Worker
├── config.yaml              # iii framework config
└── README.md               # Quickstart documentation
```

## 🔒 Security

### Network Architecture
- **VPC Isolation**: Private subnet completely isolated from internet
- **NAT Gateway**: Private instances can download packages but can't be reached from internet
- **Security Groups**: Firewall rules restrict traffic to minimum necessary
  - API Gateway: Only ports 22 (SSH) and 3111 (API)
  - Inference Worker: Only port 49134 (RPC from API) and 22 (SSH from Bastion)
- **Encryption**: EBS volumes encrypted at rest

### Best Practices Implemented
✅ Instances in isolated subnets  
✅ RPC traffic stays within VPC  
✅ No direct access to inference worker  
✅ Principle of least privilege in security groups  
✅ Enable CloudWatch monitoring  
✅ Bastion host for private access (optional)

### Production Hardening Checklist
- [ ] Restrict `allowed_ssh_cidrs` to your IP only
- [ ] Enable VPC Flow Logs for network monitoring
- [ ] Set up CloudWatch alarms for high CPU/memory
- [ ] Enable AWS CloudTrail for audit logging
- [ ] Use IAM roles instead of hardcoded credentials
- [ ] Implement auto-scaling for inference workers
- [ ] Add Application Load Balancer for API gateway
- [ ] Enable VPC endpoints for S3/ECR (if using private images)
- [ ] Implement rate limiting on API
- [ ] Use AWS Secrets Manager for sensitive config

## 📊 Cost Estimation (AWS Free Tier)

| Resource | Type | Cost |
|----------|------|------|
| API Gateway | t3.small (750 hrs/month) | Free* |
| Inference Worker | t3.medium (750 hrs/month) | Free* |
| NAT Gateway | Data processing | ~$0.06/GB |
| EBS Storage | 70GB gp3 | ~$7/month |
| **Total** | | **~$7/month** |

*Within 12-month AWS free tier. After free tier: ~$30-50/month.

## 🔄 Data Flow

1. **HTTP Request**
   ```
   Client → POST http://PUBLIC_IP:3111/v1/chat/completions
   ```

2. **TypeScript Worker Receives**
   ```
   Caller Worker receives HTTP request
   ↓
   Extracts JSON body with messages
   ↓
   Calls inference::get_response RPC
   ```

3. **RPC Call Over VPC**
   ```
   Caller Worker → WebSocket ws://PRIVATE_IP:49134
   ↓
   Inference Worker receives
   ```

4. **Inference Processing**
   ```
   Python Worker receives messages
   ↓
   Loads Gemma 3 270M model
   ↓
   Applies chat template
   ↓
   Tokenizes input
   ↓
   Runs model.generate()
   ↓
   Decodes output
   ↓
   Returns response string
   ```

5. **Response Flow**
   ```
   Python Worker → RPC response
   ↓
   Caller Worker receives
   ↓
   Wraps in HTTP response
   ↓
   Returns to client as JSON
   ```

## 🛠 Scaling for 100x Larger Model

### Challenge
Gemma 3 270M is small (~3GB). A 27B parameter model would be:
- ~300GB raw size
- ~80-100GB quantized (Q8)
- Requires GPU with 24GB+ VRAM

### Solutions

#### 1. **GPU Instances**
```terraform
# Replace t3.medium with GPU instance
instance_type = "g4dn.xlarge"  # NVIDIA T4 GPU
# Cost: ~$0.35/hour (vs $0.0416/hour for t3.medium)
```

#### 2. **Distributed Inference**
```
Load Balancer
    ↓
  ┌─┴─┐
  ↓   ↓
[Inference-1] [Inference-2] [Inference-N]
  (GPU)          (GPU)          (GPU)
```

#### 3. **Model Optimization**
- Use smaller quantization (Q4 instead of Q8)
- Reduce context length
- Use distilled models
- Implement KV-cache optimization

#### 4. **Add Caching Layer**
```
API Gateway
    ↓
[Redis Cache]  ← Cache frequent queries
    ↓
[Inference Worker Pool]
```

#### 5. **Async Processing**
- Use SQS for request queuing
- Process asynchronously
- Return job ID to client
- Client polls for results

#### 6. **Infrastructure Changes**
```hcl
# Auto-scaling group for inference workers
resource "aws_autoscaling_group" "inference" {
  min_size         = 2
  max_size         = 10
  desired_capacity = 2
  
  launch_template {
    id      = aws_launch_template.inference.id
    version = "$Latest"
  }
}

# Load balancer for API gateway
resource "aws_lb" "api" {
  name               = "inference-api-lb"
  load_balancer_type = "application"
  # ... configuration
}
```

## 📝 Terraform Commands

```bash
cd terraform

# Initialize (first time only)
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# View outputs
terraform output

# Destroy infrastructure
terraform destroy

# Get specific output
terraform output api_endpoint
```

## 🐛 Troubleshooting

### Instances Not Initializing
```bash
# Check initialization script logs
aws ec2-instance-connect open-tunnel \
  --instance-id i-xxxxx \
  --os-user ubuntu

# Inside instance
tail -f /var/log/cloud-init-output.log
```

### API Not Responding
```bash
# SSH to API Gateway
ssh ubuntu@<PUBLIC_IP>

# Check service status
sudo systemctl status caller-worker
sudo journalctl -u caller-worker -f

# Check network connectivity to inference worker
nc -zv 10.0.2.X 49134
```

### Inference Worker Connection Issues
```bash
# SSH via Bastion
# Check service status
sudo systemctl status inference-worker
sudo journalctl -u inference-worker -f

# Check model loading
ps aux | grep python
```

## 📚 Additional Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Detailed architecture explanation
- **[PRODUCTION.md](./PRODUCTION.md)** - Production hardening guide
- **[devops/quickstart/README.md](../devops/quickstart/README.md)** - Worker implementation details

## 📞 Support

For issues or questions:
1. Check CloudWatch logs
2. Review security group rules
3. Verify AWS credentials
4. Check Terraform state: `terraform show`

## 📜 License

Apache 2.0 - See LICENSE file

---

**Deployment Status**: ✅ Ready for AWS  
**Last Updated**: May 2026  
**Terraform Version**: >= 1.0
