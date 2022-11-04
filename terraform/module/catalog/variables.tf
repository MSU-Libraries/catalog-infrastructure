variable "aws_region" {
  description = "AWS region"
  type = string
}

variable "vpc_cidr" {
  description = "CIDR rangeto be used for AWS VPC"
  type = string
}

variable "cluster_name" {
  description = "Name of cluster to be used in vars"
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

variable "nodes" {
  description = "The list of variables used to create catalog nodes"
  type = map(object({
    server_name = string
    aws_availability_zone = string
    aws_ami = string
    aws_instance_type = string
    aws_root_block_size = number
    private_ip = string
    subnet_cidr = string
  }))
}
