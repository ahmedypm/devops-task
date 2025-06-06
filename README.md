# devops-task
 Explanation of Solution

Terraform Fixes:
VPC and Subnets: Added for high availability across two AZs.
RDS Security: Encrypted storage, multi-AZ, and restricted access via security groups.
Load Balancer + ASG: ALB distributes traffic to ECS instances, and ASG ensures scaling across two AZs.
Cost Hygiene: Tagged all resources with `CostCenter` and added an AWS Budget to alert at $100/month.

GitHub Actions Workflow:
- Builds and pushes Docker image to ECR with the commit SHA as the tag.
- Runs Trivy to scan for HIGH/CRITICAL CVEs, failing the build if found.
- Plans Terraform on all branches, applies only on `main`.
- Uses AWS OIDC for secure authentication and pulls secrets from GitHub Secrets.
- Validates secrets locally with `validate_secrets.sh` to prevent runtime failures.

Commit Discipline:
Each major change (VPC, RDS, CloudFront, ALB/ASG, budget) is a separate commit with a clear message explaining the purpose, not just the change.

This solution ensures a secure, scalable, cost-aware ECS deployment with a robust CI/CD pipeline and clear documentation for your README.md.
