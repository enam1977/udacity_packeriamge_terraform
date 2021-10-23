business_divsion        = "ATT"
environment             = "dev"
resource_group_name     = "Udacity_rg"
resource_group_location = "East US"
vnet_name               = "vnet"
vnet_address_space      = ["10.1.0.0/16"]

web_subnet_name            = "websubnet"
web_subnet_address         = ["10.1.1.0/24"]
server_name                = "packer"
packer_image_name          = "Udemy_PackerImage"
web_linuxvm_instance_count = 2
lb_inbound_nat_ports       = ["1022", "2022"]

