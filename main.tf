provider "aws" {
  region  = var.region
}


# BASTION

module "bastion" {
  source = "umotif-public/bastion/aws"
  version = "~> 2.1.0"
  name_prefix = "core-example"
  bastion_instance_types = ["t2.micro"]
  vpc_id         = aws_vpc.main.id
  private_subnets = [aws_subnet.private.id,aws_subnet.private_1.id] 
  public_subnets = [aws_subnet.public.id] 
  ssh_key_name   = "1"

  tags = {
    Project = "Test"
  }
}




#SECURITY GROUP

resource "aws_security_group" "nat" {
  name = "nat"
  description = "Allow nat traffic"
  vpc_id = aws_vpc.main.id

  ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
}


#NETWORK



resource "aws_vpc" "main" {
  cidr_block = "172.17.0.0/16"
  tags = {
    Name = "Test-VPC"
  }
}


resource "aws_subnet" "private" {
  cidr_block        =  "172.17.1.0/24"
  availability_zone =  "eu-central-1a"
  vpc_id            = aws_vpc.main.id
  tags = {
    Name = "Test-private"
  }
}

resource "aws_subnet" "private_1" {
  cidr_block        =  "172.17.6.0/24"
  availability_zone =  "eu-central-1b"
  vpc_id            = aws_vpc.main.id
  tags = {
    Name = "Test-private_1"
  }
}


resource "aws_subnet" "public" {
  cidr_block              = "172.17.2.0/24"
  availability_zone       = "eu-central-1a"
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true
  tags = {
    Name = "Test-public"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Test-gw"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.main.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_eip" "gw" {
  count      = 1
  vpc        = true
  depends_on = [aws_internet_gateway.gw]
  tags = {
    Name = "Test-EIP"
  }
}

resource "aws_nat_gateway" "gw" {
  count         = 1
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  allocation_id = element(aws_eip.gw.*.id, count.index)
  tags = {
    Name = "Test-GW"
  }
}
resource "aws_route_table" "private" {
  count  = 1
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.gw.*.id, count.index)
  }
  tags = {
    Name = "Test-RT"
  }
}
resource "aws_route_table_association" "private" {
  count          = 1
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

resource "aws_route_table_association" "private_1" {
  count          = 1
  subnet_id      = element(aws_subnet.private_1.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}






#EC2APACHE

resource "aws_instance" "my_web_server" {
      ami = "ami-0453cb7b5f2b7fca2"
        instance_type = "t2.micro"
        vpc_security_group_ids = [aws_security_group.nat.id]
        subnet_id = aws_subnet.private.id
        user_data = file("user_data.sh")
	depends_on = [aws_subnet.private]
	key_name               = "1"
    tags = {
        Name = "Web Server Build by terraform"
        Owner = "Valentine Kravtsov"
    }

    lifecycle {
        prevent_destroy = false
    }
}

resource "aws_instance" "my_web_server1" {
      ami = "ami-0453cb7b5f2b7fca2"
        instance_type = "t2.micro"
        vpc_security_group_ids = [aws_security_group.nat.id]
        subnet_id = aws_subnet.private_1.id
        user_data = file("user_data.sh")
        depends_on = [aws_subnet.private_1]
        key_name               = "1"
    tags = {
        Name = "Web Server Build by terraform"
        Owner = "Valentine Kravtsov"
    }

    lifecycle {
        prevent_destroy = false
    }
}

# ALB


module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name = "my-alb"

  load_balancer_type = "application"

  vpc_id             = aws_vpc.main.id
  subnets            = [aws_subnet.private.id,aws_subnet.private_1.id] # ["subnet-06c6144dd53cd8ae4","subnet-0bb3b94dc5e1cc0c0"]
  security_groups    = [aws_security_group.nat.id]

target_groups = [
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      targets = [
        {
          target_id = "i-0cc43223cf45f27d9"
          port = 80
        },
        {
          target_id = "i-044709d9db9711e92"
          port = 80
        }
      ]
    }
  ]
http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]
}

