variable "custom_input"{
    description = "Enter the source file"
    default = "main.tfvars.json"
}
locals {
  #json_data = jsondecode(file("main.tfvars.json")).VirtualMachine
  json_data = jsondecode(file("${terraform.workspace}${var.custom_input}")).VirtualMachine

  all_linux_vm = { for k, v in local.json_data : k => v
    if v.Type == "Linux"
  }
  all_linux_vm_disk = { for entry in flatten([
    for key, data in local.all_linux_vm : [
      for dk, disk in lookup(data, "Disk", []) : merge({
        vm_name = key
        lun     = dk + 1
      }, disk)
    ] if lookup(data, "Disk", []) != []
  ]) : entry.Name => entry }
#"${entry.vm_name}_${entry.Name}" => entry }

}

data "azurerm_proximity_placement_group" "linux_ppg" {
  for_each =  { for k in local.lz.PPG : k.Name => k}
  name                = each.value.Name
  resource_group_name = each.value.Resourcegroup_Name
}

#---------------------------------------
# Linux Virutal machine
#---------------------------------------

resource "azurerm_linux_virtual_machine" "linux_vm" {
  for_each                        = local.all_linux_vm
  #name                            = each.value.VMName
  name                            = each.key
  location                        = each.value.location
  resource_group_name             = each.value.resource_group_name
  size                            = each.value.vm_size
  computer_name                   = each.value.HostName
  admin_username      = each.value.admin_username
  proximity_placement_group_id  =  lookup(each.value,"PPG_ID",null)!=null? data.azurerm_proximity_placement_group.linux_ppg[each.value.PPG_ID].id:null
  disable_password_authentication = lookup(each.value, "generate_admin_ssh_key", true)
  network_interface_ids           = [azurerm_network_interface.nic[each.key].id]
  source_image_id                 = lookup(each.value,"source_image_id",null) 
  tags     = merge(local.lz.Tags[0],{
    Resourcetype="VirtualMachine Linux"
  })
  admin_ssh_key {
    username   = each.value.admin_username
    public_key = file("id_rsa.pub")
    #public_key = file("privatekey.ppk")
  }


  dynamic "source_image_reference" {
    for_each = (lookup(each.value, "storage_image_reference", {}) != {} && lookup(each.value, "source_image_id", null) == null) ? [1] : []
    content {
      publisher = lookup(each.value.storage_image_reference, "publisher", "suse")
      offer     = lookup(each.value.storage_image_reference, "offer", "sles-sap-12-sp5")
      sku       = lookup(each.value.storage_image_reference, "sku", "gen2")
      version   = lookup(each.value.storage_image_reference, "version", "latest")
    }
  }

  #allow_extension_operations = true
  
    #availability_set_id              = lookup(each.value,"availability_set",null)!=null? data.azurerm_availability_set.vm_availability_set[each.value.availability_set].id:null
  
    #availability_set_id              = lookup(each.value,"availability_set",null)
  
    

  os_disk {
    name                 = format("%s-osdisk", trimsuffix(each.value.VMName, "-vm"))
    storage_account_type = lookup(each.value.OS_Disk, "Type", "Standard_LRS")
    disk_size_gb         = lookup(each.value.OS_Disk, "Size", null)
    caching              = "ReadWrite"
    
  }


#*****************************
    dynamic "boot_diagnostics" {
        for_each = lookup(each.value, "boot_diagnostic_storage_account",null) != null ? [1] : []
        content {
                  storage_account_uri  = format("https://%s.blob.core.windows.net/",lookup(each.value, "boot_diagnostic_storage_account")) 
                  
                }
    }

  lifecycle {
    ignore_changes = [
      network_interface_ids, availability_set_id, dedicated_host_id
    ]
  }

}

resource "azurerm_managed_disk" "linux_vm_disk" {
  for_each             = local.all_linux_vm_disk
  name                 = each.key
  location             = azurerm_linux_virtual_machine.linux_vm[each.value.vm_name].location
  resource_group_name  = azurerm_linux_virtual_machine.linux_vm[each.value.vm_name].resource_group_name
  storage_account_type = each.value.Type
  create_option        = lookup(each.value,"create_option","Empty")
  disk_size_gb         = each.value.Size
  tags     = merge(local.lz.Tags[0],{
    Resourcetype="Managed Disk"
  })
}


