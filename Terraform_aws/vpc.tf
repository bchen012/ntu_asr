variable "region" {
  default     = "ap-southeast-1"
  description = "AWS region"
}


data "aws_availability_zones" "available" {}

locals {
  cluster_name = "asr_cluster"
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}


# Create a VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.66.0"

  name                 = "asr-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets       = ["10.0.3.0/24", "10.0.4.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "Tier"                                        = "public"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "Tier"                                        = "private"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}


terraform {
  backend "azurerm" {
    resource_group_name = "ntu-online-scaled"
    storage_account_name = "ntuscaledstorage3"
    container_name = "tfstate"
    key = "prod.aws.tfstate"
    sas_token = "sp=racwdl&st=2021-08-29T07:35:55Z&se=2021-12-31T15:35:55Z&sv=2020-08-04&sr=c&sig=fDaz17MBMNpUNqRySaMTlCbPrwh8Y%2BKj7yE1CkEH7eo%3D"
  }
}