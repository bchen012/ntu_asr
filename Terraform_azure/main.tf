resource "azurerm_resource_group" "resource_group" {
  name     = "ntu-online-scaled"
  location = "Southeast Asia"
}


resource "azurerm_storage_account" "storage_account" {
  name                     = "ntuscaledstorage3"
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


resource "azurerm_storage_share" "file_share" {
  name                 = "online-models"
  storage_account_name = azurerm_storage_account.storage_account.name
  quota = 50  # max size of file_share in Gb
}


resource "azurerm_storage_share" "jenkins_share" {
  name                 = "jenkins-share"
  storage_account_name = azurerm_storage_account.storage_account.name
  quota = 50  # max size of file_share in Gb
}


//resource "azurerm_kubernetes_cluster" "production" {
//  name                = "asr-production"
//  location            = azurerm_resource_group.resource_group.location
//  resource_group_name = azurerm_resource_group.resource_group.name
//  dns_prefix          = "asr"
//
//  default_node_pool {
//    name       = "default"
//    node_count = 1
//    vm_size    = "standard_d3" #standard_d3
//  }
//
//  identity {
//    type = "SystemAssigned"
//  }
//}
