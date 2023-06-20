provider "aws" {
  # The AWS region in which all resources will be created
  region = var.aws_region

  # Require a 2.x version of the AWS provider
  version = "~> 2.6"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = [var.aws_account_id]
}

terraform {
  # The configuration for this backend will be filled in by Terragrunt or via a backend.hcl file. See
  # https://www.terraform.io/docs/backends/config.html#partial-configuration
  backend "s3" {}

  # Only allow this Terraform version. Note that if you upgrade to a newer version, Terraform won't allow you to use an
  # older version, so when you upgrade, you should upgrade everyone on your team and your CI servers all at once.
  required_version = "~> 0.15.4"
}

module "eks_cluster" {
  # Make sure to replace <VERSION> in this URL with the latest terraform-aws-eks release
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-cluster-control-plane?ref=v0.40.0"

  cluster_name = var.cluster_name

  vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
  vpc_master_subnet_ids = data.terraform_remote_state.vpc.outputs.private_app_subnet_ids

  enabled_cluster_log_types = ["api", "audit", "authenticator"]
  kubernetes_version        = 1.20
  endpoint_public_access    = true
}

module "eks_workers" {
  # Make sure to replace <VERSION> in this URL with the latest terraform-aws-eks release
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-cluster-workers?ref=v0.40.0"

  name_prefix  = "app-workers-"
  cluster_name = var.cluster_name

  vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
  vpc_worker_subnet_ids = data.terraform_remote_state.vpc.outputs.private_app_subnet_ids

  eks_master_security_group_id = module.eks_cluster.eks_master_security_group_id

  cluster_min_size = var.cluster_min_size
  cluster_max_size = var.cluster_max_size

  cluster_instance_ami          = var.cluster_instance_ami
  cluster_instance_type         = var.cluster_instance_type
  cluster_instance_keypair_name = var.cluster_instance_keypair_name
  cluster_instance_user_data    = data.template_file.user_data.rendered
}

data "template_file" "user_data" {
  template = file("${path.module}/user-data/user-data.sh")

  vars = {
    aws_region                = var.aws_region
    eks_cluster_name          = var.cluster_name
    eks_endpoint              = module.eks_cluster.eks_cluster_endpoint
    eks_certificate_authority = module.eks_cluster.eks_cluster_certificate_authority
    vpc_name                  = var.vpc_name
    log_group_name            = var.cluster_name
  }
}

module "cloudwatch_log_aggregation" {
  # Make sure to replace <VERSION> in this URL with the latest module-aws-monitoring release
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/logs/cloudwatch-log-aggregation-iam-policy?ref=v0.27.0"

  name_prefix = var.cluster_name
}

resource "aws_iam_policy_attachment" "attach_cloudwatch_log_aggregation_policy" {
  name       = "attach-cloudwatch-log-aggregation-policy"
  roles      = [module.eks_workers.eks_worker_iam_role_name]
  policy_arn = module.cloudwatch_log_aggregation.cloudwatch_log_aggregation_policy_arn
}

module "cloudwatch_metrics" {
  # Make sure to replace <VERSION> in this URL with the latest module-aws-monitoring release
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-custom-metrics-iam-policy?ref=v0.27.0"

  name_prefix = var.cluster_name
}

resource "aws_iam_policy_attachment" "attach_cloudwatch_metrics_policy" {
  name       = "attach-cloudwatch-metrics-policy"
  roles      = [module.eks_workers.eks_worker_iam_role_name]
  policy_arn = module.cloudwatch_metrics.cloudwatch_metrics_policy_arn
}

module "high_cpu_usage_alarms" {
  # Make sure to replace <VERSION> in this URL with the latest module-aws-monitoring release
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-cpu-alarms?ref=v0.27.0"

  asg_names            = [module.eks_workers.eks_worker_asg_id]
  num_asg_names        = 1
  alarm_sns_topic_arns = [data.terraform_remote_state.sns_region.outputs.arn]
}

module "high_memory_usage_alarms" {
  # Make sure to replace <VERSION> in this URL with the latest module-aws-monitoring release
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-memory-alarms?ref=v0.27.0"

  asg_names            = [module.eks_workers.eks_worker_asg_id]
  num_asg_names        = 1
  alarm_sns_topic_arns = [data.terraform_remote_state.sns_region.outputs.arn]
}

module "high_disk_usage_alarms" {
  # Make sure to replace <VERSION> in this URL with the latest module-aws-monitoring release
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-disk-alarms?ref=v0.27.0"

  asg_names            = [module.eks_workers.eks_worker_asg_id]
  num_asg_names        = 1
  file_system          = "/dev/xvda1"
  mount_path           = "/"
  alarm_sns_topic_arns = [data.terraform_remote_state.sns_region.outputs.arn]
}

