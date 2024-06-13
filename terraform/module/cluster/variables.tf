variable "aws_region" {
  description = "AWS region"
  type = string
}

variable "vpc_cidr" {
  description = "CIDR range to be used for AWS VPC"
  type = string
}

variable "vpc_id" {
  description = "The vpc.id where to place the cluster"
  type = string
}

variable "route_table_id" {
  description = "The route table id for the VPC"
  type = string
}

variable "efs_id" {
  description = "The efs.id for the mounted shared storage within the servers"
  type = string
}

variable "cluster_cidr" {
  description = "CIDR range for the cluster within the VPC"
  type = string
}

variable "domain" {
  # TODO Can we pull this value from AWS given the zone_id below instead of passing it?
  # example: aws.lib.msu.edu
  description = "The domain within which the servers will reside"
  type = string
}

variable "zone_id" {
  # example: Z01234567890ABCDEFGHI
  description = "The zone_id in AWS Route53 for which the domain is associated"
  type = string
}

variable "cluster_name" {
  description = "Name of cluster to be used in vars and tags"
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

variable "roundrobin_hostnames" {
  # E.g. "catalog" with domain set to "aws.example.edu" would make RR DNS for "catalog.aws.example.edu"
  description = "Hostnames to create within the domain with round robin DNS to node IPs"
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
