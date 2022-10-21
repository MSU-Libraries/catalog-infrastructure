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
