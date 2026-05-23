#!/bin/bash
# Deploy inference stack to AWS using Terraform

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

echo "================================"
echo "Inference Deployment Script"
echo "================================"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI not installed. Please install it first."
    echo "Visit: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "ERROR: Terraform not installed. Please install it first."
    echo "Visit: https://www.terraform.io/downloads.html"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "ERROR: AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

echo "✓ AWS CLI configured"
echo "✓ Terraform installed"
echo ""

# Navigate to terraform directory
cd "$TERRAFORM_DIR"

echo "Step 1: Initialize Terraform..."
terraform init

echo ""
echo "Step 2: Validate configuration..."
terraform validate

echo ""
echo "Step 3: Create terraform.tfvars from example..."
if [ ! -f terraform.tfvars ]; then
    cp terraform.tfvars.example terraform.tfvars
    echo "Created terraform.tfvars - please review and edit if needed:"
    echo "  - Update allowed_ssh_cidrs with your IP"
    echo "  - Update github_repo URL in compute.tf"
    echo ""
    read -p "Press enter to continue with deployment..."
fi

echo ""
echo "Step 4: Plan infrastructure changes..."
terraform plan -out=tfplan

echo ""
echo "Do you want to apply these changes? (yes/no)"
read -p "Answer: " apply_answer

if [ "$apply_answer" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Step 5: Applying infrastructure..."
terraform apply tfplan

echo ""
echo "✓ Infrastructure deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Wait 2-3 minutes for instances to fully initialize"
echo "2. Get the API endpoint:"
echo "   terraform output api_endpoint"
echo "3. Test the API:"
echo "   curl -X POST http://<api_ip>:3111/v1/chat/completions -H 'Content-Type: application/json' -d '{\"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}]}'"
echo ""
echo "To destroy infrastructure:"
echo "   cd terraform && terraform destroy"
