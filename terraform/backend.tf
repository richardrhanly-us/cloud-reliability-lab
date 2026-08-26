# ============================================================
# Terraform Remote State
# ============================================================

terraform {
  backend "s3" {
    bucket       = "cloud-reliability-lab-tfstate-143838032012"
    key          = "cloud-reliability-lab/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}