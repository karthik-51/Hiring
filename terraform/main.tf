# ============================================================
# Main Terraform Configuration
# This file ties together the infrastructure deployment
# ============================================================

# The actual resources are defined in:
# - provider.tf: AWS provider configuration
# - variables.tf: Input variables
# - network.tf: VPC, subnets, security groups, Internet Gateway
# - compute.tf: EC2 instances
# - outputs.tf: Output values

# No additional resources needed in main.tf as all are modularized
