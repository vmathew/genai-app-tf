data "aws_vpc" "existing" {
  id = "vpc-061f4d9e6cb8dc071"
}

data "aws_subnet" "private" {
  id = "subnet-0f3914beddb6e5d87"
}

data "aws_subnet" "public" {
  id = "subnet-0d191982cafa55acb"
}

data "aws_subnet" "public_2" {
  id = "subnet-09572e38ebd0992a3"
}