provider "aws" {
  region = var.region
}

# Create a VPC

resource "aws_vpc" "first-vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Create an Internet gateway for your vpc
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.first-vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Create a custom route table 
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.first-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-rt"
  }
}

# Create a subnet with your VPC
resource "aws_subnet" "subnet" {
  cidr_block        = var.subnet_cidr
  vpc_id            = aws_vpc.first-vpc.id
  availability_zone = var.az

  tags = {
    Name = "${var.project_name}-subnet"
  }
}

# Create security group to allow traffic through port 22, 80, 443
resource "aws_security_group" "allow-web" {
  name        = "${var.project_name}-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.first-vpc.id

  ingress {
    description = "HTTPs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# Associate the custom route table with the subnet
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.rt.id
}

# Create a network interface for the subnet created in step 4
resource "aws_network_interface" "test" {
  security_groups = [aws_security_group.allow-web.id]
  private_ip      = "10.0.1.50"
  subnet_id       = aws_subnet.subnet.id
}

# Create an elastic IP for step 7
resource "aws_eip" "one" {
  associate_with_private_ip = "10.0.1.50"
  domain                    = "vpc"
  network_interface         = aws_network_interface.test.id
  depends_on                = [aws_security_group.allow-web, aws_instance.web]
}

# Create an instance with apache enabled and installed
resource "aws_instance" "web" {
  ami               = var.ami
  instance_type     = var.instance_type
  availability_zone = var.az
  key_name          = var.key_name

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.test.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update && sudo apt upgrade -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              EOF
}
