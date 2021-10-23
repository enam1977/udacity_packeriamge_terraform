# Terraform Block
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# Provider Block
provider "azurerm" {
  tenant_id = "dd152091-7e9a-448e-b6a0-223f687a2d84"
  features {}
}


# Generic Input Variables
# Business Division
variable "business_divsion" {
  description = "Business Division in the large organization this Infrastructure belongs"
  type        = string
  default     = "radio"
}
# Environment Variable
variable "environment" {
  description = "Environment Variable used as a prefix"
  type        = string
  default     = "uda"
}

variable "packer_resource_group_name" {
  description = "Name of the resource group in which the Packer image will be created"
  default     = "Udacity_rg"
}
variable "resource_group_name" {
  description = "name of the resource group name"
  //type        = string
  default = "Udacity_rg"
}
# Azure Resources Location
variable "resource_group_location" {
  description = "Region in which Azure Resources to be created"
  //type        = string
  default = "East US"
}
variable "location" {
  default     = "East us"
  description = "Location where resources will be created"
}

variable "admin_user" {
  description = "User name to use as the admin account on the VMs that will be part of the VM scale set"
  default     = "azureuser"
}

variable "admin_password" {
  description = "Default password for admin account"
  default     = "Allah@123"
}


# Define Local Values in Terraform
locals {
  owners               = var.business_divsion
  environment          = var.environment
  resource_name_prefix = "${var.business_divsion}-${var.environment}"
  #name = "${local.owners}-${local.environment}"
  common_tags = {
    owners      = local.owners
    environment = local.environment
  }
}

variable "server_name" {
  description = "name of the server"
  default     = "packer"
}

# Packer image variable declare
variable "packer_image_name" {
  description = "Name of the created packer image"
  type        = string
  default     = "Udemy_PackerImage"

}
# Virtual Network, Subnets and Subnet NSG's

## Virtual Network
variable "vnet_name" {
  description = "Virtual Network name"
  type        = string
  default     = "vnet-default"
}
variable "vnet_address_space" {
  description = "Virtual Network address_space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}


# Web Subnet Name
variable "web_subnet_name" {
  description = "Virtual Network Web Subnet Name"
  type        = string
  default     = "websubnet"
}
# Web Subnet Address Space
variable "web_subnet_address" {
  description = "Virtual Network Web Subnet Address Spaces"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

#weblinux Vm instance count
variable "web_linuxvm_instance_count" {
  description = "total instance count "
  type        = number
  default     = 1
}
#web linux inbound NAT port for all VMs
variable "lb_inbound_nat_ports" {
  description = "Web LB Inbound NAT Ports List"
  type        = list(string)
  default     = ["1022", "2022"]
}

