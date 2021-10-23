# Random String Resource
resource "random_string" "myrandom" {
  length  = 6
  upper   = false
  special = false
  number  = false
}
#pull up resource group data from portal
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name

}


#pull up packer image data from portal

data "azurerm_image" "packer_image" {
  name                = var.packer_image_name
  resource_group_name = data.azurerm_resource_group.rg.name

}



# Create Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.resource_name_prefix}-${var.vnet_name}"
  address_space       = var.vnet_address_space
  location            = var.resource_group_location
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = local.common_tags
}

#create Network interface
resource "azurerm_network_interface" "web_linuxvm_nic" {
  count               = var.web_linuxvm_instance_count
  name                = "${local.resource_name_prefix}-web-linuxvm-nic-${count.index}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.resource_group_location

  ip_configuration {
    name                          = "web-linuxvm-ip-1"
    subnet_id                     = azurerm_subnet.websubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
#create a availaibility ser
resource "azurerm_availability_set" "ava_set_for_vm" {
  name                = "ava_set"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name

  tags = local.common_tags
  //platform_update_domain_count = 5
  //platform_fault_domain_count  = 5
  managed = true
}


# Create Virtual Network from packer iamage

resource "azurerm_virtual_machine" "vmss" {
  count                            = var.web_linuxvm_instance_count
  name                             = "${local.resource_name_prefix}-vmscaleset-${count.index}"
  location                         = var.location
  resource_group_name              = data.azurerm_resource_group.rg.name
  network_interface_ids            = [element(azurerm_network_interface.web_linuxvm_nic[*].id, count.index)]
  availability_set_id              = azurerm_availability_set.ava_set_for_vm.id
  vm_size                          = "Standard_DS12_v2"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true



  storage_image_reference {
    id = data.azurerm_image.packer_image.id
  }

  storage_os_disk {
    name              = "mydisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  storage_data_disk {
    name              = "datadisk_new"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = "1023"
  }
  os_profile {
    computer_name  = "vmlab"
    admin_username = var.admin_user
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = local.common_tags
}


# Resource-1: Create WebTier Subnet
resource "azurerm_subnet" "websubnet" {
  name                 = "${azurerm_virtual_network.vnet.name}-${var.web_subnet_name}"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.web_subnet_address
}

# Resource-2: Create Network Security Group (NSG)
resource "azurerm_network_security_group" "web_subnet_nsg" {
  name                = "${azurerm_subnet.websubnet.name}-nsg"
  location            = var.resource_group_location
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Resource-3: Associate NSG and Subnet
resource "azurerm_subnet_network_security_group_association" "web_subnet_nsg_associate" {
  depends_on                = [azurerm_network_security_rule.web_nsg_rule_inbound_22] # Every NSG Rule Association will disassociate NSG from Subnet and Associate it, so we associate it only after NSG is completely created - Azure Provider Bug https://github.com/terraform-providers/terraform-provider-azurerm/issues/354  
  subnet_id                 = azurerm_subnet.websubnet.id
  network_security_group_id = azurerm_network_security_group.web_subnet_nsg.id
}

# Resource-4: Create NSG Rules
## Locals Block for Security Rules

## NSG Inbound Rule for WebTier Subnets
resource "azurerm_network_security_rule" "web_nsg_rule_inbound_22" {
  //for_each                    = local.web_inbound_ports_map
  name                        = "Rule-Port-22"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web_subnet_nsg.name
}
resource "azurerm_network_security_rule" "web_nsg_rule_inbound_80" {
  //for_each                    = local.web_inbound_ports_map
  name                        = "Rule-Port-80"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "80"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web_subnet_nsg.name
}





# Resource-1: Create Public IP Address for Azure Load Balancer
resource "azurerm_public_ip" "web_lbpublicip" {
  name                = "${local.resource_name_prefix}-lbpublicip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.resource_group_location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# Resource-2: Create Azure Standard Load Balancer
resource "azurerm_lb" "web_lb" {
  name                = "${local.resource_name_prefix}-web-lb"
  location            = var.resource_group_location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "web-lb-publicip-1"
    public_ip_address_id = azurerm_public_ip.web_lbpublicip.id
  }
}

# Resource-3: Create LB Backend Pool
resource "azurerm_lb_backend_address_pool" "web_lb_backend_address_pool" {
  name            = "web-backend"
  loadbalancer_id = azurerm_lb.web_lb.id
}

# Resource-4: Create LB Probe
resource "azurerm_lb_probe" "web_lb_probe" {
  name                = "tcp-probe"
  protocol            = "Tcp"
  port                = 80
  loadbalancer_id     = azurerm_lb.web_lb.id
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Resource-5: Create LB Rule
resource "azurerm_lb_rule" "web_lb_rule_app1" {
  name                           = "web-app1-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.web_lb.frontend_ip_configuration[0].name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id
  probe_id                       = azurerm_lb_probe.web_lb_probe.id
  loadbalancer_id                = azurerm_lb.web_lb.id
  resource_group_name            = data.azurerm_resource_group.rg.name
}


# Resource-6: Associate Network Interface and Standard Load Balancer
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_backend_address_pool_association
resource "azurerm_network_interface_backend_address_pool_association" "web_nic_lb_associate" {
  //for_each                = var.web_linuxvm_instance_count
  count                   = var.web_linuxvm_instance_count
  network_interface_id    = element(azurerm_network_interface.web_linuxvm_nic[*].id, count.index)
  ip_configuration_name   = azurerm_network_interface.web_linuxvm_nic[count.index].ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id


}



# Azure LB Inbound NAT Rule
resource "azurerm_lb_nat_rule" "web_lb_inbound_nat_rule_22" {
  depends_on = [azurerm_virtual_machine.vmss] # To effectively handle azurerm provider related dependency bugs during the destroy resources time
  //for_each = var.web_linuxvm_instance_count
  count = var.web_linuxvm_instance_count
  name  = "vm-${count.index}-ssh-${var.lb_inbound_nat_ports[count.index]}-vm22"
  #name = "${each.key}-ssh-${each.value}-vm-22"
  protocol      = "Tcp"
  frontend_port = element(var.lb_inbound_nat_ports, count.index)
  #frontend_port = each.value,
  #frontend_port = lookup(var.web_linuxvm_instance_count, each.key)
  backend_port                   = 22
  frontend_ip_configuration_name = azurerm_lb.web_lb.frontend_ip_configuration[0].name
  resource_group_name            = data.azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.web_lb.id
}

# Associate LB NAT Rule and VM Network Interface
resource "azurerm_network_interface_nat_rule_association" "web_nic_nat_rule_associate" {
  #for_each              = var.web_linuxvm_instance_count
  count                 = var.web_linuxvm_instance_count
  network_interface_id  = element(azurerm_network_interface.web_linuxvm_nic[*].id, count.index)
  ip_configuration_name = element(azurerm_network_interface.web_linuxvm_nic[*].ip_configuration[0].name, count.index)
  nat_rule_id           = element(azurerm_lb_nat_rule.web_lb_inbound_nat_rule_22[*].id, count.index)

}


//https://docs.microsoft.com/en-us/azure/developer/terraform/create-vm-cluster-with-infrastructure


