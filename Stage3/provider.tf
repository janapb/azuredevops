# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  #version         = "=2.20.0"
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id

  features {}
}



# Backend for softwareonedev
terraform {
  backend "azurerm" {
    tenant_id       = "d892a081-1f19-49f6-94c3-2ef56720126e"
    subscription_id = "249a3bf8-18cc-4f88-ab0e-77e87f943d8c"
    #tenant_id       = var.tenant_id
    #subscription_id = var.subscription_id
    resource_group_name  = "agp-tf-rg"
    storage_account_name = "tfstorageaccdev"
    container_name       = "tstate-dev-cont"
    key                  = "terraform.tfstate"
  }
}

