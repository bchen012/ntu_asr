resource "kubernetes_service_account" "efs-service-accoount" {
  metadata {
    name = "efs-csi-controller-sa"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "aws-efs-csi-driver"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.DriverRole_name}"
    }
  }
}


resource "kubernetes_storage_class" "efs_storageclass" {
  metadata {
    name = "efs-sc"
  }

  storage_provisioner = "efs.csi.aws.com"
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId = data.aws_efs_file_system.asr-efs.file_system_id
    directoryPerms = "700"
  }
}