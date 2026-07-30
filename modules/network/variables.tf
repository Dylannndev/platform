variable "vpc_cidr" {
  type        = string
  description = "IP range of the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "IP ranges of the public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "IP ranges of the private subnets"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones used by the network"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "nat_instance_type" {
  type        = string
  description = "EC2 instance type used for the NAT instance"
  default     = "t4g.micro"
}

variable "environment" {
  type        = string
  description = "Environment name (dev or prod), used to tag resources"
}