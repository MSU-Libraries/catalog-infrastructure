# Provider library needed to run
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

# Define a subnet within the VPC
resource "aws_subnet" "node_subnet" {
  vpc_id     = var.vpc_id
  cidr_block = var.subnet_cidr
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"

  tags = {
    Name = "${var.server_name}-subnet"
  }
}

# Assign the subnet with the route table
resource "aws_route_table_association" "catalog_rta" {
  subnet_id      = aws_subnet.node_subnet.id
  route_table_id = var.catalog_route_table_id
}

# Create the EFS mount target in our subnet
resource "aws_efs_mount_target" "catalog_efs_mt" {
  file_system_id  = var.efs_id
  subnet_id       = aws_subnet.node_subnet.id
  security_groups = [
    var.security_group_ids[1]       # Index 1 is the private security group
  ]
}

# Add a network device with IP to subnet and security group
resource "aws_network_interface" "node_nic" {
  subnet_id       = aws_subnet.node_subnet.id
  private_ips     = [var.private_ip]
  security_groups = var.security_group_ids

  tags = {
    Name = "${var.server_name}-nic"
  }
}

# Request a public IP (i.e. elastic IP) be assigned to the network device
resource "aws_eip" "node_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.node_nic.id
  associate_with_private_ip = var.private_ip
  # Special case: Recommends explicitly indicating EIP dependencies for gateway and instance
  depends_on = [
    aws_instance.node_instance
  ]

  tags = {
    Name = "${var.server_name}-eip"
  }
}

# Create a hostname for the public IP for this node machine
resource "aws_route53_record" "node_dnsrec" {
  # Zone: aws.lib.msu.edu
  zone_id = "Z0159018169CCNUQINNQG"
  name    = "${var.server_name}.aws.lib.msu.edu"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.node_eip.public_ip]
}

# Create an EC2 virtual machine instance containing the network device
resource "aws_instance" "node_instance" {
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
    network_interface_id = aws_network_interface.node_nic.id
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
    prevent_destroy = true # Avoid accidentally destroying the catalog
  }
}
