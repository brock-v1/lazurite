##########################################################################################################################

# Resource Group

resource "azurerm_resource_group" "rg" {
  name     = "rg"
  location = var.location
}

##########################################################################################################################

# 2 VNETs + Peering

resource "azurerm_virtual_network" "vnet1" {
  name                = "vnet1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  address_space       = ["10.1.0.0/16"]
}
resource "azurerm_virtual_network" "vnet2" {
  name                = "vnet2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  address_space       = ["10.2.0.0/16"]
}
resource "azurerm_virtual_network_peering" "peer1to2" {
  name                      = "peer1to2"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet2.id
}
resource "azurerm_virtual_network_peering" "peer2to1" {
  name                      = "peer2to1"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
}

##########################################################################################################################

# Network Watcher

resource "azurerm_network_watcher" "networkwatcher" {
  name                = "networkwatcher"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
}

##########################################################################################################################

# 2 Subnets, 1 per VNET

resource "azurerm_subnet" "vnet1-subnet1" {
  name                 = "vnet1-subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.1.1.0/24"]
}
resource "azurerm_subnet" "vnet2-subnet1" {
  name                 = "vnet2-subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.2.1.0/24"]
}

##########################################################################################################################

# NSG - VNET1 + VNET2

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
}
resource "azurerm_network_security_rule" "allowany80" {
  name                        = "allowany80"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}
resource "azurerm_subnet_network_security_group_association" "nsgtovnet1-subnet1" {
  subnet_id                 = azurerm_subnet.vnet1-subnet1.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
resource "azurerm_subnet_network_security_group_association" "nsgtovnet2-subnet1" {
  subnet_id                 = azurerm_subnet.vnet2-subnet1.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

##########################################################################################################################

# Storage Account + Log Analytics Workspace + Flow Logging

resource "azurerm_storage_account" "salazurite123" {
  name                      = "salazurite123"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = var.location
  account_tier              = "Standard"
  account_kind              = "StorageV2"
  account_replication_type  = "LRS"
  enable_https_traffic_only = "true"
}
resource "azurerm_log_analytics_workspace" "law1" {
  name                = "law1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
resource "azurerm_network_watcher_flow_log" "nsgflowlog" {
  network_watcher_name      = azurerm_network_watcher.networkwatcher.name
  resource_group_name       = azurerm_resource_group.rg.name
  name                      = "nsgflowlog"
  network_security_group_id = azurerm_network_security_group.nsg.id
  storage_account_id        = azurerm_storage_account.salazurite123.id
  enabled                   = true
  retention_policy {
    enabled = true
    days    = 0
  }
  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.law1.workspace_id
    workspace_region      = var.location
    workspace_resource_id = azurerm_log_analytics_workspace.law1.id
    interval_in_minutes   = 10
  }
}

##########################################################################################################################

# VM1 - VNET1

resource "random_password" "vm1-pw" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  special     = true
}
resource "azurerm_public_ip" "vm1-public-ip" {
  name                = "vm1-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}
resource "azurerm_network_interface" "vm1-nic" {
  name                = "vm1-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "vm1-nic-ipconfig"
    subnet_id                     = azurerm_subnet.vnet1-subnet1.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.1.5"
    public_ip_address_id          = azurerm_public_ip.vm1-public-ip.id
  }
}
resource "azurerm_windows_virtual_machine" "vm1" {
  name                = "vm1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = "Standard_DS1_v2"
  admin_username      = "lazurite"
  admin_password      = random_password.vm1-pw.result
  network_interface_ids = [
    azurerm_network_interface.vm1-nic.id,
  ]
  os_disk {
    name                 = "vm1-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}
resource "azurerm_virtual_machine_extension" "vm1-webserverinstall" {
  name                       = "vm1-webserverinstall"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm1.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools"
    }
  SETTINGS
}

##########################################################################################################################

# VM2 - VNET1

resource "random_password" "vm2-pw" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  special     = true
}
resource "azurerm_public_ip" "vm2-public-ip" {
  name                = "vm2-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}
resource "azurerm_network_interface" "vm2-nic" {
  name                = "vm2-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "vm2-nic-ipconfig"
    subnet_id                     = azurerm_subnet.vnet1-subnet1.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.1.6"
    public_ip_address_id          = azurerm_public_ip.vm2-public-ip.id
  }
}
resource "azurerm_windows_virtual_machine" "vm2" {
  name                = "vm2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = "Standard_DS1_v2"
  admin_username      = "lazurite"
  admin_password      = random_password.vm2-pw.result
  network_interface_ids = [
    azurerm_network_interface.vm2-nic.id,
  ]
  os_disk {
    name                 = "vm2-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}
resource "azurerm_virtual_machine_extension" "vm2-webserverinstall" {
  name                       = "vm2-webserverinstall"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm2.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools"
    }
  SETTINGS
}

##########################################################################################################################

# Load Balancer

resource "azurerm_public_ip" "extlb-ip" {
  name                = "extlb-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_lb" "extlb" {
  name                = "extlb"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = azurerm_public_ip.extlb-ip.name
    public_ip_address_id = azurerm_public_ip.extlb-ip.id
  }
}
resource "azurerm_lb_backend_address_pool" "extlb-pool" {
  loadbalancer_id = azurerm_lb.extlb.id
  name            = "extlb-pool"
}
resource "azurerm_lb_probe" "extlb-probe80" {
  loadbalancer_id = azurerm_lb.extlb.id
  name            = "extlb-probe80"
  port            = 80
}
resource "azurerm_lb_rule" "extlb-rule80" {
  loadbalancer_id                = azurerm_lb.extlb.id
  name                           = "extlb-rule80"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  disable_outbound_snat          = true
  frontend_ip_configuration_name = azurerm_public_ip.extlb-ip.name
  probe_id                       = azurerm_lb_probe.extlb-probe80.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.extlb-pool.id]
}
resource "azurerm_lb_backend_address_pool_address" "vm1" {
  name                    = "vm1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.extlb-pool.id
  virtual_network_id      = azurerm_virtual_network.vnet1.id
  ip_address              = "10.1.1.5"
}
resource "azurerm_lb_backend_address_pool_address" "vm2" {
  name                    = "vm2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.extlb-pool.id
  virtual_network_id      = azurerm_virtual_network.vnet1.id
  ip_address              = "10.1.1.6"
}

##########################################################################################################################

# TO DO LIST:

# Add Bastion
# Add Private Endpoint
# Add DNS

##########################################################################################################################