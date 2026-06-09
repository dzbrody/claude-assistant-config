# ============================================================
# OpenProject Server — EC2 + Docker Compose
# Domain: projects.axinagroup.com
# ============================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Optional: store state in S3 for collaboration later
  # backend "s3" {
  #   bucket = "dzbrody-terraform-state"
  #   key    = "openproject/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================
# Data Sources — Existing Infrastructure
# ============================================================

data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnet" "main" {
  id = var.subnet_id
}

data "aws_route53_zone" "main" {
  zone_id = var.hosted_zone_id
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================
# Security Group
# ============================================================

# Port reference:
# 22   — SSH (your IPs only)
# 80   — HTTP (redirect to 443)
# 443  — HTTPS (OpenProject web UI)
# 8080 — OpenProject direct (optional, internal)
# 39128 — MCP server: localhost-only on EC2, accessed via SSM tunnel

resource "aws_security_group" "openproject" {
  name        = "openproject-server"
  description = "Security group for OpenProject + MCP server"
  vpc_id      = var.vpc_id

  # ---- SSH ----
  ingress {
    description = "SSH from admin IPv4"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ipv4]
  }

  dynamic "ingress" {
    for_each = var.my_ipv6 != "" ? [var.my_ipv6] : []
    content {
      description      = "SSH from admin IPv6"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      ipv6_cidr_blocks = [ingress.value]
    }
  }

  # ---- HTTP/HTTPS ----
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # ---- OpenProject Direct (optional, admin only) ----
  ingress {
    description      = "OpenProject direct (admin IP only)"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = [var.my_ipv4]
    ipv6_cidr_blocks = var.my_ipv6 != "" ? [var.my_ipv6] : []
  }

  # ---- Outbound (all) ----
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "openproject-server"
  }
}

# ============================================================
# EC2 Instance
# ============================================================

resource "aws_instance" "openproject" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.openproject.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.openproject.name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true

    tags = {
      Name = "openproject-root"
    }
  }

  # Store Docker volumes and OpenProject data on a separate EBS volume
  # so it survives instance replacement
  ebs_block_device {
    device_name = "/dev/xvdf"
    volume_type = "gp3"
    volume_size = var.data_volume_size
    encrypted   = true
    delete_on_termination = false

    tags = {
      Name = "openproject-data"
    }
  }

  user_data = templatefile("${path.module}/../docker/user-data.sh", {
    domain_name = var.domain_name
    letsencrypt_email = var.letsencrypt_email
  })

  tags = {
    Name = "openproject-server"
  }
}

# ============================================================
# Elastic IP (static IP for the EC2)
# ============================================================

resource "aws_eip" "openproject" {
  instance = aws_instance.openproject.id
  domain   = "vpc"

  tags = {
    Name = "openproject-eip"
  }
}

# ============================================================
# Route53 DNS Record
# ============================================================

resource "aws_route53_record" "openproject" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_eip.openproject.public_ip]
}


# ============================================================
# IAM Role — Axina OpenProject EC2
# ============================================================

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "openproject" {
  name               = "axina-openproject-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "axina-openproject-role"
  }
}

resource "aws_iam_role_policy_attachment" "openproject_ssm" {
  role       = aws_iam_role.openproject.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "openproject" {
  name = "axina-openproject-profile"
  role = aws_iam_role.openproject.name
}

# ============================================================
# S3 Bucket — OpenProject File Attachments
# ============================================================

resource "aws_s3_bucket" "openproject_files" {
  bucket = "axina-openproject-files"
}

resource "aws_s3_bucket_versioning" "openproject_files" {
  bucket = aws_s3_bucket.openproject_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "openproject_files" {
  bucket = aws_s3_bucket.openproject_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "openproject_files" {
  bucket = aws_s3_bucket.openproject_files.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
  }

  rule {
    id     = "backup-lifecycle"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "openproject_files" {
  bucket = aws_s3_bucket.openproject_files.id

  cors_rule {
    allowed_origins = ["https://projects.axinagroup.com"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE"]
    allowed_headers = ["*"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_public_access_block" "openproject_files" {
  bucket = aws_s3_bucket.openproject_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================
# IAM Policy — Allow EC2 to access the S3 bucket
# ============================================================

data "aws_iam_policy_document" "openproject_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.openproject_files.arn,
      "${aws_s3_bucket.openproject_files.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "openproject_s3" {
  name   = "openproject-s3-access"
  role   = aws_iam_role.openproject.name
  policy = data.aws_iam_policy_document.openproject_s3.json
}

# ============================================================
# Outputs
# ============================================================

output "public_ip" {
  description = "Public IP of the OpenProject server"
  value       = aws_eip.openproject.public_ip
}

output "domain_name" {
  description = "Fully qualified domain name"
  value       = "https://${var.domain_name}"
}

output "instance_id" {
  description = "EC2 instance ID for SSM connections"
  value       = aws_instance.openproject.id
}

output "ssm_tunnel_command" {
  description = "Command to start SSM port forwarding tunnel for MCP"
  value       = "aws ssm start-session --target ${aws_instance.openproject.id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"39128\"],\"localPortNumber\":[\"39128\"]}'"
}

output "claude_mcp_command" {
  description = "Claude CLI command to connect MCP (run AFTER starting SSM tunnel)"
  value       = "claude mcp add --transport sse openproject http://localhost:39128/sse"
}

output "s3_bucket" {
  description = "S3 bucket for OpenProject file attachments"
  value       = aws_s3_bucket.openproject_files.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.openproject_files.arn
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_eip.openproject.public_ip}"
}