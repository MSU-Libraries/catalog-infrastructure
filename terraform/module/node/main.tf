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

# Add a network device with IP to subnet and security group
resource "aws_network_interface" "node_nic" {
  subnet_id       = var.subnet_id
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
  # - As our gateway is defined in the shared module, we are no longer including it here
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

resource "aws_cloudwatch_metric_alarm" "cpu_credits" {
  for_each            = toset(var.cpu_balance_threshold == null ? [] : [1])
  alarm_name          = "${var.server_name}-cpu-credit-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUCreditBalance"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = var.cpu_balance_threshold
  alarm_description   = "Alarm when EC2 CPU credits drop below the given value"
  alarm_actions       = [var.alert_topic_arn]
  dimensions = {
    InstanceId = aws_instance.node_instance.id
  }
}

resource "aws_cloudwatch_metric_alarm" "ebs_burst" {
  for_each            = toset(var.ebs_balance_threshold == null ? [] : [1])
  alarm_name          = "${var.server_name}-ebs-burst-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "EBSBurstBalance"
  namespace           = "AWS/EBS"
  period              = 120
  statistic           = "Average"
  threshold           = var.ebs_balance_threshold
  alarm_description   = "Alarm when EBS burst balance drops below the given value"
  alarm_actions       = [var.alert_topic_arn]
  dimensions = {
    VolumeId = aws_instance.node_instance.root_block_device[0].volume_id
  }
}
