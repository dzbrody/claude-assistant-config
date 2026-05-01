variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the instance will be launched"
  type        = string
  default     = "vpc-0f16147ed2d23dee1"
}

variable "subnet_id" {
  description = "Subnet ID for the instance"
  type        = string
  default     = "subnet-0c23d4021f81edf63"
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for axinagroup.com"
  type        = string
  default     = "Z03662342MPWYW6ZEPJLC"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
  default     = "aws-key-xgccloudcom"
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
  description = "Full domain name for OpenProject"
  type        = string
  default     = "projects.axinagroup.com"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt SSL certificate notifications"
  type        = string
  default     = "db@xgccorp.com"
}

# Source IPs for security group (sensitive — use terraform.tfvars in practice)
variable "my_ipv4" {
  description = "Your IPv4 address for SSH and MCP access"
  type        = string
  default     = "99.239.58.91/32"
}

variable "my_ipv6" {
  description = "Your IPv6 address"
  type        = string
  default     = "2001:4860:7:704::f8/128"
}