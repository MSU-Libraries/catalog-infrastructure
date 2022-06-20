variable "server_name" {
  description = "Name of server used in vars"
  type = string
}

variable "aws_instance_type" {
  description = "AWS instance type"
  type = string
}

variable "aws_root_block_size" {
  description = "Size in GB of the root volume"
  type = number
}

variable "aws_region" {
  description = "AWS region"
  type = string
}

variable "aws_availability_zone" {
  description = "AWS availability zone"
  type = string
}

variable "aws_ami" {
  description = "AWS ami"
  type = string
}

variable "net_allow_inbound_ssh" {
  description = "Allow inbound to SSH port these CIDRs"
  type = list(string)
}

variable "net_allow_inbound_ncpa" {
  description = "Allow inbound to Nagios NCPA port these CIDRs"
  type = list(string)
}

variable "net_allow_inbound_web" {
  description = "Allow inbound to web ports these CIDRs"
  type = list(string)
}

variable "smtp_host" {
  description = "SMTP hostname"
  type = string
}

variable "smtp_user" {
  description = "SMTP username"
  type = string
}

variable "smtp_password" {
  description = "SMTP password"
  type = string
}
