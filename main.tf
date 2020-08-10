provider "aws" {
  region     = "eu-west-3"
  access_key = "Secret"
  secret_key = "Secret"
}

# # Creating new Instance in AWS cloud
# resource "aws_instance" "First-Instance" {
#   ami           = "ami-0aa9ac13698fff547"
#   instance_type = "t2.micro"

#   tags = {
#     Name = "Production"
#   }
# }

# # Creating new VPC in AWS cloud
#   resource "aws_vpc" "First_VPC" {
#   cidr_block = "10.0.0.0/16"

#   tags = {
#     Name = "Production"
#   }
# }

# # Creating new Subnet in AWS Cloud
# resource "aws_subnet" "subnet-1" {
#   vpc_id     = aws_vpc.First_VPC.id #refering to the VPC, that we created above
#   cidr_block = "10.0.1.0/24"

#   tags = {
#     Name = "sub-prod"
#   }
# }


#1. Create VPC
  resource "aws_vpc" "Prod_VPC" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Production"
  }
}

#2. Create Internet Gateway
resource "aws_internet_gateway" "Prod_Gateway" {
  vpc_id = aws_vpc.Prod_VPC.id

  tags = {
    Name = "Prod-gateway"
  }
}

#3. Create custom route Table
resource "aws_route_table" "Prod_route_table" {
  vpc_id = aws_vpc.Prod_VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Prod_Gateway.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.Prod_Gateway.id
  }

  tags = {
    Name = "Prod_route"
  }
}

#4. Create a Subnet
resource "aws_subnet" "Prod_Subnet" {
  vpc_id =  aws_vpc.Prod_VPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-3a"

  tags =  {
    Name =  "Prod_Subnet"
  }
}

#5. Assocaite subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.Prod_Subnet.id
  route_table_id = aws_route_table.Prod_route_table.id
}

#6. Create Security Group to allow port  22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.Prod_VPC.id

  ingress {
    description = "SSH connection from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS connection from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP connection from VPC"
    from_port   = 80
    to_port     = 80
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
    Name = "allow_web"
  }
}

#7. Create a network interface with an ip in the subnet that was create in step 4
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.Prod_Subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = ["${aws_security_group.allow_web.id}"]

  # attachment {
  #   instance     = "${aws_instance.test.id}"
  #   device_index = 1
  # }
}

#8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.Prod_Gateway]
}

#9. Create ubuntu server and install/enable apache2
resource "aws_instance" "Ubuntu-Prod-Server" {
  ami           = "ami-0e11cbb34015ff725"
  instance_type = "t2.micro" 
  availability_zone = "eu-west-3a"
  key_name = "my_key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemcl status apache2
                sudo systemctl start apache2
                sudo systecmtl status apache2
                sudo bash -c 'echo your first server is installed successfully and apache2 is runnnig successfully > /var/www/html/index.html'
                EOF
  tags = {
    Name = "Production"
  }
}
