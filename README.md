
Title: 
How to use Packer to create Linux virtual machine images in Azure and deploy using terraform


Prerequisites:

Install Packer,Terraform, Azure CLI and VSCode Editor in order to create the project. Follow the below link to install the tools. My information based on Mac OOS. So provided shell commands are for Mac OS.
- Create Azure account https://azure.microsoft.com/en-us/free/
From above link you can create a azure account for the project to create your resources.
- Homebrew is the place where all packages can be found to install(https://brew.sh/)

- Install [Packer](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli)
- Install [Terraform CLI](https://www.terraform.io/downloads.html)
- [Install CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- Install [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Install [VS Code Editor](https://code.visualstudio.com/download)
- Install [HashiCorp Terraform plugin for VS Code](https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform)
- Install [Git Client](https://git-scm.com/downloads)

Installation procedures:

 # Install Brew
First you need to install Homebrew, a powerful package manager for Mac. You can install following below command. 

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install XCode
brew update 
xcode-select --install
The reason to install xcode is that some software packages, usually open-source Unix packages, come with source code instead of a prebuilt binary file to install.

# Install Python 3:
$ brew install python
 AZ CLI does not work without Python 3 install into the system.

# AZ CLI Current Version (if installed)
az --version

# Install Azure CLI (if not installed)
brew update 
brew install azure-cli

# Upgrade az cli version
az --version
brew upgrade azure-cli 
[or]
az upgrade
az --version

# Install terraform from brew

brew install terraform

To confirm the installation, type terraform -v and you will get the current version as the output.


Terraform - Authenticating using the Azure CLI:

- [Azure Provider: Authenticating using the Azure CLI](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli)

# Azure CLI Login
az login
This command gets you to the azure portal where you have to provide credentials to get into the portal.
# List Subscriptions
az account list
This command get you the list of subscriptions associated with the account. In the list you will also get the subscription IDs.

# Set Specific Subscription (if we have multiple subscriptions)
az account set --subscription="SUBSCRIPTION_ID"
if you have more than one subscription IDs you need to set one to work for terraform. IF you have just one no need to do anything.

#  Install Git Client
- [Download Git Client](https://git-scm.com/downloads)
- This is required when we are working with `Terraform Modules`

Now we are done with all our installation and get ready in order to write coding in Packer and Terraform

Use Packer to create virtual image:

# Create Resource Group and location
https://docs.microsoft.com/en-us/azure/virtual-machines/windows/build-image-with-packer
In order to create Packer VM image you need to first create resource group and the location. There are so many option for location but i use "EAST-US". You can create login to the portal or using azure CLI. See the CLI command below to crease resource and location 

az group create -Name Udacity_rg -Location eastus

# Create Azure credentials

Packer authenticates with Azure using a service principal. An Azure service principal is a security identity that you can use with apps, services, and automation tools like Packer. You control and define the permissions as to what operations the service principal can perform in Azure.
  
  ## Create service principle

Below command create a service principle and get you credentials to use to run packer and terraform.

    az ad sp create-for-rbac -n "Uacity_Packer" --role Contributor --query "{ client_id: appId, client_secret: password, tenant_id: tenant }"


    "client_id": "21331ae3-df85-4cc9-be3e-445508caa15c",
    "client_secret": "ceceabee-a05b-4155-b05c-4b6a28371b2f",
    "tenant_id": "dd152091-7e9a-448e-b6a0-223f687a2d84"

  ## Find Subscription IDs

you will get above credentials by creating service principle but you also need subscription IDs that you can have using the following 

       az account show --query "{ subscription_id: id }"

       Subscription_id: "50d65e48-cd36-43c6-b861-3b1bcc7804e9"

you can also go portal to find the subscription ID and other credentials.
   ## Manual process to get the credentials
     -Login to Azure portal
     -Go Azure Active directory
     -App Registrations
     -new Registration
     -Application ID=Client ID 720188a5-ec69-446c-8fcf-7eb31bd44ca0
     -Secret ID=Client Secret(In order to get this you have to go Certificates and secrets and add new client secret)9ae19868-33e6-40ec-a075-d3241e4d156e
     -tenant ID=tenant ID(you will get it from Active Directory---Properties)
     -Subscription ID=Subscription (get from Subscriptions)50d65e48-cd36-43c6-b861-3b1bcc7804e9

  ## Role assign to  newly created service principle.
       
Without permission you can not create anything into the portal. It is basically protect unauthorized access into the system.
Here is the process to provide access,
   -Login to the portal
   -Find subscriptions
   -Select IAM
   -Select add -add role assignment--next
   -select contributor
   -select members and search for created Uacity_Packer to select.
   -Review and assign.
  
  AD App is unable to assign using AZ CLI command. So you have to do it using portal.

https://docs.microsoft.com/en-us/cli/azure/role?view=azure-cli-latest


Deploy a tagging policy:

The tagging policy will ensure all created resources have a tags so that it will help tracking and make it easier to do troubleshoot if anything goes wrong. 

# Policy deploy command
Below Az cli command to publish customer Policy that deny create any resource without  tags. Json code has generated and save in the file as Tagpolicy.json.


az policy definition create --name tagging-policy --subscription 50d65e48-cd36-43c6-b861-3b1bcc7804e9 --description Deny if tag is not there --display-name tagging-policy  --rules Tagpolicy.json --mode Indexed.

# Check whether policy is assigned or not

Below command show you all the policies including what you deployed now. 

az polcy assignment list

# Delete the policy

   If for some reason you need to get rid of any of the policy you can use below command or login to the portal to remove manually.

    az policy assignment delete ---name TagsPolicyDefinition


Create a Packer template:

Templates are the configuration files for Packer Images written in JSON format. There will be  three different kind of information.

# Variables in the Packer

Variables block contains any user provided variables that packer uses to create image. You can parameterize the packer template by configuring variables from the command line, storing them in a separate JSON file, or environment variables.

The Packer Azure builder will prompt you to authenticate via a web browser if you have the following 3 pieces of information referenced in the template:

You can directly provide the authenticate information into the template but it is not the standard practice. Here credentials will provide as environment variable and packer builder will pull the information. It is important not to keep credentials information in the templates due to security concern.

Below is an example of how the environment variables are passed to the packer template (this is for a service principal). Environment variables are passed to the variables set at the top of the packer template and then they become ‘user’ variables and passed to the builders.

"variables": {
        "client_id": "{{env `ARM_CLIENT_ID`}}",
        "client_secret": "{{env `ARM_CLIENT_SECRET`}}",
        "subscription_id": "{{env `ARM_SUBSCRIPTION_ID`}}"
    },

In order to get the credentials values during packer build , need to create a env to your machine . Here are the command below

     export ARM_CLIENT_ID="21331ae3-df85-4cc9-be3e-445508caa15c"
     export ARM_CLIENT_SECRET="b1Mlrps_T34tDmfb7NaNB_J4Jd.LTFBnmS"
     export ARM_SUBSCRIPTION_ID="50d65e48-cd36-43c6-b861-3b1bcc7804e9"


  To make sure whether values have  assigned or not. Run the below command.
      echo $ARM_CLIENT_ID

In case you need to change the value for some reasons. Here is the command below to change the value

    export ARM_CLIENT_ID="${ARM_CLIENT_ID} 

# Builders in the Packer: 
builders are an array of objects that Packer uses to generate machine images. Builders create temporary Azure resources as Packer builds the source VM based on the template.

This is where you have to provide all parameters you want to see in your packer image. Here are the sample 

  "builders": [
        {
            "type": "azure-arm",
            "client_id": "{{user `client_id`}}",
            "client_secret": "{{user `client_secret`}}",
            "subscription_id": "{{user `subscription_id`}}",
            "os_type": "Linux",
            "image_publisher": "Canonical",
            "image_offer": "UbuntuServer",
            "image_sku": "18.04-LTS",
            "managed_image_resource_group_name": "Udacity_rg",
            "managed_image_name": "Udemy_PackerImage",
            "location": "East US",
            "vm_size": "Standard_D2s_v3",
            "Azure_tags": {
                "dept": "ATT",
                "task": "Image_deployment"
            }
        }
    ],

# Provisioners in the packer: 
Provisioners can be used to pre-install and configure software within the running VM prior to turning it into a machine image. There can be multiple provisioners in a Packer template. Here is the sample of provisioners.

       "provisioners": [
        {
            "execute_command": "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'",
            "inline": [
                "echo 'Hello, World!' > index.html",
                "sudo apt update",
                "sudo apt install nginx -y",
                "sudo uft enable",
                "sudo wft allow http",
                "sudo wft allow https",
                "sudo ufw allow ssh",
                "nohup busybox httpd -f -p 80 &",
                "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
            ],
            "inline_shebang": "/bin/sh -x",
            "type": "shell"
        }
    ]


# Build the packer image:

Now are done building packer template to build virtual image in Azure portal. 

Before running the build command, you need to check whether the template syntax is correct. 

        packer validate server.json

Packer builds the images using the build sub-command followed by a JSON template.
        
        packer build server.json

Packer image has built. You can check whether packer image build  going to portal or the following command
     
        Az image list 

Whatever you build in the portal it cost money. So, if you don't need to keep the image any more, You can remove by following command or from the portal.

        az image delete -g resource-group name -n name of the image

Here is the link below to get details about packer image.
https://docs.microsoft.com/en-us/azure/virtual-machines/linux/build-image-with-packer


Create Terraform template:

Build a terraform template that use packer image VM to create duplicate virtual machine. While creating image  VM some of the resources have built and no need to repete them here. Just need to get the data of the resources i.e resources group, location, Image VM ete. There are three files have been used to write the coding.
  
# Variables.tf
  
In the file all of the variables have defined including 

       Terraform Settings Block
       Terraform Provider Block
       Terraform Input Variables
       Terraform Local Values Block

Here are some exampples of variables used for different resources
    
  ## This variable has used for packer image already created in the portal.

    variable "packer_image_name" {
    description = "Name of the created packer image"
    type        = string
    default     = "Udemy_PackerImage"

  }

  ## The variable has used for tagging
    common_tags = {
    owners      = local.owners
    environment = local.environment
    }

This link gets you more information about variables.
https://www.terraform.io/docs/language/values/index.html



# main.tf
This is where all resources information have given to execute. Som of the resources have created earliers in packer, so, just need to pull the information from the portal. These are the below resources we will create.


  ## First create Azure Resources 
These are mostly common resources required in any design.
       
       azurerm_resource_group
        -Resource group already created. So we will provide the source to get the data 
              
              data "azurerm_resource_group" "rg" {
              name = var.resource_group_name

              }

       azurerm_virtual_network
              resource "azurerm_virtual_network" "vnet" {
              name                = "${local.resource_name_prefix}-${var.vnet_name}"
              address_space       = var.vnet_address_space
              location            = var.resource_group_location
              resource_group_name = data.azurerm_resource_group.rg.name
              tags                = local.common_tags
              }
       
       azurerm_subnet
              resource "azurerm_subnet" "websubnet" {
              name                 = "${azurerm_virtual_network.vnet.name}-${var.web_subnet_name}"
              resource_group_name  = data.azurerm_resource_group.rg.name
              virtual_network_name = azurerm_virtual_network.vnet.name
              address_prefixes     = var.web_subnet_address
              }
       azurerm_network_security_group
              resource "azurerm_subnet" "websubnet" {
              name                 = "${azurerm_virtual_network.vnet.name}-${var.web_subnet_name}"
              resource_group_name  = data.azurerm_resource_group.rg.name
              virtual_network_name = azurerm_virtual_network.vnet.name
              address_prefixes     = var.web_subnet_address
              }
       azurerm_network_security_rule
Here two rules have  created.Deny port 80 that's mean deny all traffic from internet. Allow port 22, that's mean all traffic from VMs are allowed.
              resource "azurerm_network_security_rule" "web_nsg_rule_inbound_22" {
  
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

  ## Second Design Azure Virtual Network
  Here we will just pull the image  VM and try to create new.

        Packer image VM 

            data "azurerm_image" "packer_image" {
            name                = var.packer_image_name
            resource_group_name = data.azurerm_resource_group.rg.name

            }

      Azure Virtual Network     
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

 ## Third Network Security Group and rules for the Subnet
Shown above, need to create some more resource. These just help to create rule who can and who cannot access in the system.

    -azurerm_public_ip
    -azurerm_network_interface
    -azurerm_network_interface_security_group_association
    -Terraform Local Block for Security Rule Ports
    -azurerm_network_security_rule

More information about resources in the link below.
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule



## Fourth Azure Standard Load Balancer using Terraform

    -azurerm_public_ip
    -azurerm_lb
    -azurerm_lb_backend_address_pool
    -azurerm_lb_probe
    -azurerm_lb_rule
    -azurerm_network_interface_backend_address_pool_association

More information about resources in the link below.
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb
## Fifth NAT rule for loan balancer

   -azurerm_lb_nat_rule
   -azurerm_network_interface_nat_rule_association
   -Verify the SSH Connectivity to Linux VM using Load Balancer Public IP with port 1022 

More information about resources in the link below.
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_nat_rule

# terraform.tfvars

To set lots of variables, it is more convenient to specify their values in a variable definitions file (with a filename ending in either .tfvars or .tfvars.json) and then specify that file on the command line with -var-file

    business_divsion = "hr"
    environment = "dev"
    resource_group_name = "rg"
    resource_group_location = "eastus"
    vnet_name = "vnet"
    vnet_address_space = ["10.1.0.0/16"]
    web_subnet_name = "websubnet"
    web_subnet_address = ["10.1.1.0/24"]
    web_linuxvm_instance_count = 2
    lb_inbound_nat_ports = ["1022", "2022"]

More information about resources and variables
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
https://www.terraform.io/docs/language/values/variables.html#assigning-values-to-root-module-variables

#Execute Terraform Commands
   Now you are done with terraform. Define variables and resources. Below terraform commands will let the implement the code into the system.

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan -out solution.plan

# Terraform Apply
terraform apply -auto-approve


# Delete Resources
After implementing the file we might dont need to keep them long time. We can delete them. This is the way you can do this.

# Delete Resources
terraform destroy 
terraform apply -destroy

# Clean-Up Files
rm -rf .terraform* 
rm -rf terraform.tfstate*

