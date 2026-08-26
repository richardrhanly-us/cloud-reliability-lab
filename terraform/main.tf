# ============================================================
# Shared Configuration
# ============================================================

locals {
  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# ============================================================
# Amazon Linux 2023 AMI
# ============================================================

data "aws_ssm_parameter" "amazon_linux_2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ============================================================
# Networking
# ============================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.20.1.0/24"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-subnet"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-route-table"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ============================================================
# Security Group
# ============================================================

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for Cloud Reliability Lab web server"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-web-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id

  description = "Allow public HTTP traffic"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id

  description = "Allow outbound traffic"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = local.common_tags
}

# ============================================================
# EC2 IAM, SSM, and CloudWatch Permissions
# ============================================================

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ============================================================
# EC2 Application Server
# ============================================================

resource "aws_instance" "app" {
  ami           = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type = var.instance_type

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.ec2.name

  user_data = file("${path.module}/../scripts/aws-bootstrap.sh")

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-app"
  })
}

# ============================================================
# CloudWatch Monitoring
# ============================================================

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  alarm_description   = "Triggers when EC2 CPU utilization stays above 80 percent."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = aws_instance.app.id
  }

  treat_missing_data = "notBreaching"

  tags = local.common_tags
}

# Convert systemd application failures into a CloudWatch metric.
resource "aws_cloudwatch_log_metric_filter" "app_systemd_failure" {
  name           = "${var.project_name}-systemd-failure"
  log_group_name = "/cloud-reliability-lab/systemd"

  pattern = "\"Failed with result\""

  metric_transformation {
    name          = "SystemdFailureCount"
    namespace     = "CloudReliabilityLab"
    value         = "1"
    default_value = "0"
  }
}

# Alarm when at least one systemd application failure is detected.
resource "aws_cloudwatch_metric_alarm" "app_systemd_failure" {
  alarm_name          = "${var.project_name}-systemd-failure"
  alarm_description   = "Application service failure detected in systemd logs."
  comparison_operator = "GreaterThanOrEqualToThreshold"

  evaluation_periods = 1
  threshold          = 1

  metric_name = "SystemdFailureCount"
  namespace   = "CloudReliabilityLab"
  statistic   = "Sum"
  period      = 60

  treat_missing_data = "notBreaching"

  tags = local.common_tags
}
