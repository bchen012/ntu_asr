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
        resource_group_name = "terraform-group 
        storage_account_name = "terraform-storage 
        container_name = "tfstate 
        key = "prod.azure.tfstate 
        sas_token = "sp=racwdl&st=2021-08-29T07:35:55Z&se=2021-12-31T15:35:55Z&sv=2020-08-04&sr=c&sig=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX 
    }
}
