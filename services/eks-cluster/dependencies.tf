data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    region = var.terraform_state_aws_region
    bucket = var.terraform_state_s3_bucket
    key    = "dev/${var.aws_region}/dev/networking/vpc/terraform.tfstate"
  }
}

data "terraform_remote_state" "sns_region" {
  backend = "s3"
  config = {
    region = var.terraform_state_aws_region
    bucket = var.terraform_state_s3_bucket
    key    = "dev/${var.aws_region}/_regional/sns-topic/terraform.tfstate"
  }
}

data "terraform_remote_state" "mgmt_vpc" {
  backend = "s3"
  config = {
    region = var.terraform_state_aws_region
    bucket = var.terraform_state_s3_bucket
    key    = "dev/${var.aws_region}/mgmt/vpc-mgmt/terraform.tfstate"
  }
}
