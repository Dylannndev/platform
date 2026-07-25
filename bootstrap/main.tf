terraform{
    required_version = ">= 1.15.0"

    required_providers{
        aws = {
            source = "hashicorp/aws"
            version = "~> 6.0"
        }
    }  
}

provider "aws" {
    region = "us-east-1"
}

resource "aws_s3_bucket" "platform_bucket" {
    bucket = "plataforma-interna-tfstate-3020"

    tags = {
        Project = "plataforma-interna"
        Environment = "global"
        ManagedBy = "terraform"
    }
}

resource "aws_s3_bucket_versioning" "platform_versioning" {
    bucket = aws_s3_bucket.platform_bucket.id
    versioning_configuration{
        status = "Enabled"
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "platform_encryption" {
  bucket = aws_s3_bucket.platform_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "platform_pab" {
  bucket = aws_s3_bucket.platform_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}