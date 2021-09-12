data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}


data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}


provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}


module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = local.cluster_name
  cluster_version = "1.20"
  subnets         = module.vpc.private_subnets

  vpc_id = module.vpc.vpc_id


  node_groups = [
    {
      name                          = "asr_nodegroup"
      desired_capacity              = 0
      max_capacity                  = 3
      min_capacity                  = 0
      instance_types                 = ["t2.xlarge"]
      additional_tags               = {
        "kubernetes.io/cluster/${local.cluster_name}" = "owned"
      }
    }
  ]

}


//data "aws_efs_file_system" "asr-efs" {
//  file_system_id = "fs-f8d462b8"
//}

resource "aws_efs_file_system" "asr_efs" {
  tags = {
    "Name" = "asr-efs"
  }
}



resource "aws_efs_mount_target" "efs_mount" {
  count = 2
  file_system_id = data.aws_efs_file_system.asr-efs.file_system_id
  subnet_id      = element(module.vpc.private_subnets, count.index)
  security_groups = [aws_security_group.MyEfsSecurityGroup.id]
}