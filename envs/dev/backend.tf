terraform {
    required_version = ">= 1.15.0"

    required_providers{
        aws = {
            source = "hashicorp/aws"
            version = "~> 6.0"
        }
    }  

  backend "s3" {
    bucket       = "plataforma-interna-tfstate-3020"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "plataforma-interna"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

