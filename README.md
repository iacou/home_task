# Luminor EKS + Atlantis Task

This repository contains Terraform code to provision:

- 1 VPC with 2 subnets
- 1 EKS cluster (with managed node group)
- IAM roles for `eks-admin` and `eks-readonly`
- Atlantis deployed on the cluster using Helm

Atlantis is integrated with GitHub to process Terraform plans and applies via pull requests against /demo directory.

---

## Requirements

- Terraform >= 1.6
- AWS CLI configured
- kubectl and helm installed
- An AWS account with sufficient permissions

---

## Usage

1. Clone this repository.
2. Create a `terraform.tfvars` file in the root directory with the required values:

   ```hcl
   github_owner       = "<your-github-username-or-org>"
   github_repo        = "<your-repo-name>"
   github_user        = "<github-username-for-atlantis>"
   github_token       = "<personal-access-token>"
   github_webhook_secret = "<random-string>"
⚠️ These values are not checked into the repository for security reasons.

Initialize and apply:

bash
Copy code
terraform init
terraform apply
