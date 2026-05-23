#!/bin/bash
# Destroy inference stack (cleanup)

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

echo "================================"
echo "Inference Stack Cleanup"
echo "================================"
echo ""
echo "⚠️  WARNING: This will destroy all AWS resources created by Terraform."
echo "This includes VPC, EC2 instances, and all associated resources."
echo ""

read -p "Type 'yes' to confirm destruction: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Destruction cancelled."
    exit 0
fi

cd "$TERRAFORM_DIR"

echo ""
echo "Destroying infrastructure..."
terraform destroy -auto-approve

echo ""
echo "✓ Infrastructure destroyed."
