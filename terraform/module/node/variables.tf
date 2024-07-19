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

variable "private_ip" {
  description = "Internal private IP to use within the VPC"
  type = string
}

variable "subnet_id" {
  description = "Subnet ID to use for node"
  type = string
}

variable "alert_topic_arn" {
  description = "SNS topic ARN to send alerts to"
  type = string
}

variable "cpu_balance_threshold" {
  description = "CPU Credit balance below which alarm is raised"
  type = number
  nullable = true
  default = null
}

variable "ebs_balance_threshold" {
  description = "EBS Burst balance below which alarm is raised"
  type = number
  nullable = true
  default = null
}

variable "security_group_ids" {
  description = "Predefined security groups to assign to NIC"
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
