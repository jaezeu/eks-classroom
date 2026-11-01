# Add more user groups if required to grant admin access since this is sandbox account
data "aws_iam_group" "students" {
  group_name = "sctp-cloud-ce13"
}

data "aws_iam_group" "instructor" {
  group_name = "instructor"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_route53_zone" "base" {
  name         = "sctp-sandbox.com"
  private_zone = false
}
