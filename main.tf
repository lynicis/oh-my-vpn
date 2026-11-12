# ==============================================================================
# Azure Resource Group & Networking
# ==============================================================================

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "Production"
    Service     = "WireGuard"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-wireguard"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_subnet" "wireguard" {
  name                 = "snet-wireguard"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ==============================================================================
# Public IP & Network Security
# ==============================================================================

resource "azurerm_public_ip" "wireguard" {
  name                = "pip-wireguard"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_network_security_group" "wireguard" {
  name                = "nsg-wireguard"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = azurerm_resource_group.main.tags
}

# Public by design: VPN clients connect from arbitrary networks.
#trivy:ignore:AZU-0047
resource "azurerm_network_security_rule" "wireguard_udp" {
  name                        = "Allow-WireGuard-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = tostring(var.wireguard_port)
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.wireguard.name
}

# Scanner only sees the 0.0.0.0/0 default; restrict via admin_ssh_allowed_cidrs in terraform.tfvars.
#trivy:ignore:AZU-0047
#trivy:ignore:AZU-0050
resource "azurerm_network_security_rule" "ssh" {
  name                        = "Allow-SSH-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.admin_ssh_allowed_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.wireguard.name
}

# Public by design: encrypted DNS endpoint for off-tunnel devices.
#trivy:ignore:AZU-0047
resource "azurerm_network_security_rule" "dot" {
  name                        = "Allow-DoT-853"
  priority                    = 310
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "853"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.wireguard.name
}

# Public by design: encrypted DNS endpoint for off-tunnel devices.
#trivy:ignore:AZU-0047
resource "azurerm_network_security_rule" "doh" {
  name                        = "Allow-DoH-443"
  priority                    = 320
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.wireguard.name
}

resource "azurerm_network_interface" "wireguard" {
  name                = "nic-wireguard"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.wireguard.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.wireguard.id
  }

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_network_interface_security_group_association" "wireguard" {
  network_interface_id      = azurerm_network_interface.wireguard.id
  network_security_group_id = azurerm_network_security_group.wireguard.id
}

# ==============================================================================
# DNS-over-HTTPS Secret Path Generation
# ==============================================================================

resource "random_id" "doh_secret" {
  byte_length = 4
}

locals {
  doh_secret = var.doh_secret_path != null && var.doh_secret_path != "" ? var.doh_secret_path : random_id.doh_secret.hex
  doh_path   = "/dns-query-${local.doh_secret}"
}

# ==============================================================================
# Virtual Machine (Ubuntu 24.04 LTS + WireGuard)
# ==============================================================================

resource "azurerm_linux_virtual_machine" "wireguard" {
  name                = "vm-wireguard"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.wireguard.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    server_public_ip   = azurerm_public_ip.wireguard.ip_address
    server_domain_name = var.server_domain_name
    wireguard_port     = var.wireguard_port
    admin_username     = var.admin_username
    doh_path           = local.doh_path
  }))

  lifecycle {
    ignore_changes = [
      custom_data,
    ]
  }

  tags = azurerm_resource_group.main.tags
}
