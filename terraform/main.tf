provider "azurerm" {
  features {}

  subscription_id = "e417c211-aacf-4c20-91fa-26cc7556ef5f"
  client_id       = "724731e4-0174-4b38-8045-35fa93e57388"
  tenant_id       = "4baeec43-fbe3-44ee-af41-7a0701b58a57"
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "main-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "main" {
  name                 = "main-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IPs for each VM
resource "azurerm_public_ip" "vm" {
  for_each            = var.vm_configs
  name                = "${each.value.vm_name}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  allocation_method   = "Static"
}

# Network Interface for each VM
resource "azurerm_network_interface" "vm" {
  for_each            = var.vm_configs
  name                = "${each.value.vm_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = each.value.public_ip ? azurerm_public_ip.vm[each.key].id : null
  }
}

# Network Security Group with dynamic rules
resource "azurerm_network_security_group" "vm" {
  for_each            = var.vm_configs
  name                = "${each.value.vm_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Rule 1: Always allow SSH (priority 100)
  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Dynamic rules for custom ports (priority 200+)
  dynamic "security_rule" {
    for_each = each.value.open_ports
    content {
      name                       = "AllowPort-${security_rule.value}"
      priority                   = 200 + index(each.value.open_ports, security_rule.value) * 10
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = tostring(security_rule.value)
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  for_each                  = var.vm_configs
  network_interface_id      = azurerm_network_interface.vm[each.key].id
  network_security_group_id = azurerm_network_security_group.vm[each.key].id
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each            = var.vm_configs
  name                = each.value.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = each.value.vm_size
  admin_username      = each.value.admin_username

  network_interface_ids = [
    azurerm_network_interface.vm[each.key].id
  ]

  admin_ssh_key {
    username   = each.value.admin_username
    public_key = file(each.value.ssh_public_key)
  }

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

  custom_data = filebase64("${path.module}/${each.value.script_path}")
}

output "vm_public_ips" {
  value = {
    for key, config in var.vm_configs : key => (
      config.public_ip ? azurerm_public_ip.vm[key].ip_address : "No public IP"
    )
  }
}