module "eks_k8s_role_mapping" {
  # Make sure to replace <VERSION> in this URL with the latest terraform-aws-eks release
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-k8s-role-mapping?ref=v0.40.0"

  # This will configure the worker nodes' IAM role to have access to the system:node Kubernetes role
  eks_worker_iam_role_arns = [module.eks_workers.eks_worker_iam_role_arn]

  # The IAM role to Kubernetes role mappings are passed in via a variable
  iam_role_to_rbac_group_mappings = var.iam_role_to_rbac_group_mappings

  config_map_labels = {
    eks-cluster = module.eks_cluster.eks_cluster_name
  }
}

provider "kubernetes" {
  version = "~> 2.0"

  load_config_file       = false
  host                   = data.template_file.kubernetes_cluster_endpoint.rendered
  cluster_ca_certificate = base64decode(data.template_file.kubernetes_cluster_ca.rendered)
  token                  = data.aws_eks_cluster_auth.kubernetes_token.token
}

# Workaround for Terraform limitation where you cannot directly set a depends on directive or interpolate from resources
# in the provider config.
# Specifically, Terraform requires all information for the Terraform provider config to be available at plan time,
# meaning there can be no computed resources. We work around this limitation by creating a template_file data source
# that does the computation.
# See https://github.com/hashicorp/terraform/issues/2430 for more details
data "template_file" "kubernetes_cluster_endpoint" {
  template = module.eks_cluster.eks_cluster_endpoint
}

data "template_file" "kubernetes_cluster_ca" {
  template = module.eks_cluster.eks_cluster_certificate_authority
}

data "aws_eks_cluster_auth" "kubernetes_token" {
  name = module.eks_cluster.eks_cluster_name
}

resource "aws_security_group_rule" "openvpn_server_control_plane_access" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks_cluster.eks_master_security_group_id
  # Replace <SECURITY_GROUP_ID> with the ID of a security group from which SSH access should be allowed. E.g., If you
  # are running a VPN server, you could use a terraform_remote_state data source to fetch its security group ID and
  # fill it in here.
  source_security_group_id = "sg-0e5e0550afbccfffd"
}

module "dns_forwarder_rule" {
  # Make sure to replace <VERSION> in this URL with the latest terraform-aws-eks release
  source = "git::git@github.com:gruntwork-io/module-vpc.git//modules/vpc-dns-forwarder-rules?ref=v0.15.4"

  vpc_id                                        = data.terraform_remote_state.mgmt_vpc.outputs.vpc_id
  origin_vpc_route53_resolver_endpoint_id       = data.terraform_remote_state.vpc.outputs.origin_vpc_route53_resolver_endpoint_id
  destination_vpc_route53_resolver_primary_ip   = data.terraform_remote_state.vpc.outputs.destination_vpc_route53_resolver_primary_ip
  destination_vpc_route53_resolver_secondary_ip = data.terraform_remote_state.vpc.outputs.destination_vpc_route53_resolver_secondary_ip

  num_endpoints_to_resolve = 1
  endpoints_to_resolve = [
    # endpoint returned here is of the form https://DOMAIN. We want just the domain, so we chop off the https
    replace(lower(module.eks_cluster.eks_cluster_endpoint), "https://", ""),
  ]
}

resource "aws_security_group_rule" "allow_inbound_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = module.eks_workers.eks_worker_security_group_id
  # Replace <SECURITY_GROUP_ID> with the ID of a security group from which SSH access should be allowed. E.g., If you
  # are running a VPN server, you could use a terraform_remote_state data source to fetch its security group ID and
  # fill it in here.
  source_security_group_id = "sg-0e5e0550afbccfffd"
}

module "iam_policies" {
  # Make sure to replace <VERSION> in this URL with the latest terraform-aws-eks release
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/iam-policies?ref=v0.49.0"

  aws_account_id = var.aws_account_id

  # ssh-grunt is an automated app, so we can't use MFA with it
  iam_policy_should_require_mfa   = false
  trust_policy_should_require_mfa = false

  # If your IAM users are defined in a separate AWS account (e.g., a security account), you can pass in the ARN of
  # of that account via an input variable, and the IAM policy will give the worker nodes permission to assume that
  # IAM role
  allow_access_to_other_account_arns = [var.external_account_ssh_grunt_role_arn]
}

resource "aws_iam_role_policy" "ssh_grunt_permissions" {
  name   = "ssh-grunt-permissions"
  role   = module.eks_workers.eks_worker_iam_role_name
  policy = module.iam_policies.allow_access_to_other_accounts[0]
}


