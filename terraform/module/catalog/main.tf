# Provider library needed to run (AWS for AWS EC2 in this case)
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
    Name = "${var.server_name}-vpc"
  }
}

# Define a gateway for the VPC
resource "aws_internet_gateway" "catalog_gateway" {
  vpc_id = aws_vpc.catalog_vpc.id

  tags = {
    Name = "${var.server_name}-gateway"
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
    Name = "${var.server_name}-route-table"
  }
}

# Define a subnet within the VPN
resource "aws_subnet" "catalog_subnet" {
  vpc_id     = aws_vpc.catalog_vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"

  tags = {
    Name = "${var.server_name}-subnet"
  }
}

# Assign the subnet with the route table
resource "aws_route_table_association" "catalog_rta_1" {
  subnet_id      = aws_subnet.catalog_subnet.id
  route_table_id = aws_route_table.catalog_route_table.id
}

# Set security rules to allow for inbound traffic (and allow outbound)
resource "aws_security_group" "catalog_sg_allow_net" {
  name        = "${var.server_name}-allow-net"
  description = "Allow inbound net traffic"
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
    Name = "${var.server_name}-sg-allow-net"
  }
}

# Add a network device with IP to subnet and security group
resource "aws_network_interface" "catalog_nic" {
  subnet_id       = aws_subnet.catalog_subnet.id
  private_ips     = ["10.0.0.10"]
  security_groups = [aws_security_group.catalog_sg_allow_net.id]

  tags = {
    Name = "${var.server_name}-nic"
  }
}

# Request a public IP (i.e. elastic IP) be assigned to the network device
resource "aws_eip" "catalog_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.catalog_nic.id
  associate_with_private_ip = "10.0.0.10"
  # Special case: Recommends explicitly indicating EIP dependencies for gateway and instance
  depends_on = [
    aws_internet_gateway.catalog_gateway,
    aws_instance.catalog_instance
  ]

  tags = {
    Name = "${var.server_name}-eip"
  }
}

# Create a hostname for the public IP for this catalog machine
resource "aws_route53_record" "catalog_dnsrec" {
  # Zone: aws.lib.msu.edu
  zone_id = "Z0159018169CCNUQINNQG"
  name    = "${var.server_name}.aws.lib.msu.edu"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.catalog_eip.public_ip]
}

# Create an EC2 virtual machine instance containing the network device
resource "aws_instance" "catalog_instance" {
  ami = var.aws_ami
  instance_type     = var.aws_instance_type
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"

  tags = {
    Name = "${var.server_name}-instance"
  }

  root_block_device {
    volume_size = var.aws_root_block_size
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.catalog_nic.id
  }

  # Script to run upon provisioning
  user_data = templatefile("${path.module}/user_data.sh", 
    {
      smtp_host = var.smtp_host,
      smtp_user = var.smtp_user,
      smtp_password = var.smtp_password

    }
  )

  lifecycle {
    ignore_changes = [
      user_data,
    ]
   #prevent_destroy = true # We'll add this back in once we're keeping servers up consistently
  }
}
