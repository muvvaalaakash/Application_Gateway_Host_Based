# ==============================================================
# TERRAFORM + PROVIDER
# ==============================================================
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.80.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}
# =========================================
# RESOURCE GROUP
# =========================================

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# =========================================
# VNET
# =========================================

resource "azurerm_virtual_network" "vnet" {
  name                = "HostBased-VNet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# =========================================
# SUBNETS
# =========================================

resource "azurerm_subnet" "gateway_subnet" {
  name                 = "Application-Gateway-Subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "backend_subnet" {
  name                 = "Backend-Subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/26"]
}

# =========================================
# APPLICATION NSG
# =========================================

resource "azurerm_network_security_group" "application_nsg" {
  name                = "Application-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-Http-internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-gateway-manager"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["65200-65535"]
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
}

# =========================================
# BACKEND NSG
# =========================================

resource "azurerm_network_security_group" "backend_nsg" {
  name                = "Backend-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-gateway-to-backend"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "8080-8083"]
    source_address_prefix      = "ApplicationGateway"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-bastion-ssh"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.3.0/26"
    destination_address_prefix = "*"
  }
}

# =========================================
# NSG ASSOCIATIONS
# =========================================

resource "azurerm_subnet_network_security_group_association" "gateway_assoc" {
  subnet_id                 = azurerm_subnet.gateway_subnet.id
  network_security_group_id = azurerm_network_security_group.application_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "backend_assoc" {
  subnet_id                 = azurerm_subnet.backend_subnet.id
  network_security_group_id = azurerm_network_security_group.backend_nsg.id
}

# =========================================
# NICS
# =========================================

resource "azurerm_network_interface" "vm1_nic" {
  name                = "vm1-fitness-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "vm2_nic" {
  name                = "vm2-organic-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# =========================================
# VM1
# =========================================

resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "VM1-Fitness"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2ls_v5"

  admin_username = var.admin_username
  admin_password = var.admin_password

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.vm1_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# =========================================
# VM2
# =========================================

resource "azurerm_linux_virtual_machine" "vm2" {
  name                = "VM-2-Organic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2ls_v5"

  admin_username = var.admin_username
  admin_password = var.admin_password

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.vm2_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# =========================================
# NAT GATEWAY
# =========================================

resource "azurerm_public_ip" "nat_ip" {
  name                = "NAT-Public-IP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "nat" {
  name                    = "NAT-Gateway"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_nat_gateway_public_ip_association" "nat_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat_ip.id
}

resource "azurerm_subnet_nat_gateway_association" "backend_nat_assoc" {
  subnet_id      = azurerm_subnet.backend_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}

# =========================================
# BASTION
# =========================================

resource "azurerm_public_ip" "bastion_ip" {
  name                = "Bastion-Public-IP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "Azure-Bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "bastion-config"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }
}

# =========================================
# WAF POLICY
# =========================================

resource "azurerm_web_application_firewall_policy" "waf" {
  name                = "WAF"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  policy_settings {
    enabled = true
    mode    = "Prevention"
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

# =========================================
# APPLICATION GATEWAY PUBLIC IP
# =========================================

resource "azurerm_public_ip" "agw_public_ip" {
  name                = "AGW-Public-IP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# =========================================
# APPLICATION GATEWAY
# =========================================

resource "azurerm_application_gateway" "agw" {

  name                = "AGW"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  autoscale_configuration {
    min_capacity = 1
    max_capacity = 3
  }

  firewall_policy_id = azurerm_web_application_firewall_policy.waf.id

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.gateway_subnet.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.agw_public_ip.id
  }

  backend_address_pool {
    name = "fitness"

    ip_addresses = [
      azurerm_network_interface.vm1_nic.private_ip_address
    ]
  }

  backend_address_pool {
    name = "organic"

    ip_addresses = [
      azurerm_network_interface.vm2_nic.private_ip_address
    ]
  }

  backend_http_settings {
    name                  = "fitness"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  backend_http_settings {
    name                  = "organic"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "Fitness-pool"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
    host_name                      = "fitness.clahanfashion.shop"
  }

  http_listener {
    name                           = "organic-pool"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
    host_name                      = "organic.clahanfashion.shop"
  }

  request_routing_rule {
    name                       = "Fitness-rule"
    rule_type                  = "Basic"
    http_listener_name         = "Fitness-pool"
    backend_address_pool_name  = "fitness"
    backend_http_settings_name = "fitness"
    priority                   = 102
  }

  request_routing_rule {
    name                       = "organic-rule"
    rule_type                  = "Basic"
    http_listener_name         = "organic-pool"
    backend_address_pool_name  = "organic"
    backend_http_settings_name = "organic"
    priority                   = 103
  }
}
