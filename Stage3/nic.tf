locals {
  lz = jsondecode(file("lz_input.json"))
}

#azurerm_storage_account.vm-sa.*.primary_blob_endpoint
data "azurerm_subnet" "vm_subnet" {
  for_each             = local.all_subnet
  name                 = each.value.subnet
  virtual_network_name = each.value.virtual_network
  resource_group_name  = each.value.resource_group_name
}

/*
output "networkid"{
    value =[azurerm_network_interface.nic]
}
*/