data "aws_ami" "fck_nat" {
  most_recent = true
  owners      = ["568608671756"]

  filter {
    name   = "name"
    values = ["fck-nat-al2023-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

resource "aws_instance" "nat_instance" {
  ami                    = data.aws_ami.fck_nat.id
  instance_type          = "t4g.nano"
  subnet_id              = aws_subnet.public_az_a.id
  source_dest_check      = false
  vpc_security_group_ids = [aws_security_group.nat_instance_sg.id]

  tags = {
    Name = "nat-instance"
  }
}

resource "aws_security_group" "nat_instance_sg" {
  name        = "nat-instance-sg"
  description = "Allow private subnets to reach internet via NAT instance"
  vpc_id      = aws_vpc.platform_vpc.id

  tags = {
    Name = "nat-instance-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nat_from_private_az_a" {
  security_group_id = aws_security_group.nat_instance_sg.id
  cidr_ipv4          = "10.0.11.0/24"
  ip_protocol         = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "nat_from_private_az_b" {
  security_group_id = aws_security_group.nat_instance_sg.id
  cidr_ipv4          = "10.0.12.0/24"
  ip_protocol         = "-1"
}

resource "aws_vpc_security_group_egress_rule" "nat_to_internet" {
  security_group_id = aws_security_group.nat_instance_sg.id
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol         = "-1"
}


resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.platform_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    network_interface_id = aws_instance.nat_instance.primary_network_interface_id
  }

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private_az_a" {
  subnet_id      = aws_subnet.private_az_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_az_b" {
  subnet_id      = aws_subnet.private_az_b.id
  route_table_id = aws_route_table.private_rt.id
}