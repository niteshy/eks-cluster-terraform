# Resource: aws_vpc
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc

#
# VPC Resources
#  * VPC
#  * Subnets
#  * Internet Gateway
#  * Route Table
#

# Diagram: https://lucid.app/lucidchart/c6646513-546c-4f70-9def-e180125e03f9/edit?viewport_loc=-91%2C24%2C2219%2C999%2C0_0&invitationId=inv_a7cd6bfc-02a2-4b34-bd04-a571d3929182

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  # The CIDR block for the VPC.
  cidr_block = "10.100.0.0/16"

  # Makes your instances shared on the host.
  instance_tenancy = "default"

  # Required for EKS. Enable/disable DNS support in the VPC.
  enable_dns_support = true

  # Required for EKS. Enable/disable DNS hostnames in the VPC.
  enable_dns_hostnames = true

  # Enable/disable ClassicLink for the VPC.
  enable_classiclink = false

  # Enable/disable ClassicLink DNS Support for the VPC.
  enable_classiclink_dns_support = false

  # Requests an Amazon-provided IPv6 CIDR block with a /56 prefix length for the VPC.
  assign_generated_ipv6_cidr_block = false

  tags = tomap({
    "Name"                                      = "${var.vpc_name}",
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared",
  })
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC id."
  # Setting an output value as sensitive prevents Terraform from showing its value in plan and apply.
  sensitive = false
}

# Resource: aws_subnet
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet

resource "aws_subnet" "main_public" {
  count = 2
  
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  # The CIDR block for the public subnet
  cidr_block              = "10.100.${count.index + 1}.0/24"

  # Required for EKS. Instances launched into the subnet should be assigned a public IP address.
  map_public_ip_on_launch = true

  tags = tomap({
    "Name"                                      = "${var.eks_cluster_name}-public-${count.index + 1}",
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared",
    "kubernetes.io/role/elb"                    = 1
  })
}

resource "aws_subnet" "main_private" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  # The CIDR block for the private subnet prefix with 1
  cidr_block              = "10.100.1${count.index + 1}.0/24"

  tags = tomap({
    "Name"                                      = "${var.eks_cluster_name}-private-${count.index + 1}",
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared",
    "kubernetes.io/role/internal-elb"           = 1
  })
}


# Resource: aws_internet_gateway
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main.id

  tags = tomap({
    "Name" = "${var.eks_cluster_name}-igw",
  })
}

# Resource: aws_eip
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip

resource "aws_eip" "main_eip" {
  count = 2
  # EIP may require IGW to exist prior to association. 
  # Use depends_on to set an explicit dependency on the IGW.
  depends_on = [aws_internet_gateway.main_igw]
  tags = tomap({
    "Name" = "${var.eks_cluster_name}-eip-${count.index}",
  })
}

# Resource: aws_nat_gatway
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway

resource "aws_nat_gateway" "main_nat" {
  count = 2
  # The Allocation ID of the Elastic IP address for the gateway.
  allocation_id = aws_eip.main_eip.*.id[count.index]

  # The Subnet ID of the subnet in which to place the gateway.
  subnet_id = aws_subnet.main_public.*.id[count.index]

  tags = tomap({
    "Name" = "${var.eks_cluster_name}-nat-${count.index + 1}",
  })
}

# Resource: aws_route_table
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table

resource "aws_route_table" "main_public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  # A map of tags to assign to the resource.
  tags = tomap({
    "Name" = "${var.eks_cluster_name}-public",
  })
}

resource "aws_route_table" "main_private" {
  count = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"

    # Identifier of a VPC NAT gateway.
    nat_gateway_id = aws_nat_gateway.main_nat.*.id[count.index]
  }

  tags = tomap({
    "Name" = "${var.eks_cluster_name}-private-${count.index + 1}",
  })
}

# Resource: aws_route_table_association
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association

resource "aws_route_table_association" "main_public" {
  count = 2
  # The subnet ID to create an association.
  subnet_id = aws_subnet.main_public.*.id[count.index]

  # The ID of the routing table to associate with.
  route_table_id = aws_route_table.main_public.id
}

resource "aws_route_table_association" "main_private" {
  count = 2
  # The subnet ID to create an association.
  subnet_id = aws_subnet.main_private.*.id[count.index]

  # The ID of the routing table to associate with.
  route_table_id = aws_route_table.main_private.*.id[count.index]
}
