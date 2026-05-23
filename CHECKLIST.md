# Pre-Submission Checklist

Use this checklist to verify everything is ready before submitting.

## ✅ Code & Infrastructure

- [ ] All Terraform files created:
  - [ ] `terraform/provider.tf`
  - [ ] `terraform/variables.tf`
  - [ ] `terraform/network.tf`
  - [ ] `terraform/compute.tf`
  - [ ] `terraform/outputs.tf`
  - [ ] `terraform/main.tf`
  - [ ] `terraform/user_data_api.sh`
  - [ ] `terraform/user_data_inference.sh`
  - [ ] `terraform/terraform.tfvars.example`
  - [ ] `terraform/.gitignore`

- [ ] Deployment scripts created:
  - [ ] `scripts/deploy.sh` (executable)
  - [ ] `scripts/cleanup.sh` (executable)

- [ ] Worker code present:
  - [ ] `devops/quickstart/workers/caller-worker/` (TypeScript)
  - [ ] `devops/quickstart/workers/inference-worker/` (Python)

## ✅ Documentation

- [ ] **QUICKSTART.md** - Quick reference guide
- [ ] **DEPLOYMENT.md** - Full deployment guide with:
  - [ ] Architecture diagram
  - [ ] Prerequisites
  - [ ] Step-by-step deployment
  - [ ] Testing instructions
  - [ ] curl command examples
  - [ ] SSH commands
  - [ ] Troubleshooting section

- [ ] **ARCHITECTURE.md** - Detailed architecture with:
  - [ ] System overview
  - [ ] Component descriptions
  - [ ] Network architecture
  - [ ] Data flow diagrams
  - [ ] Security groups explanation
  - [ ] Performance characteristics
  - [ ] Cost model

- [ ] **PRODUCTION.md** - Production readiness with:
  - [ ] Security hardening (encryption, IAM, monitoring)
  - [ ] Scaling for 100x larger model (GPU, async, caching)
  - [ ] Migration path
  - [ ] Production checklist

## ✅ Configuration

- [ ] **terraform/terraform.tfvars.example** - Contains:
  - [ ] Default AWS region (us-east-1)
  - [ ] Network CIDR blocks
  - [ ] Instance types
  - [ ] Example security settings

- [ ] **worker code ready** to deploy:
  - [ ] No hardcoded paths to your machine
  - [ ] No hardcoded IPs
  - [ ] Dependencies in requirements.txt / package.json

## ✅ Terraform Validation

Run these commands to validate:

```bash
cd terraform

# Check syntax
terraform fmt -check *.tf
# Should show: OK (or files needing formatting)

# Validate configuration
terraform validate
# Should show: Success!

# Check for common issues
terraform plan > /tmp/plan.txt 2>&1
# Review for errors
```

- [ ] All `.tf` files formatted correctly
- [ ] `terraform validate` passes
- [ ] No syntax errors in Terraform code

## ✅ GitHub Setup

Before submitting:

- [ ] Initialize git repo:
  ```bash
  cd hiring
  git init
  git config user.name "Your Name"
  git config user.email "your@email.com"
  git add .
  git commit -m "DevOps internship assignment submission"
  git branch -M main
  git remote add origin https://github.com/yourusername/hiring.git
  git push -u origin main
  ```

- [ ] **DO NOT commit**:
  - [ ] `.terraform/` directory
  - [ ] `*.tfstate` files
  - [ ] `*.tfstate.backup` files
  - [ ] `terraform.tfvars` (use example only)
  - [ ] AWS credentials
  - [ ] SSH keys
  - [ ] `.env` files with secrets

- [ ] **.gitignore properly configured**:
  - [ ] Terraform artifacts ignored
  - [ ] State files ignored
  - [ ] Sensitive data ignored

## ✅ Documentation Quality

Review documentation for:

- [ ] **DEPLOYMENT.md**:
  - [ ] Clear prerequisites section
  - [ ] Step-by-step instructions numbered
  - [ ] Expected outputs shown
  - [ ] Curl command with sample request/response
  - [ ] SSH commands provided
  - [ ] Troubleshooting section included
  - [ ] Cost estimation included

- [ ] **ARCHITECTURE.md**:
  - [ ] ASCII diagram of infrastructure
  - [ ] Explanation of each component
  - [ ] Network flow diagrams
  - [ ] Security group rules detailed
  - [ ] Data model documented
  - [ ] Performance characteristics listed

- [ ] **PRODUCTION.md**:
  - [ ] Network security section (VPC, encryption, ACLs)
  - [ ] IAM and secrets management
  - [ ] Monitoring and logging setup
  - [ ] Scaling strategies for 100x model
  - [ ] Cost comparison table
  - [ ] Migration path provided

- [ ] **No typos** in documentation
- [ ] **Links work** (if any internal references)
- [ ] **Code snippets are valid** (can be copy-pasted)
- [ ] **Examples use placeholders** where needed (e.g., `<PUBLIC_IP>`)

## ✅ Testing (If possible)

If you want to verify locally:

