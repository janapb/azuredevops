
locals {
  #json_data2 = jsondecode(file("main.tfvars.json")).VirtualMachine
json_data2 = jsondecode(file("${terraform.workspace}${var.custom_input}")).VirtualMachine

  all_windows_vm = { for k, v in local.json_data2 : k => v
    if v.Type == "Windows"
  }
  all_windows_vm_disk = { for entry in flatten([
    for key, data in local.all_windows_vm : [
      for dk, disk in lookup(data, "Disk", []) : merge({
        vm_name = key
        lun     = dk + 1
      }, disk)
    ] if lookup(data, "Disk", []) != []
  ]) : "${entry.vm_name}_${entry.Name}" => entry }

  all_vm_collection = { for k, v in local.json_data2 : k => v
  }

  all_subnet = { for entry in distinct([for v in local.all_vm_collection : {
    virtual_network     = v.virtual_network
    subnet              = v.subnet
    resource_group_name = lookup(v, "vnet_resource_group_name", v.resource_group_name)
  }]) : format("%s-%s", entry.virtual_network, entry.subnet) => entry }

}


#---------------------------------------
# Windows Virutal machine
#---------------------------------------
resource "azurerm_windows_virtual_machine" "win_vm" {
  for_each            = local.all_windows_vm
  name                = each.key
  computer_name       = each.key
  location            = each.value.location
  resource_group_name = each.value.resource_group_name

  size                       = each.value.vm_size
  admin_username             = "swo_admin"
  admin_password             = "Password#123"
  network_interface_ids      = [azurerm_network_interface.nic[each.key].id]
  source_image_id            = lookup(each.value, "source_image_id", null)
  allow_extension_operations = true
  /*source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  */
 dynamic "source_image_reference" {
    for_each = (lookup(each.value, "storage_image_reference",{}) != {} && lookup(each.value,"source_image_id",null)==null) ? [1] : []
      content {
      publisher = lookup(each.value.storage_image_reference,"publisher","MicrosoftWindowsServer") 
      offer     = lookup(each.value.storage_image_reference,"offer","WindowsServer") 
      sku       = lookup(each.value.storage_image_reference,"sku","2019-Datacenter")
      version   =  lookup(each.value.storage_image_reference,"version","latest")
    }
  }
  #availability_set_id              = lookup(each.value,"availability_set",null)!=null? data.azurerm_availability_set.vm_availability_set[each.value.availability_set].id:null
  #availability_set_id              = lookup(each.value,"availability_set",null)

  lifecycle {
    ignore_changes = [
      availability_set_id, dedicated_host_id, network_interface_ids
    ]
  }
  
  


  os_disk {
    name                 = format("%s-osdisk", each.value.HostName)
    storage_account_type = lookup(each.value, "os_disk_storage_account_type", "Standard_LRS")
    disk_size_gb         = lookup(each.value, "os_disk_size_gb", null)
    caching              = "ReadWrite"
  }
  tags     = merge(local.lz.Tags[0],{
    Resourcetype="Virtual Machine"
  })

    dynamic "boot_diagnostics" {
        for_each = lookup(each.value, "boot_diagnostic_storage_account",null) != null ? [1] : []
        content {
                  #"https://wlprodeusmgmtdiagstr01.blob.core.windows.net/"
                  storage_account_uri  = format("https://%s.blob.core.windows.net/",lookup(each.value, "boot_diagnostic_storage_account")) 
                # data.azurerm_storage_account.storeacc[lookup(each.value, "boot_diagnostic_storage_account")].primary_blob_endpoint
        }
    
}
}

resource "azurerm_managed_disk" "vm_disk" {
  for_each = local.all_windows_vm_disk
  name                 = each.key
  location             = azurerm_windows_virtual_machine.win_vm[each.value.vm_name].location
  resource_group_name  = azurerm_windows_virtual_machine.win_vm[each.value.vm_name].resource_group_name
  storage_account_type = each.value.Type
  create_option        = lookup(each.value,"create_option","Empty")
  disk_size_gb         = each.value.Size
  tags     = merge(local.lz.Tags[0],{
    Resourcetype="Managed Disk"
  })
}

resource "azurerm_virtual_machine_data_disk_attachment" "vm_disk_attachment" {
  for_each = local.all_windows_vm_disk
  managed_disk_id    = azurerm_managed_disk.vm_disk[each.key].id
  virtual_machine_id = azurerm_windows_virtual_machine.win_vm[each.value.vm_name].id
  lun                = lookup(each.value,"lun","1")
  caching            = "ReadWrite"
  lifecycle {
    ignore_changes = [
      virtual_machine_id, managed_disk_id
    ]
  }
 }

