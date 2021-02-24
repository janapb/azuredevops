data "azurerm_resource_group" "rg" {
  count = length(local.lz.ResourceGroup)
  name = lookup(element(local.lz.ResourceGroup,count.index),"Name")
}

output "resource_group_tags"{
    value = data.azurerm_resource_group.rg.*.tags
}
/*
output "jumpbox_ip"{
  value = azurerm_windows_virtual_machine.win_vm[*].private_ip_addresses
}



output "app_ip" {
  value = azurerm_network_interface.app[*].private_ip_address
}

output "app_admin_ip" {
  value = azurerm_network_interface.app_admin[*].private_ip_address
}


resource "null_resource" remoteExecProvisionerWFolder {

  provisioner "file" {
    source      = "TESTING.txt"
    destination = "C:/"
  }

  connection {
    host     = "agp-dev-jmp1-vm"
    type     = "winrm"
    user     = "swo_admin"
    password = "Password#123"
  }
}
*/