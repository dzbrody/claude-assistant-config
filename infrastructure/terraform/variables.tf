variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the instance will be launched"
  type        = string
  # Set in terraform.tfvars — find with: aws ec2 describe-vpcs --query 'Vpcs[?IsDefault].VpcId'
}

variable "subnet_id" {
  description = "Subnet ID for the instance"
  type        = string
  # Set in terraform.tfvars — find with: aws ec2 describe-subnets --query 'Subnets[0].SubnetId'
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for your domain"
  type        = string
  # Set in terraform.tfvars — find with: aws route53 list-hosted-zones-by-name --dns-name yourdomain.com
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
  # Set in terraform.tfvars — must already exist in AWS: aws ec2 describe-key-pairs
}


variable "instance_type" {
  description = "EC2 instance type (4+ vCPU, 8GB+ RAM recommended)"
  type        = string
  default     = "t3.large"  # 2 vCPU, 8GB — minimum viable
  # Consider t3.xlarge (4 vCPU, 16GB) for better performance
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

variable "data_volume_size" {
  description = "Data EBS volume size in GB (Docker volumes, OpenProject data)"
  type        = number
  default     = 100
}

variable "domain_name" {
  description = "Full domain name for OpenProject (must be in the Route53 hosted zone)"
  type        = string
  # Example: "projects.yourdomain.com"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt SSL certificate expiry notifications"
  type        = string
  # Use the domain owner's email
}

# Source IPs for SSH security group rules — set in terraform.tfvars, never hardcode here
variable "my_ipv4" {
  description = "Your IPv4 CIDR for SSH access (e.g. 1.2.3.4/32)"
  type        = string
  # Find your IP: curl -4 ifconfig.me && echo /32
}

variable "my_ipv6" {
  description = "Your IPv6 CIDR for SSH access (e.g. 2001:db8::/128)"
  type        = string
  default     = ""
  # Find your IP: curl -6 ifconfig.me && echo /128 — leave empty string if no IPv6
}