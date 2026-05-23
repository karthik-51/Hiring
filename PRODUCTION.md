# Production Hardening & Scaling Guide

## 🔒 Production Hardening

### 1. Network Security

#### Restrict SSH Access
```hcl
# Before (INSECURE):
allowed_ssh_cidrs = ["0.0.0.0/0"]

# After (SECURE):
allowed_ssh_cidrs = ["203.0.113.45/32"]  # Your IP only
```

#### Enable VPC Flow Logs
```hcl
resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.flowlogs.arn
  log_destination = aws_cloudwatch_log_group.flowlogs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}
```

**Why**: Capture all network traffic for auditing, debugging, and security analysis

#### VPC Endpoints for AWS Services
```hcl
# For S3 access without NAT (cheaper)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  
  route_table_ids = [
    aws_route_table.private.id,
    aws_route_table.public.id
  ]
}
```

**Why**: Avoid NAT charges, enhance security by not routing through internet

### 2. Encryption

#### Enable EBS Encryption by Default
```hcl
# Already implemented in compute.tf:
encrypted = true
```

#### Enable S3 Encryption (if using S3 for models)
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "models" {
  bucket = aws_s3_bucket.models.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

#### TLS for API Endpoint
```hcl
# Replace plain HTTP with HTTPS
resource "aws_acm_certificate" "main" {
  domain_name       = var.api_domain
  validation_method = "DNS"
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.main.arn
}
```

### 3. IAM & Access Control

#### Use IAM Roles (Don't use Access Keys)
```hcl
resource "aws_iam_role" "ec2_role" {
  name = "inference-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach to instance profile
resource "aws_iam_instance_profile" "ec2" {
  name = "inference-instance-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "api_gateway" {
  iam_instance_profile = aws_iam_instance_profile.ec2.name
  # ...
}
```

**Benefits**:
- No hardcoded credentials on instances
- Temporary credentials that rotate automatically
- Fine-grained permission control

#### Minimal IAM Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-models",
        "arn:aws:s3:::my-models/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

**Principle**: Grant only necessary permissions

### 4. Monitoring & Logging

#### CloudWatch Metrics
```hcl
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "inference-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.inference_worker.id
  }
}
```

#### CloudWatch Logs
```bash
# Inside instance (user_data):
sudo aws logs create-log-group --log-group-name /inference/worker
sudo systemctl enable aws-cloudwatch-agent
```

#### CloudTrail for Audit Logging
```hcl
resource "aws_cloudtrail" "main" {
  name           = "inference-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail.id
  
  depends_on = [aws_s3_bucket_policy.cloudtrail]

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}
```

**Why**: Track all API calls to AWS resources

### 5. Secrets Management

#### Use AWS Secrets Manager (Not Environment Variables)
```hcl
resource "aws_secretsmanager_secret" "model_token" {
  name = "inference/huggingface-token"
}

resource "aws_secretsmanager_secret_version" "model_token" {
  secret_id     = aws_secretsmanager_secret.model_token.id
  secret_string = var.huggingface_token
}
```

**In application**:
```python
import boto3
secrets = boto3.client('secretsmanager')
response = secrets.get_secret_value(SecretId='inference/huggingface-token')
token = response['SecretString']
```

### 6. Compliance & Auditing

#### Security Group Audit
```bash
# Review all rules regularly
aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupId, GroupName, IpPermissions[*]]'
```

#### Network ACLs (Additional Layer)
```hcl
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private.id]

  # Allow RPC from public subnet
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.public_subnet_cidr
    from_port  = 49134
    to_port    = 49134
  }

  # Deny everything else inbound
  ingress {
    protocol   = "-1"
    rule_no    = 32767
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }
}
```

---

## 📈 Scaling for 100x Larger Model

### Current Bottleneck: Model Size
- Gemma 3 270M: 3 GB, ~0.5s TTFT, ~10 tokens/sec
- Gemma 3 27B (100x): 300GB raw, ~80GB quantized, needs GPU, ~2s TTFT

### Scaling Strategy 1: Multi-GPU Inference

#### Hardware Upgrade
```hcl
# Change instance type
inference_instance_type = "g4dn.12xlarge"  # 4x NVIDIA T4 GPUs, 48 GB GPU memory

# Or use more cost-efficient option
inference_instance_type = "g5.24xlarge"    # 4x NVIDIA L40 GPUs
```

#### Model Sharding (Multiple GPUs)
```python
import torch
from transformers import AutoModelForCausalLM

# Load on multiple GPUs
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-2-70b",
    device_map="auto",  # Automatically shard across GPUs
    offload_folder="./offload"
)
```

#### Inference Optimization
```python
# Use vLLM for better throughput
from vllm import LLM, SamplingParams

llm = LLM(
    model="meta-llama/Llama-2-70b",
    tensor_parallel_size=4,  # Shard across 4 GPUs
    dtype=torch.float16,
    max_num_seqs=32  # Batch multiple requests
)

outputs = llm.generate(prompts, sampling_params)
```

### Scaling Strategy 2: Distributed Inference

#### Load Balancer
```hcl
resource "aws_lb" "inference" {
  name               = "inference-lb"
  internal           = true  # Only accessible within VPC
  load_balancer_type = "network"
  
  subnets = [aws_subnet.private.id]
}

resource "aws_lb_target_group" "inference" {
  name     = "inference-targets"
  port     = 49134
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
}
```

#### Auto-Scaling Group
```hcl
resource "aws_launch_template" "inference" {
  name_prefix   = "inference-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "g4dn.xlarge"
  user_data     = base64encode(file("user_data_inference.sh"))
}

resource "aws_autoscaling_group" "inference" {
  name                = "inference-asg"
  vpc_zone_identifier = [aws_subnet.private.id]
  min_size            = 2
  max_size            = 10
  desired_capacity    = 3
  
  launch_template {
    id      = aws_launch_template.inference.id
    version = "$Latest"
  }
  
  health_check_type          = "ELB"
  health_check_grace_period  = 300
  
  tag {
    key                 = "Name"
    value               = "inference-worker"
    propagate_launch_template = true
  }
}
```

#### Inference Mesh Architecture
```
                    API Gateway
                         │
                         ▼
                 [Load Balancer]
                    │    │    │
        ┌───────────┼────┼────┼────────────┐
        ▼           ▼    ▼    ▼            ▼
   [Worker-1]  [Worker-2] [Worker-3]  [Worker-N]
   (g4dn.xlarge)
   - GPU Optimized
   - Model replicated
   - Can handle 32 concurrent requests
```

### Scaling Strategy 3: Async Processing

Replace synchronous processing with queue-based architecture:

```python
# Before (sync)
result = inference_worker.run_inference(messages)
return result

# After (async)
job_id = queue.push(messages)
return {"job_id": job_id, "status": "queued"}

# Client polls:
GET /v1/chat/completions/{job_id}
# Returns:
{"status": "processing"} or {"status": "done", "result": "..."}
```

#### Implementation
```hcl
resource "aws_sqs_queue" "inference_jobs" {
  name                      = "inference-jobs"
  message_retention_seconds = 3600
  visibility_timeout_seconds = 1800  # 30 minutes for long inference
}

resource "aws_dynamodb_table" "job_results" {
  name           = "inference-results"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "job_id"
  
  attribute {
    name = "job_id"
    type = "S"
  }
  
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}
```

**Python Worker**:
```python
import boto3
import uuid

sqs = boto3.client('sqs')
dynamodb = boto3.resource('dynamodb')

def process_job():
    messages = sqs.receive_message(
        QueueUrl=QUEUE_URL,
        MaxNumberOfMessages=1,
        WaitTimeSeconds=20
    )
    
    if 'Messages' not in messages:
        return
    
    job_id = messages['Messages'][0]['Body']
    
    # Run inference
    result = run_inference(...)
    
    # Store result
    table = dynamodb.Table('inference-results')
    table.put_item(Item={
        'job_id': job_id,
        'result': result,
        'expires_at': int(time.time()) + 3600
    })
    
    # Delete from queue
    sqs.delete_message(
        QueueUrl=QUEUE_URL,
        ReceiptHandle=messages['Messages'][0]['ReceiptHandle']
    )
```

### Scaling Strategy 4: Caching

#### Redis Cache for Common Queries
```hcl
resource "aws_elasticache_cluster" "inference" {
  cluster_id           = "inference-cache"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis6.x"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "inference-cache-subnet"
  subnet_ids = [aws_subnet.private.id]
}
```

**Implementation**:
```python
import redis
import hashlib
import json

cache = redis.Redis(host='cache-endpoint', port=6379, decode_responses=True)

def get_response(messages):
    # Create cache key from messages
    key = f"inference:{hashlib.md5(json.dumps(messages).encode()).hexdigest()}"
    
    # Check cache
    cached = cache.get(key)
    if cached:
        return json.loads(cached)
    
    # Run inference
    result = run_inference(messages)
    
    # Cache result (1 hour TTL)
    cache.setex(key, 3600, json.dumps(result))
    
    return result
```

### Scaling Strategy 5: Model Pruning & Distillation

#### Quantization (Already using Q8)
```python
# Further quantize to Q4 (2x size reduction, slight quality loss)
from transformers import AutoModelForCausalLM, BitsAndBytesConfig

quantization_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_compute_dtype=torch.float16
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-2-70b",
    quantization_config=quantization_config
)
```

#### Knowledge Distillation
```python
# Train smaller model to mimic larger model
# Results in ~70% size reduction with ~90% performance

# Use distilled model instead:
# Instead of Llama 2 70B → use Llama 2 7B
# Or: Instead of Mistral 7B → use MiniLM or DistilBERT
```

#### LoRA Fine-tuning
```python
# Reduce trainable parameters to specific layers
from peft import LoraConfig, get_peft_model

lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "v_proj"],
    lora_dropout=0.05
)

model = get_peft_model(model, lora_config)
# Now only 1-5% of parameters are trainable
```

### Scaling Cost Comparison

```
Scenario 1: Single Instance (Current)
  Infrastructure: 1x t3.medium
  Monthly Cost: ~$15 (compute in free tier)
  Max Throughput: 4 req/min
  Latency: 15-30s per request

Scenario 2: GPU + Auto-scaling (100x model)
  Infrastructure: 3x g4dn.xlarge + load balancer
  Monthly Cost: ~$500-800
  Max Throughput: 100+ req/min
  Latency: 2-5s per request

Scenario 3: Full Stack (Production)
  Infrastructure: 5x g4dn.xlarge + LB + Cache + Queue
  Monthly Cost: ~$1500-2000
  Max Throughput: 1000+ req/min
  Latency: <1s cached, 2-5s fresh
```

### Migration Path (Incremental)

```
Week 1: Single GPU + Async
  - Switch to g4dn.xlarge (1x GPU)
  - Implement SQS queue
  - Result: 20% latency improvement

Week 2: Caching Layer
  - Add Redis cache
  - Cache common queries
  - Result: 30% faster for repeated queries

Week 3: Multi-GPU
  - Scale to 3-5 GPU workers
  - Implement load balancing
  - Result: 3-5x throughput

Week 4: Optimization
  - Quantize further (Q4)
  - Optimize batch size
  - Profile and tune
  - Result: 2x latency improvement
```

---

## Summary

**Production Checklist**:
- ✅ Encryption enabled (EBS, S3, TLS)
- ✅ VPC Flow Logs enabled
- ✅ CloudWatch monitoring configured
- ✅ CloudTrail audit logging enabled
- ✅ IAM roles (no hardcoded credentials)
- ✅ Secrets Manager for sensitive data
- ✅ Network ACLs for defense-in-depth
- ✅ SSH restricted to known IPs
- ✅ Auto-recovery enabled (systemd restart)
- ✅ Load balancer for HA (if scaling)
- ✅ Auto-scaling configured (if scaling)
- ✅ Backup strategy (if production)

**Scaling Decision Tree**:
```
Need to scale?
├─ Yes, same model
│  └─ Add load balancer + auto-scaling group
├─ Yes, larger model
│  ├─ GPU instances + vLLM
│  ├─ Multiple GPUs per instance
│  └─ Inference sharding
└─ Yes, minimize cost
   ├─ Implement caching (Redis)
   ├─ Async processing (SQS)
   └─ Use distilled/pruned models
```

---

**Version**: 1.0  
**Last Updated**: May 2026  
**Audience**: DevOps Engineers, Platform Teams
