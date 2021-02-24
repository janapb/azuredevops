
locals {
  lz = jsondecode(file("lz_input.json"))

}

#Creates PPG
resource "azurerm_proximity_placement_group" "lz_ppg" {
  for_each =  { for k in local.lz.PPG : k.Name => k}
  name                = each.value.Name
  location            = each.value.Region
  resource_group_name = each.value.Resourcegroup_Name
}

#Creates Security Vault 
resource "azurerm_recovery_services_vault" "lz_vault" {
for_each =  { for k in local.lz.RecoveryServicesVault : k.Name => k}
  name                = each.value.Name
  location            = each.value.Region
  resource_group_name = each.value.Resourcegroup_Name
  sku                 = each.value.sku
  #storage_replication_type = "LocallyRedundant"
  soft_delete_enabled = true
}

# Creates Virtual Networks 
resource "azurerm_virtual_network" "lz_vnet" {
  for_each =  { for k in local.lz.Vnet : k.Vnet => k}
  name                = each.value.Vnet_Name
  location            = each.value.Region
  resource_group_name = each.value.Resourcegroup_Name
  address_space       = [each.value.Addres_Space]
  tags     = merge(local.lz.Tags[0],{
    Resourcetype="VirtualNetwork"
  })
  }

    
# Creates Subnets 
resource "azurerm_subnet" "lz_subnet" {
  for_each =  { for k in local.lz.Subnet : k.Subnet_Name => k}
  name                 = each.value.Subnet_Name
  resource_group_name  = each.value.Resourcegroup_Name
  virtual_network_name = each.value.Vnet_Name
  address_prefixes     = [each.value.Address_Space]
  depends_on = [azurerm_virtual_network.lz_vnet]
}

# Creates Network Security Group  
resource "azurerm_network_security_group" "lz_nsg" {
  for_each =  { for k in local.lz.Subnet : k.Subnet_Name => k}
  name                = each.value.NSG
  location            = each.value.Region
  resource_group_name = each.value.Resourcegroup_Name
  tags     = merge(local.lz.Tags[0],{
    Resourcetype="NSG"
  })

}

resource "azurerm_subnet_network_security_group_association" "lz_nsg_association" {
  for_each =  { for k in local.lz.Subnet : k.Subnet_Name => k}
  subnet_id                 = azurerm_subnet.lz_subnet[each.key].id
  network_security_group_id = azurerm_network_security_group.lz_nsg[each.key].id
  depends_on = [azurerm_network_security_group.lz_nsg]
}


data "azurerm_virtual_network" "example"{
  for_each =  { for k in local.lz.Peering : k.Name => k}
  name                = each.value.Remote_virtual_network
  resource_group_name = each.value.Remote_Resourcegroup_Name
  depends_on = [azurerm_virtual_network.lz_vnet]
}

# Peering of Hub VNET to Spoke VNET
resource "azurerm_virtual_network_peering" "Hub-Spoke_Peer" {
  for_each =  { for k in local.lz.Peering : k.Name => k}
  name                         = each.value.Name
  resource_group_name          = each.value.Resourcegroup_Name
  virtual_network_name         = each.value.Vnet_Name
  remote_virtual_network_id    = data.azurerm_virtual_network.example[each.key].id
  allow_virtual_network_access = each.value.Allow_virtual_network_access
  allow_forwarded_traffic      = each.value.Allow_forwarded_traffic
  depends_on = [azurerm_virtual_network.lz_vnet]
}

locals {
  security_group_rules = csvdecode(file("rules.csv"))
}

resource "azurerm_network_security_rule" "lz_nsg_rules" {
  for_each = { for inst in local.security_group_rules : inst.name => inst }
  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port
  destination_port_ranges     = split(",", each.value.destination_port)
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = each.value.resource_group_name
  network_security_group_name = each.value.network_security_group_name
  depends_on = [azurerm_network_security_group.lz_nsg]
}
