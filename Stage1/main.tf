locals {
  lz = jsondecode(file("lz_input.json"))
}

# Create a resource group
resource "azurerm_resource_group" "lz_rg" {
  for_each =  { for k in local.lz.ResourceGroup : k.Env => k}
  name = each.value.Name
  location = each.value.Region
  tags     = merge(local.lz.Tags[0],{
  Resourcetype="ResourceGroup"
  })
}

resource "azurerm_storage_account" "storage" {
  for_each =  { for k in local.lz.Storage : k.Storagename => k}
  name                     = each.value.Storagename
  resource_group_name      = each.value.Resourcegroup_Name
  location                 = each.value.Region
  account_tier             = each.value.Account_tier
  account_replication_type = each.value.Replication_type
depends_on = [azurerm_resource_group.lz_rg]
}

resource "azurerm_storage_container" "example" {
  for_each =  { for k in local.lz.Storage : k.Storagename => k}
  name                  = each.value.Containername
  storage_account_name  = each.value.Storagename
  container_access_type = each.value.Access_Type
depends_on = [azurerm_storage_account.storage]
}


