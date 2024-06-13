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

# Define the provider to use
provider "aws" {
  region = var.aws_region
}

# Set security rules to allow for inbound traffic (and allow outbound)
resource "aws_security_group" "security_group_public_net" {
  name        = "${var.cluster_name}-public-net"
  description = "Allow inbound traffic from public network"
  vpc_id      = var.vpc_id

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
  ingress {
    description      = "ICMP ping"
    # Port fields are used to describe type of icmp; 8,0 is "echo request"
    from_port        = 8        # icmp type
    to_port          = 0        # icmp code
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "ICMP TIMESTAMP (Nagios only)"
    from_port        = 13
    to_port          = 0
    protocol         = "icmp"
    cidr_blocks      = var.net_allow_inbound_ncpa
    ipv6_cidr_blocks = []
  }

  egress {
    description      = "Allow all outgoing traffic"
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
  vpc_id      = var.vpc_id

  ingress {
    description      = "Docker Swarm Cluster Management"
    from_port        = 2377
    to_port          = 2377
    protocol         = "tcp"
    cidr_blocks      = [var.cluster_cidr]
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "Docker Swarm Node Communication (TCP)"
    from_port        = 7946
    to_port          = 7946
    protocol         = "tcp"
    cidr_blocks      = [var.cluster_cidr]
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "Docker Swarm Node Communication (UDP)"
    from_port        = 7946
    to_port          = 7946
    protocol         = "udp"
    cidr_blocks      = [var.cluster_cidr]
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "Docker Swarm Overlay Network Traffic"
    from_port        = 4789
    to_port          = 4789
    protocol         = "udp"
    cidr_blocks      = [var.cluster_cidr]
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "NFS allow inbound for EFS mount (tcp)"
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = [var.vpc_cidr]
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "NFS allow inbound for EFS mount (udp)"
    from_port        = 2049
    to_port          = 2049
    protocol         = "udp"
    cidr_blocks      = [var.vpc_cidr]
    ipv6_cidr_blocks = []
  }

  tags = {
    Name = "${var.cluster_name}-sg-private-net"
  }
}

# Create user with permissions to verify Let's Encrypt DNS challenge
resource "aws_iam_user" "dnschallenge_user" {
  name = "${var.cluster_name}-dnschallenge"

  tags = {
    Name = "${var.cluster_name}-dnschallenge"
  }
}

resource "aws_iam_access_key" "dnschallenge_key" {
  user = aws_iam_user.dnschallenge_user.name
}

resource "aws_iam_user_policy" "dnschallenge_policy" {
  name = "${var.cluster_name}-dnschallenge-user-policy"
  user = aws_iam_user.dnschallenge_user.name

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:GetChange",
                "route53:ListHostedZonesByName"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets",
                "route53:ListResourceRecordSets"
            ],
            "Resource": [
                "arn:aws:route53:::hostedzone/${ var.zone_id }"
            ]
        }
    ]
}
POLICY
}

module "nodes" {
  for_each = var.nodes
  source   = "../node"
  security_group_ids = [
    aws_security_group.security_group_public_net.id,
    aws_security_group.security_group_private_net.id    # If private moves from index 1, then need to update EFS mount target resource definition
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
  catalog_route_table_id = var.route_table_id
  vpc_id = var.vpc_id
  efs_id = var.efs_id
}

# Create round robin hostname records
# Only required for prod cluster, as it is the only location where we
# reference domain names without a Route53 controlled domain (e.g. catalog-beta.lib.msu.edu)
resource "aws_route53_record" "roundrobin_dnsrec" {
  for_each = toset(var.roundrobin_hostnames)
  zone_id  = "${var.zone_id}"
  name     = "${each.value}.${var.domain}"
  type     = "A"
  ttl      = "300"
  records  = [for node in module.nodes:"${node.public_ip}"]
}
