# Get the default VPC

data "aws_vpc" "default" {
  default = true
}

# Get available subnets

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Find Ubuntu 24.04 AMI

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Security Group

resource "aws_security_group" "python_app_sg" {
  name        = "python-calculator-sg"
  description = "Allow SSH and Python application traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Python Flask application"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "python-calculator-sg"
  }
}

# EC2 Instance

resource "aws_instance" "python_app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.python_app_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    apt-get update -y
    apt-get install -y git python3 python3-venv python3-pip

    cd /opt

    git clone https://github.com/saikumarmedasari-devops/python_demo.git

    cd /opt/python_demo

    python3 -m venv venv
    ./venv/bin/pip install --upgrade pip
    ./venv/bin/pip install -r requirements.txt

    cat > /etc/systemd/system/python-calculator.service <<'SERVICE'
    [Unit]
    Description=Python Calculator Flask Application
    After=network.target

    [Service]
    User=ubuntu
    WorkingDirectory=/opt/python_demo
    ExecStart=/opt/python_demo/venv/bin/gunicorn --workers 2 --bind 0.0.0.0:5000 web_app:app
    Restart=always

    [Install]
    WantedBy=multi-user.target
    SERVICE

    chown -R ubuntu:ubuntu /opt/python_demo

    systemctl daemon-reload
    systemctl enable python-calculator
    systemctl start python-calculator
  EOF

  tags = {
    Name = "python-calculator"
  }
}
