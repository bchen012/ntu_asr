//terraform import aws_iam_policy.AmazonEKS_EFS_CSI_Driver_Policy arn:aws:iam::861814105207:policy/AmazonEKS_EFS_CSI_Driver_Policy

resource "aws_iam_policy" "AmazonEKS_EFS_CSI_Driver_Policy" {
  name        = "AmazonEKS_EFS_CSI_Driver_Policy"
  path        = "/"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
  Version: "2012-10-17",
  Statement: [
    {
      Effect: "Allow",
      Action: [
        "elasticfilesystem:DescribeAccessPoints",
        "elasticfilesystem:DescribeFileSystems"
      ],
      Resource: "*"
    },
    {
      Effect: "Allow",
      Action: [
        "elasticfilesystem:CreateAccessPoint"
      ],
      Resource: "*",
      Condition: {
        StringLike: {
          "aws:RequestTag/efs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      Effect: "Allow",
      Action: "elasticfilesystem:DeleteAccessPoint",
      Resource: "*",
      Condition: {
        StringEquals: {
          "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
        }
      }
    }
  ]
  })
}

data "aws_caller_identity" "current" {}


locals {
  DriverRole_name = "AmazonEKS_EFS_CSI_DriverRole"
}


resource "aws_iam_role" "AmazonEKS_EFS_CSI_DriverRole" {
  name = local.DriverRole_name

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
  Version: "2012-10-17",
  Statement: [
    {
      Effect: "Allow",
      Principal: {
        Federated: "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer,"https://","")}"
      },
      Action: "sts:AssumeRoleWithWebIdentity",
      Condition: {
        StringEquals: {
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer,"https://","")}:sub": "system:serviceaccount:kube-system:efs-csi-controller-sa"
        }
      }
    }
  ]
})
}


resource "aws_iam_role_policy_attachment" "Driver_Policy_to_Driver_Role" {
  role      = aws_iam_role.AmazonEKS_EFS_CSI_DriverRole.name
  policy_arn = aws_iam_policy.AmazonEKS_EFS_CSI_Driver_Policy.arn
}


resource "aws_security_group" "MyEfsSecurityGroup" {
  name = "MyEfsSecurityGroup"
  description = "My EFS security group"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = [module.vpc.vpc_cidr_block]
  }
}
