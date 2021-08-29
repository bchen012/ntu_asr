terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}

}

terraform {
  backend "azurerm" {
    resource_group_name = "ntu-online-scaled"
    storage_account_name = "ntuscaledstorage3"
    container_name = "tfstate"
    key = "prod.terraform.tfstate"
    sas_token = "sp=racwdl&st=2021-08-29T07:35:55Z&se=2021-12-31T15:35:55Z&sv=2020-08-04&sr=c&sig=fDaz17MBMNpUNqRySaMTlCbPrwh8Y%2BKj7yE1CkEH7eo%3D"
  }
}
