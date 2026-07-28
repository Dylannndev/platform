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

resource "aws_vpc" "platform_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

resource "aws_subnet" "public_az_a" {
  vpc_id                  = aws_vpc.platform_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-az-a"
  }
}

resource "aws_subnet" "public_az_b" {
  vpc_id                  = aws_vpc.platform_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-az-b"
  }

}

resource "aws_subnet" "private_az_a" {
  vpc_id                  = aws_vpc.platform_vpc.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "us-east-1a"

  tags = {
    Name = "private-az-a"
  }
}

resource "aws_subnet" "private_az_b" {
  vpc_id                  = aws_vpc.platform_vpc.id
  cidr_block              = "10.0.12.0/24"
  availability_zone       = "us-east-1b"

  tags = {
    Name = "private-az-b"
  }
}

resource "aws_internet_gateway" "platform_igw" {
  vpc_id = aws_vpc.platform_vpc.id

  tags = {
    Name = "platform-igw"
  }
}

resource "aws_route_table" "platform_rt" {
  vpc_id = aws_vpc.platform_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.platform_igw.id
  }

  tags = {
    Name = "route-table-vpc"
  }
}

resource "aws_route_table_association" "public_az_a" {
  subnet_id      = aws_subnet.public_az_a.id
  route_table_id = aws_route_table.platform_rt.id
}

resource "aws_route_table_association" "public_az_b" {
  subnet_id      = aws_subnet.public_az_b.id
  route_table_id = aws_route_table.platform_rt.id
}