resource "azurerm_virtual_machine_data_disk_attachment" "linux_vm_disk_attachment" {
  for_each = local.all_linux_vm_disk

  managed_disk_id    = azurerm_managed_disk.linux_vm_disk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.linux_vm[each.value.vm_name].id
  #The Logical Unit Number of the Data Disk, which needs to be unique within the Virtual Machine. 
  #Changing this forces a new resource to be created
  lun     = lookup(each.value, "lun", "1")
  caching = lookup(each.value,"Cache","None")

  lifecycle {
    ignore_changes = [
      managed_disk_id, virtual_machine_id
    ]
  }
}
/*
output "jumpip"{
  value = { for k in azurerm_public_ip.pip : k.ip_address => k
  }
}


output "jumpip"{
  value = { for k in azurerm_public_ip.pip : k.ip_address => k
           if v.Type == "Linux" }
  #value = {for k,v in local.all_linux_vm : k => v
  #      if lookup(v, "enable_public_ip_address",false)}
}

resource "azurerm_public_ip" "pip" {
for_each =  { for k,v in local.all_linux_vm : k => v
        if lookup(v, "enable_public_ip_address",false) 
    }

resource "null_resource" "vm_registration" {
      for_each = local.all_linux_vm
      connection {

      host        = azurerm_network_interface.nic[each.key].private_ip_address
      #host        = [azurerm_network_interface.nic[each.key].id]
      private_key = file("id_rsa")
      user        = each.value.admin_username
      
      #bastion_host        = "20.197.107.198"
      bastion_host        = azurerm_network_interface.nic[each.key].public_ip_address_id
      bastion_user        = each.value.admin_username
      bastion_private_key = file("id_rsa")
      timeout             = "120s"
    }
    provisioner "remote-exec" {
      inline = [
        #"SUSEConnect -r <ActivationCode> -e <EmailAddress>",
        "touch /tmp/janapb.txt",
        "hostname"
      ]
    }
     provisioner "remote-exec" {
      inline = [
        #"SUSEConnect -r <ActivationCode> -e <EmailAddress>",
        "touch /tmp/janapb.txt",
        "hostname"
      ]
    }
  }

  resource "null_resource" "testdeply" {
      for_each = local.all_linux_vm
      connection {

      host        = azurerm_network_interface.nic[each.key].private_ip_address
      #host        = [azurerm_network_interface.nic[each.key].id]
      private_key = file("id_rsa")
      user        = each.value.admin_username
      
      bastion_host        = "20.197.107.198"
      bastion_user        = each.value.admin_username
      bastion_private_key = file("id_rsa")
      timeout             = "120s"
    }
    provisioner "remote-exec" {
      inline = [
        #"SUSEConnect -r <ActivationCode> -e <EmailAddress>",
        "touch /tmp/janapb.txt",
        "hostname"
      ]
    }
    
  }



  resource "null_resource" "vm_registration6" {
      for_each = local.all_linux_vm
      connection {

      host        = azurerm_network_interface.nic[each.key].private_ip_address
      private_key = file("id_rsa")
      user        = each.value.admin_username
      
      #bastion_host        = "20.197.107.198"
      #bastion_host        = azurerm_linux_virtual_machine.linux_vm[each.value.bastion].public_ip_address
      
      bastion_host        = lookup(each.value,"bastion",null)!=null? azurerm_linux_virtual_machine.linux_vm[each.value.bastion].public_ip_address:"20.197.107.198"
      
      bastion_host         = data.azurerm_public_ip.test[each.value.bastion].ip_address
      bastion_user        = each.value.admin_username
      bastion_private_key = file("id_rsa")
      timeout             = "120s"
    }
     provisioner "remote-exec" {
      inline = [
        #"SUSEConnect -r <ActivationCode> -e <EmailAddress>",
        "touch /tmp/output2.txt",
        "hostname"
      ]
    }
  }
  */

  data "azurerm_public_ip" "test" {
  for_each =  { for k,v in local.all_vm_collection : k => v
        if lookup(v, "enable_public_ip_address",false) && v.Type == "Linux"
    }
  name                = format("%s-pip",each.key)
  resource_group_name = each.value.resource_group_name
}



/*
resource "null_resource" "vm_registration9" {
      for_each = local.all_linux_vm
      connection {

      host        = azurerm_network_interface.nic[each.key].private_ip_address
      private_key = file("id_rsa")
      user        = each.value.admin_username
      
      #bastion_host        = "20.197.107.198"
      #bastion_host        = azurerm_linux_virtual_machine.linux_vm[each.value.bastion].public_ip_address
      
      #bastion_host        = lookup(each.value,"bastion",null) !=null? azurerm_linux_virtual_machine.linux_vm[each.value.bastion].public_ip_address:null
     
      #proximity_placement_group_id  =  lookup(each.value,"PPG_ID",null)!=null? data.azurerm_proximity_placement_group.linux_ppg[each.value.PPG_ID].id:null
      
      
      #bastion_host        = lookup(each.value,"bastion",null)!=null ? azurerm_network_interface.nic[each.key].private_ip_address:azurerm_linux_virtual_machine.linux_vm[each.value.bastion].public_ip_address
      
      bastion_host         = data.azurerm_public_ip.test[lookup(each.value,"bastion","null")].ip_address
      
      #bastion_host         = data.azurerm_public_ip.test[agp-jmp-srv3-vm].ip_address
      bastion_user        = each.value.admin_username
      bastion_private_key = file("id_rsa")
      timeout             = "120s"
    }
     provisioner "remote-exec" {
      inline = [
        #"SUSEConnect -r <ActivationCode> -e <EmailAddress>",
        "touch /tmp/output4.txt",
        "touch /tmp/demo.txt",
        "hostname"
      ]
    }
  }
 
Try splat expression and use the for each in output.value = for k,v in data.azurermpublicip.test(*).ipaddress  : v.ipaddess

*/
output "testing"{
    value = { for k,v in data.azurerm_public_ip.test[*].ip_address : v.ip_address => k}
    
}