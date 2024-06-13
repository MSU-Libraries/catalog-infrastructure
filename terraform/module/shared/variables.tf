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

variable "vpc_cidr" {
  description = "CIDR range to be used for AWS VPC"
  type = string
}

variable "efs_mount_zones" {
  description = "Availability zones where the EFS mount target should be available"
  type = list(string)
}
