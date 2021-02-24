
#-----------------------------------
# Public IP for Virtual Machine
#-----------------------------------
resource "azurerm_public_ip" "pip" {
for_each =  { for k,v in local.all_vm_collection : k => v
        if lookup(v, "enable_public_ip_address",false) 
    }
  
  name                = format("%s-pip",each.key)
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  #domain_name_label   = format("%s-pip",each.key)
  tags     = merge(local.lz.Tags[0],{
    Resourcetype="PublicIP"
  })
}
/*
output "networkid"{
    value =[azurerm_network_interface.nic]
}
*/
#---------------------------------------
# Network Interface for Virtual Machine
#---------------------------------------
resource "azurerm_network_interface" "nic" {
for_each = local.all_vm_collection

  name                          =  format("%s-nic",trimsuffix(each.value.VMName, "-vm"))
  location                      = each.value.location
  resource_group_name           = each.value.resource_group_name
  dns_servers                   = lookup(each.value,"dns_servers",[])
  enable_ip_forwarding          = lookup(each.value,"enable_ip_forwarding",false)
  enable_accelerated_networking = lookup(each.value,"enable_accelerated_networking",false)
  tags     = merge(local.lz.Tags[0],{
    Resourcetype="NIC Card"
  })

dynamic "ip_configuration" {
    for_each = {
        for i, j in lookup(each.value,"ip_configuration",[]):"${each.key}-${j.name}"=> merge({
            index = i+1
            vm_name   = each.key
            virtual_network      = each.value.virtual_network
            subnet    = each.value.subnet
            name =  j.name
            ip_address = lookup(j,"ip_address",null)
            ip_address_allocation =lookup(j,"ip_address_allocation","Dynamic")
        },)
        if lookup(each.value,"ip_configuration",[]) !=[]
    }
content{ 
        primary                       = ip_configuration.value.index!=1? false : true
        name                          = ip_configuration.value.name
        subnet_id                     = data.azurerm_subnet.vm_subnet["${ip_configuration.value.virtual_network}-${ip_configuration.value.subnet}"].id
        private_ip_address_allocation = ip_configuration.value.ip_address ==null ? "Dynamic" : ip_configuration.value.ip_address_allocation
        private_ip_address            = ip_configuration.value.ip_address
        public_ip_address_id          = lookup(each.value, "enable_public_ip_address",false) == true ? azurerm_public_ip.pip[each.key].id:null
        
        
    }
  }

 /* lifecycle {
    ignore_changes = [
      ip_configuration.*.subnet_id, ip_configuration.*.public_ip_address_id
    ]
  }*/

}


