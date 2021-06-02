variable "cluster_name" {
  description = "The name of the EKS cluster (e.g. eks-prod). This is used to namespace all the resources created by these templates."
  type        = string
  default     = "cifarm-sandy-arun"
}

variable "vpc_id" {
  description = "The ID of the VPC in which the EKS Cluster's EC2 Instances will reside."
  type        = string
  default     = "vpc-06b2d61182ffa0753"
}

variable "private_app_subnet_ids" {
  description = "A list of the subnets into which the EKS Cluster's control plane nodes will be launched. These should usually be all private subnets and include one in each AWS Availability Zone."
  type        = list(string)
  default     = ["subnet-0d5a5a08ee33ce1b6", "subnet-0a3de59b378ce153a", "subnet-0b3a4680fd6c119d0", "subnet-095eea03edab48071"]
}

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
  type        = string
  default     = "us-west-2"
}

variable "aws_account_id" {
  description = "The ID of the AWS Account in which to create resources."
  type        = string
  default     = "787447885853"
}

variable "vpc_name" {
  description = "The name of the VPC in which to run the EKS cluster (e.g. stage, prod)"
  type        = string
  default     = "app"
}

variable "terraform_state_aws_region" {
  description = "The AWS region of the S3 bucket used to store Terraform remote state"
  type        = string
  default     = "us-west-2"
}

variable "terraform_state_s3_bucket" {
  description = "The name of the S3 bucket used to store Terraform remote state"
  type        = string
  default     = "mfpoc-dev-us-west-2-tf-state"
}

variable "cluster_min_size" {
  description = "The minimum number of instances to run in the EKS cluster"
  type        = number
  default     = "1"
}

variable "cluster_max_size" {
  description = "The maximum number of instances to run in the EKS cluster"
  type        = number
  default     = "2"
}

variable "cluster_instance_type" {
  description = "The type of instances to run in the EKS cluster (e.g. t2.medium)"
  type        = string
  default     = "t2.medium"
}

variable "cluster_instance_ami" {
  description = "The AMI to run on each instance in the EKS cluster. You can build the AMI using the Packer template under packer/build.json."
  type        = string
  default     = "ami-0b8242962dce1e523"
}

variable "cluster_instance_keypair_name" {
  description = "The name of the Key Pair that can be used to SSH to each instance in the EKS cluster"
  type        = string
  default     = "cifarm-sandy-arun"
}

variable "iam_role_to_rbac_group_mappings" {
  description = "Mapping of AWS IAM roles to RBAC groups, where the keys are the AWS ARN of IAM roles and the values are the mapped k8s RBAC group names as a list."
  type        = map(list(string))
  default     = {}
}