```bash
# Terraform syntax check
cd terraform
terraform init
terraform validate
terraform plan

# This should succeed without errors
# (Don't actually run terraform apply unless deploying to AWS)
```

- [ ] Terraform syntax is valid
- [ ] No errors in terraform plan
- [ ] All variables have defaults or examples

## ✅ Assignment Requirements Met

### Deliverables (From Assignment)

- [ ] **Infrastructure-as-Code**
  - [ ] VPC defined in Terraform
  - [ ] Private subnet for inference worker
  - [ ] Public subnet for API gateway
  - [ ] Security groups restrict access correctly
  - [ ] Firewall rules follow least privilege

- [ ] **Deployment Scripts**
  - [ ] Can deploy from scratch
  - [ ] Single command deployment
  - [ ] Scripts are idempotent
  - [ ] Error handling included

- [ ] **Architecture Diagram**
  - [ ] ASCII diagram shows VPC, subnets, VMs
  - [ ] Shows security group rules
  - [ ] Shows RPC flow between workers

- [ ] **README Documentation**
  - [ ] Exact curl command provided
  - [ ] Sample request shown
  - [ ] Sample response shown
  - [ ] Deployment instructions clear
  - [ ] Redeploy steps documented

- [ ] **Production Hardening Writeup**
  - [ ] Network hygiene discussed
  - [ ] Encryption discussed
  - [ ] IAM/secrets discussed
  - [ ] Monitoring discussed
  - [ ] Minimum 3-4 paragraphs

- [ ] **100x Larger Model Writeup**
  - [ ] GPU requirements discussed
  - [ ] Scaling architecture shown
  - [ ] Load balancing approach
  - [ ] Cost implications
  - [ ] Minimum 3-4 paragraphs

### Evaluation Criteria

- [ ] **Correctness**
  - [ ] Architecture allows HTTP → RPC → Inference flow
  - [ ] Workers can communicate via RPC
  - [ ] API returns JSON response

- [ ] **Network Hygiene**
  - [ ] Inference worker NOT reachable from internet
  - [ ] Only API endpoint is public
  - [ ] RPC traffic stays within VPC
  - [ ] Security groups properly configured

- [ ] **Reproducibility**
  - [ ] Can deploy on clean AWS account
  - [ ] All configuration is in Terraform
  - [ ] No manual console steps required
  - [ ] IaC is the source of truth

- [ ] **Clarity**
  - [ ] Someone can follow your instructions
  - [ ] Architecture is understandable
  - [ ] Troubleshooting section helps
  - [ ] No ambiguous steps

## ✅ Final Checks

Before sending:

```bash
# 1. Verify repo structure
ls -la hiring/
# Should show:
# - terraform/
# - scripts/
# - devops/
# - DEPLOYMENT.md
# - ARCHITECTURE.md
# - PRODUCTION.md
# - QUICKSTART.md
# - README.md
# - .gitignore
# - .git/

# 2. Check GitHub is up
git log --oneline -3
# Should show recent commits

# 3. Verify no secrets in repo
git log -p | grep -i "password\|secret\|key" | head -5
# Should return nothing

# 4. Check file counts
find . -name "*.tf" | wc -l
# Should be: 7+ Terraform files

find . -name "*.md" | wc -l
# Should be: 5+ Markdown files

find . -name "*.sh" | wc -l
# Should be: 2+ Shell scripts
```

- [ ] Repo structure is correct
- [ ] All files are committed
- [ ] No secrets in repo history
- [ ] All required files present

## ✅ Submission Ready

Final verification:

- [ ] GitHub repo link is public
- [ ] All documentation is readable (no encoding issues)
- [ ] All Terraform files are present
- [ ] Deployment scripts are executable
- [ ] No sensitive data in any files
- [ ] README explains the project
- [ ] QUICKSTART.md provides quick reference

## 📧 Submission

When ready, email:

**To**: anuran@getalchemystai.com  
**CC**: saumitra@getalchemystai.com, khushi@getalchemystai.com  
**Subject**: `DevOps Internship Assignment — Your Name`

**Body**:
```
Hi team,

I've completed the DevOps internship assignment. Here's my submission:

GitHub Repo: https://github.com/yourusername/hiring
Key Files:
- Terraform IaC: terraform/
- Deployment Scripts: scripts/
- Documentation: DEPLOYMENT.md, ARCHITECTURE.md, PRODUCTION.md

Quick Start:
1. aws configure
2. cd terraform
3. cp terraform.tfvars.example terraform.tfvars
4. vim terraform.tfvars  # Edit allowed_ssh_cidrs
5. ../scripts/deploy.sh

The deployment creates:
- VPC with public/private subnets
- Security-hardened security groups
- API Gateway (TypeScript) in public subnet
- Inference Worker (Python) in private subnet
- Auto-deployment via user-data scripts

All infrastructure is reproducible via Terraform.

Architecture, hardening, and scaling documentation are included.

Best regards,
Your Name
```

---

**Total Items**: 50+  
**Time to Complete**: ~2 hours (with review)  
**Difficulty**: Medium  
**Status**: Ready for submission when all checked

