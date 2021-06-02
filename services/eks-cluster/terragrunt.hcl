terraform {
  source = "git@github.com/arunms003/eks-cluster-test.git//services/eks-cluster?ref=v1.2"
}

inputs = {
  cluster_name                  = "cifarm-sandy-arun"
  cluster_instance_keypair_name = "cifarm-sandy-arun"

  # Fill in the ID of the AMI you built from your Packer template
  cluster_instance_ami          = "ami-0b8242962dce1e523"

  # Set the max size to double the min size so the extra capacity can be used to do a zero-downtime deployment of updates
  # to the EKS Cluster Nodes (e.g. when you update the AMI). For docs on how to roll out updates to the cluster, see:
  # https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-cluster-workers#how-do-i-roll-out-an-update-to-the-instances
  cluster_min_size      = 3
  cluster_max_size      = 6
  cluster_instance_type = "t2.medium"

  # If your IAM users are defined in a separate AWS account (e.g., in a security account), pass in the ARN of an IAM
  # role in that account that ssh-grunt on the worker nodes can assume to look up IAM group membership and public SSH
  # keys
  external_account_ssh_grunt_role_arn = "arn:aws:iam::960729387024:role/allow-ssh-grunt-access-from-other-accounts"

  # Configure your role mappings
  iam_role_to_rbac_group_mappings = {
    # Give anyone using the full-access IAM role admin permissions
    "arn:aws:iam::787447885853:role/allow-full-access-from-other-accounts" = ["system:masters"]

    # Give anyone using the developers IAM role developer permissions. Kubernetes will automatically create this group
    # if it doesn't exist already, but you're still responsible for binding permissions to it!
    "arn:aws:iam::787447885853:role/allow-full-access-from-other-accounts" = ["developers"]
  }
}

