# Architecture Documentation

## System Design

### Overview
This system implements a distributed inference architecture where:
- **API Gateway** (public-facing TypeScript worker) handles HTTP requests
- **Inference Worker** (private Python worker) runs the AI model
- **RPC Communication** over WebSocket within VPC for inter-worker communication

### Components

#### 1. API Gateway (Caller Worker)
- **Language**: TypeScript
- **Location**: Public subnet (10.0.1.0/24)
- **Instance Type**: t3.small (1 vCPU, 2 GB RAM)
- **Responsibilities**:
  - Listen for HTTP requests on port 3111
  - Parse JSON payload with conversation messages
  - Call inference worker via RPC
  - Format and return JSON response

**Exposed Functions**:
```typescript
// RPC Function - called by inference::run_inference_over_http
inference::get_response(payload) 
  → Calls inference::run_inference
  → Returns wrapped result

// HTTP Trigger - called by external clients
http::run_inference_over_http(payload)
  → Listens on POST /v1/chat/completions
  → Calls inference::get_response
  → Returns HTTP 200 with JSON
```

#### 2. Inference Worker
- **Language**: Python 3.12
- **Location**: Private subnet (10.0.2.0/24)
- **Instance Type**: t3.medium (2 vCPU, 4 GB RAM)
- **Responsibilities**:
  - Load Gemma 3 270M language model
  - Receive RPC calls with message history
  - Process messages through model
  - Return generated text

**Exposed Functions**:
```python
# RPC Function - called by caller-worker via iii framework
inference::run_inference(payload: dict) → str
  - Input: {"messages": [{"role": "user", "content": "..."}]}
  - Output: "Generated response text..."
```

#### 3. iii Framework
- **Purpose**: RPC and HTTP orchestration framework
- **Communication**: WebSocket-based RPC between workers
- **Default Port**: 49134 (for RPC)
- **Configuration**: config.yaml defines workers and their properties

### Network Architecture

```
Internet
   ↓
┌─────────────────────────────┐
│    AWS VPC                  │
│  (10.0.0.0/16)             │
├─────────────────────────────┤
│                             │
│  ┌──────────────────────┐   │  Public Subnet
│  │  API Gateway         │   │  (10.0.1.0/24)
│  │  - Public IP         │   │  Internet Gateway
│  │  - Port 3111 (HTTP)  │   │
│  └─────────┬────────────┘   │
│            │ RPC             │
│            │ (49134)         │
│  ┌─────────▼────────────┐   │  Private Subnet
│  │ Inference Worker     │   │  (10.0.2.0/24)
│  │ - NO Public IP       │   │  NAT Gateway
│  │ - Port 49134 (RPC)   │   │
│  │ - Gemma Model        │   │
│  └──────────────────────┘   │
│                             │
└─────────────────────────────┘
```

### Traffic Flow

#### 1. Inbound HTTP Request
```
Client Machine
    │
    │ HTTP: POST /v1/chat/completions
    │ Body: {"messages": [{"role": "user", "content": "Hello"}]}
    ▼
[Internet] 
    │
    │ Port 3111 allowed by public security group
    ▼
API Gateway (10.0.1.X)
    │
    │ iii framework receives HTTP request
    │ Extracts body and triggers http::run_inference_over_http
    │
    ▼
Caller Worker Code
```

#### 2. RPC Call to Inference Worker
```
Caller Worker
    │
    │ Calls iii.trigger({
    │   function_id: "inference::run_inference",
    │   payload: {"messages": [...]}
    │ })
    │
    ├─ Converts to WebSocket message
    │
    │ ✓ Port 49134 allowed by private security group
    │ ✓ Source: public SG, Destination: private SG
    │
    ▼
[VPC Internal Network]
    │
    ▼
Inference Worker (10.0.2.X)
    │
    │ Receives WebSocket RPC message
    │
    ├─ run_inference_handler() executes
    │  ├─ Load tokenizer and model
    │  ├─ Apply chat template to messages
    │  ├─ Tokenize input text
    │  ├─ Call model.generate()
    │  ├─ Decode output tokens
    │  └─ Return response string
    │
    ▼
Response String: "Hello! How can I help?"
```

#### 3. Response Back to Client
```
Inference Worker
    │
    │ Returns RPC response via WebSocket
    │
    ▼
Caller Worker
    │
    │ Receives response
    │ Wraps in HTTP response format
    │
    {
      "status_code": 200,
      "body": {
        "result": "Hello! How can I help?",
        "success": "Workers connected..."
      },
      "headers": {"Content-Type": "application/json"}
    }
    │
    ▼
[VPC egress → IGW]
    │
    ▼
Client Machine
```

### Security Groups

#### Public SG (API Gateway)
```
INBOUND:
  - Protocol: TCP
    Port: 22 (SSH)
    Source: allowed_ssh_cidrs (default: 0.0.0.0/0)
    Purpose: Administrative access
  
  - Protocol: TCP
    Port: 3111 (HTTP)
    Source: 0.0.0.0/0 (anywhere)
    Purpose: API endpoint access

OUTBOUND:
  - All traffic allowed
```

#### Private SG (Inference Worker)
```
INBOUND:
  - Protocol: TCP
    Port: 49134 (RPC)
    Source: public SG (API Gateway only)
    Purpose: RPC communication with API
  
  - Protocol: TCP
    Port: 22 (SSH)
    Source: bastion SG (if bastion enabled)
    Purpose: Administrative access via bastion

OUTBOUND:
  - All traffic allowed (for downloading model)
```

