provider "aws" {
  profile = var.profile
  region  = var.aws_region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.21"
    }
  }
}


