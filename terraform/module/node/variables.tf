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

variable "subnet_cidr" {
  description = "CIDR to use for subnet within this availability zone"
  type = string
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

variable "catalog_gateway" {
  description = "Terraform gateway resource definition"
  type = object({
    id = string
  })
}

variable "catalog_route_table_id" {
  description = "AWS Route table to associate with this node's subnet"
  type = string
}

variable "vpc_id" {
  description = "AWS VPC to assign subnet to"
  type = string
}

variable "bucket_user" {
  description = "AWS IAM user for the S3 bucket"
  type = string
}

variable "bucket_key" {
  description = "Key for the AWS IAM user to be used for the S3 bucket"
  type = string
}
