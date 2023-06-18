# Define a vpc
resource "aws_vpc" "vpc" {
  cidr_block = "10.5.0.0/16"
  tags = {
    Name = "${var.prefix}"
    createdBy = "infra-${var.prefix}/base"
  }
}

resource "aws_ssm_parameter" "vpc" {
  name = "/${var.prefix}/base/vpc_id"
  value = "${aws_vpc.vpc.id}"
  type  = "String"
}

# Routing table for public subnets
resource "aws_route_table" "public_subnet_routes" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
  tags = {
    Name = "Public subnet routing table"
    createdBy = "infra-${var.prefix}/base"
  }
}

# Internet gateway for the public subnet
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags = {
    Name = "Public gateway"
    createdBy = "infra-${var.prefix}/base"
  }
}

resource "aws_subnet" "public_subnet_a" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.5.0.0/24"
  availability_zone = "${var.region}a"
  tags = {
    Name = "Public subnet A"
    createdBy = "infra-${var.prefix}/base"
  }
}

resource "aws_ssm_parameter" "subnet_a" {
  name = "/${var.prefix}/base/subnet/a/id"
  value = "${aws_subnet.public_subnet_a.id}"
  type  = "String"
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.5.1.0/24"
  availability_zone = "${var.region}b"
  tags = {
    Name = "Public subnet B"
    createdBy = "infra-${var.prefix}/base"
  }
}

resource "aws_ssm_parameter" "subnet_b" {
  name = "/${var.prefix}/base/subnet/b/id"
  value = "${aws_subnet.public_subnet_b.id}"
  type  = "String"
}

# Here, you can add more subnets in other availability zones

# Associate the routing table to public subnet A
resource "aws_route_table_association" "public_subnet_routes_assn_a" {
  subnet_id = "${aws_subnet.public_subnet_a.id}"
  route_table_id = "${aws_route_table.public_subnet_routes.id}"
}

# Associate the routing table to public subnet B
resource "aws_route_table_association" "public_subnet_routes_assn_b" {
  subnet_id = "${aws_subnet.public_subnet_b.id}"
  route_table_id = "${aws_route_table.public_subnet_routes.id}"
}
/*
resource "aws_security_group" "allec2" {
  name        = "allec2"
  
  vpc_id      = "${aws_vpc.vpc.id}"
 
   ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["49.37.156.198/32"]
     }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  tags = {
    Name = "all-sg"
  }
}
resource "aws_security_group" "frontend-sg" {
  name        = "frontend-sg"
 
  vpc_id      = "${aws_vpc.vpc.id}"
 
  ingress {
    description      = "HTTP"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
     }



  tags = {
    Name = "frontend-sg"
  }
}
resource "aws_security_group" "newsfeed-sg" {
  name        = "newsfeed-sg"
  
  vpc_id      = "${aws_vpc.vpc.id}"
 
  ingress {
    description      = "HTTP"
    from_port        = 8081
    to_port          = 8081
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
     }



  tags = {
    Name = "newsfeed-sg"
  }
}
resource "aws_security_group" "quotes-sg" {
  name        = "quotes-sg"
 
  vpc_id      = "${aws_vpc.vpc.id}"
 
  ingress {
    description      = "HTTP"
    from_port        = 8082
    to_port          = 8082
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
     }

  tags = {
    Name = "quotes-sg"
  }
}
*/