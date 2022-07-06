# Provider library needed to run
# To install: terraform init
terraform {
  required_version = "~> 1.2.3"
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

# Define a virtual private cloud (VPC, essentially a private network)
resource "aws_vpc" "catalog_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# Define a gateway for the VPC
resource "aws_internet_gateway" "catalog_gateway" {
  vpc_id = aws_vpc.catalog_vpc.id

  tags = {
    Name = "${var.cluster_name}-gateway"
  }
}

# Define a route table to have external traffic routed out
resource "aws_route_table" "catalog_route_table" {
  vpc_id = aws_vpc.catalog_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.catalog_gateway.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.catalog_gateway.id
  }

  tags = {
    Name = "${var.cluster_name}-route-table"
  }
}

# Set security rules to allow for inbound traffic (and allow outbound)
resource "aws_security_group" "security_group_public_net" {
  name        = "${var.cluster_name}-public-net"
  description = "Allow inbound traffic from public network"
  vpc_id      = aws_vpc.catalog_vpc.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.net_allow_inbound_ssh
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "Nagios"
    from_port        = 5693
    to_port          = 5693
    protocol         = "tcp"
    cidr_blocks      = var.net_allow_inbound_ncpa
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = var.net_allow_inbound_web
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = var.net_allow_inbound_web
    ipv6_cidr_blocks = []
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.cluster_name}-sg-public-net"
  }
}

# Set security rules to allow for internal traffic to the VPC
resource "aws_security_group" "security_group_private_net" {
  name        = "${var.cluster_name}-private-net"
  description = "Allow inbound traffic from private network"
  vpc_id      = aws_vpc.catalog_vpc.id

  ingress {
    description      = "Docker Swarm Cluster Management"
    from_port        = 2377
    to_port          = 2377
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "Docker Swarm Node Communication (TCP)"
    from_port        = 7946
    to_port          = 7946
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "Docker Swarm Node Communication (UDP)"
    from_port        = 7946
    to_port          = 7946
    protocol         = "udp"
    cidr_blocks      = ["10.0.0.0/16"]
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "Docker Swarm Overlay Network Traffic"
    from_port        = 4789
    to_port          = 4789
    protocol         = "udp"
    cidr_blocks      = ["10.0.0.0/16"]
    ipv6_cidr_blocks = []
  }

  tags = {
    Name = "${var.cluster_name}-sg-private-net"
  }
}

module "nodes" {
  for_each = var.nodes
  source   = "../node"
  security_group_ids = [
    aws_security_group.security_group_public_net.id,
    aws_security_group.security_group_private_net.id
  ]
  server_name = each.value.server_name
  aws_instance_type = each.value.aws_instance_type
  aws_root_block_size = each.value.aws_root_block_size
  aws_region = var.aws_region
  aws_availability_zone = each.value.aws_availability_zone
  aws_ami = each.value.aws_ami
  private_ip = each.value.private_ip
  subnet_cidr = each.value.subnet_cidr
  smtp_host = var.smtp_host
  smtp_user = var.smtp_user
  smtp_password = var.smtp_password
  catalog_gateway = aws_internet_gateway.catalog_gateway
  catalog_route_table_id = aws_route_table.catalog_route_table.id
  vpc_id = aws_vpc.catalog_vpc.id
}
