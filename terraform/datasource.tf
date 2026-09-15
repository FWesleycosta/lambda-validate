data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_caller_identity" "current" {}
 
