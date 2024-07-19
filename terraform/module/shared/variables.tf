variable "mail_instance" {
  description = "Name of mail instance used in vars"
  type = string
}

variable "aws_region" {
  description = "AWS region"
  type = string
}

variable "shared_name" {
  description = "Name prefix used in resource names and tags"
  type = string
}

variable "alert_emails" {
  description = "Send CloudWatch alerts to these email addresses"
  type = list(string)
}

variable "vpc_cidr" {
  description = "CIDR range to be used for AWS VPC"
  type = string
}

variable "zone_subnets" {
  description = "Subnet for each availability zone"
  type = map(string)
}
