
terraform {
  required_version = ">= 1.17.1"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 6.72"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region // no alias is provided so will be used as default

  default_tags {
    tags = {
      Service = var.service_name
      ManagedByTerraform = var.github_url
    }
  }
}
