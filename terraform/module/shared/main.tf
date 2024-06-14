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

resource "aws_subnet" "zone_subnets" {
  for_each          = var.zone_subnets
  vpc_id            = aws_vpc.shared_vpc.id
  cidr_block        = each.value
  availability_zone = "${var.aws_region}${each.key}"

  tags = {
    Name = "${var.shared_name}-az-subnet"
  }
}

# Associate the subnet with the route table
resource "aws_route_table_association" "shared_rtas" {
  for_each       = aws_subnet.zone_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.shared_route_table.id
}

resource "aws_security_group" "security_group_efs_net" {
  name        = "${var.shared_name}-efs-net"
  description = "Allow inbound traffic for EFS mounts"
  vpc_id      = aws_vpc.shared_vpc.id

  ingress {
    description      = "NFS allow inbound for EFS mount (tcp)"
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = [var.vpc_cidr]
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "NFS allow inbound for EFS mount (udp)"
    from_port        = 2049
    to_port          = 2049
    protocol         = "udp"
    cidr_blocks      = [var.vpc_cidr]
    ipv6_cidr_blocks = []
  }

  tags = {
    Name = "${var.shared_name}-sg-efs-net"
  }
}

# Create the EFS mount target in our subnet
resource "aws_efs_mount_target" "shared_efs_mts" {
  for_each        = aws_subnet.zone_subnets
  file_system_id  = aws_efs_file_system.shared_efs.id
  subnet_id       = each.value.id
  security_groups = [
    aws_security_group.security_group_efs_net.id
  ]
}
