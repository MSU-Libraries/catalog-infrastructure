# Provider library needed to run (AWS for AWS EC2 in this case)
# To install: terraform init
terraform {
  required_version = ">= 1.2.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
}

# Define the provider to use
provider "aws" {
  region = var.aws_region
}

# New user for sending email
resource "aws_iam_user" "catalog_smtp_user" {
  name = "${var.mail_instance}-smtp"

  tags = {
    Name = "${var.mail_instance}-smtp-user"
  }
}

# Create access key
resource "aws_iam_access_key" "catalog_smtp_key" {
  user = aws_iam_user.catalog_smtp_user.name
}

# Define permissions policy
data "aws_iam_policy_document" "catalog_ses_policy_doc" {
  statement {
    actions   = ["ses:SendRawEmail"]
    resources = ["*"]
  }
}

# Create policy
resource "aws_iam_policy" "catalog_ses_policy" {
  name        = "${var.mail_instance}-ses"
  description = "Allows sending of e-mails via Simple Email Service"
  policy      = data.aws_iam_policy_document.catalog_ses_policy_doc.json

  tags = {
    Name = "${var.mail_instance}-ses-policy"
  }
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "catalog_ses_policy_attach" {
  user       = aws_iam_user.catalog_smtp_user.name
  policy_arn = aws_iam_policy.catalog_ses_policy.arn
}

# Define a virtual private cloud (VPC, essentially a private network)
resource "aws_vpc" "shared_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true       # Required for EFS mount targets DNS resolution
  tags = {
    Name = "${var.shared_name}-vpc"
  }
}

# Define a gateway for the VPC
resource "aws_internet_gateway" "shared_gateway" {
  vpc_id = aws_vpc.shared_vpc.id

  tags = {
    Name = "${var.shared_name}-gateway"
  }
}

# Define a route table to have external traffic routed out
resource "aws_route_table" "shared_route_table" {
  vpc_id = aws_vpc.shared_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.shared_gateway.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.shared_gateway.id
  }

  tags = {
    Name = "${var.shared_name}-route-table"
  }
}

# Create EFS resource for shared storage
resource "aws_efs_file_system" "shared_efs" {
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
    # transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = {
    Name = "${var.shared_name}-shared-storage"
  }
}

# Creating access point for EFS
resource "aws_efs_access_point" "shared_efs_ap" {
  file_system_id = aws_efs_file_system.shared_efs.id
}

# Creating the EFS system policy to handle file transitions
resource "aws_efs_file_system_policy" "shared_efs_policy" {
  file_system_id = aws_efs_file_system.shared_efs.id

  # bypass_policy_lockout_safety_check = true

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Id": "Policy01",
    "Statement": [
        {
            "Sid": "Statement",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Resource": "${aws_efs_file_system.shared_efs.arn}",
            "Action": [
                "elasticfilesystem:ClientMount",
                "elasticfilesystem:ClientRootAccess",
                "elasticfilesystem:ClientWrite"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
POLICY
}