#### Bastion SG (Optional)
```
INBOUND:
  - Protocol: TCP
    Port: 22 (SSH)
    Source: allowed_ssh_cidrs
    Purpose: SSH access to private instances

OUTBOUND:
  - TCP 22 to 10.0.2.0/24 (private subnet)
  - All other traffic allowed
```

### NAT Gateway

**Purpose**: Enables private subnet instances to reach the internet for:
- Downloading Python packages
- Downloading model weights from HuggingFace
- System updates (apt-get)

**Flow**:
```
Inference Worker (10.0.2.X) wants to download from HuggingFace
    │
    ├─ Packet: Source=10.0.2.X, Dest=hf-cdn.huggingface.co
    │
    ▼
NAT Gateway (in public subnet, Elastic IP)
    │
    ├─ Translates Source to Elastic IP
    │ Translates back on response
    │
    ▼
[Internet]
    │
    ▼
HuggingFace CDN
    │
    ├─ Sees request from Elastic IP
    │ Sends response to Elastic IP
    │
    ▼
NAT Gateway
    │
    ├─ Translates back to 10.0.2.X
    │
    ▼
Inference Worker receives model data
```

### Data Model

#### HTTP Request
```json
{
  "messages": [
    {
      "role": "user",
      "content": "What is AI?"
    },
    {
      "role": "assistant", 
      "content": "AI is Artificial Intelligence..."
    },
    {
      "role": "user",
      "content": "Tell me more"
    }
  ]
}
```

#### RPC Message Format (Internal)
```json
{
  "function_id": "inference::run_inference",
  "payload": {
    "messages": [...]
  }
}
```

#### HTTP Response
```json
{
  "status_code": 200,
  "body": {
    "result": "Generated response from model",
    "success": "You've connected two workers..."
  },
  "headers": {
    "Content-Type": "application/json"
  }
}
```

### Model Pipeline

#### Input Processing
```
Raw Text → Tokenizer → Token IDs → Model Embedding
```

#### Model Generation
```
[BOS Token] + [Input Tokens] 
    → Model Forward Pass (Attention, FFN, etc)
    → Logits (probability distribution over vocabulary)
    → argmax → Next Token ID
    → Repeat until [EOS] or max_tokens reached
```

#### Output Processing
```
Generated Token IDs → Tokenizer Decode → Human Readable Text
```

### Deployment Flow

```
Developer runs: ../scripts/deploy.sh
    │
    ├─ terraform init
    │  └─ Download AWS provider
    │
    ├─ terraform validate
    │  └─ Check syntax
    │
    ├─ terraform plan
    │  └─ Show what will be created
    │
    ├─ User confirms
    │
    ├─ terraform apply
    │  │
    │  ├─ Create VPC (10.0.0.0/16)
    │  │  ├─ Public Subnet (10.0.1.0/24)
    │  │  │  └─ Internet Gateway
    │  │  │  └─ NAT Gateway + Elastic IP
    │  │  └─ Private Subnet (10.0.2.0/24)
    │  │     └─ Route to NAT for internet
    │  │
    │  ├─ Create Security Groups
    │  │  ├─ Public SG (port 22, 3111)
    │  │  ├─ Private SG (port 49134, 22)
    │  │  └─ Bastion SG (optional)
    │  │
    │  ├─ Launch EC2 Instances
    │  │  ├─ API Gateway (public subnet)
    │  │  │  └─ Execute user_data_api.sh
    │  │  │     ├─ Clone repo
    │  │  │     ├─ npm install
    │  │  │     └─ Start caller-worker service
    │  │  │
    │  │  └─ Inference Worker (private subnet)
    │  │     └─ Execute user_data_inference.sh
    │  │        ├─ Clone repo
    │  │        ├─ pip install
    │  │        ├─ Download model
    │  │        └─ Start inference-worker service
    │  │
    │  └─ Output results
    │     ├─ API Endpoint
    │     ├─ Instance IPs
    │     └─ SSH commands
    │
    └─ Deployment complete in ~5-10 minutes

After initialization (2-3 more minutes):
    - Model fully loaded
    - API responds to requests
```

### Performance Characteristics

#### Model: Gemma 3 270M (Q8)
- **Model Size**: ~3 GB (quantized)
- **VRAM Required**: ~4 GB
- **Inference Speed**: 
  - Time to First Token (TTFT): ~0.5-1 second
  - Generation Speed: ~5-10 tokens/second
  - Typical response (100 tokens): ~10-20 seconds

#### System Capacity
- **Max concurrent requests**: 1 (sequential processing on single instance)
- **Latency**: ~15-30 seconds per request (model + network)
- **Throughput**: ~2-4 requests/minute

#### Resource Utilization
- API Gateway: Minimal (just proxying requests)
- Inference Worker: ~90% CPU during inference, ~100% during model loading

### Failover & Reliability

**Current (Single Instance)**:
- Single point of failure
- If inference worker crashes, API returns error
- No automatic restart configured in base setup

**Production Ready**:
- Auto-restart via systemd (configured)
- Bastion host for debugging
- CloudWatch monitoring (recommended)
- Auto-scaling group for multiple workers (scaling section)

### Cost Model

```
Instance Running Cost:
  t3.small: $0.0104/hour = $7.49/month
  t3.medium: $0.0208/hour = $14.98/month
  Total compute: ~$22/month (within free tier first 750h)

Network:
  NAT Gateway: $0.045/hour = $32/month
  But included in free tier for small data transfer
  
Storage:
  20 GB (API): $1.00/month
  50 GB (Inference): $2.50/month
  Total: $3.50/month
  
Total AWS Cost (free tier): ~$0 first 12 months
Total AWS Cost (post free tier): ~$50-60/month
```

---

**Version**: 1.0  
**Last Updated**: May 2026  
**Architecture Diagram**: ASCII diagram included above
