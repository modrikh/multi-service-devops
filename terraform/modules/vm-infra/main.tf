locals {
  tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
    module      = "vm-infra"
  }

  tooling_name = "${var.project_name}-${var.environment}-tooling"
  appdb_name   = "${var.project_name}-${var.environment}-appdb"
}

resource "azurerm_network_security_group" "vm_nsg" {
  name                = "${var.project_name}-${var.environment}-vm-nsg"
  location            = var.region
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.tags
}

resource "azurerm_public_ip" "tooling_pip" {
  name                = "${local.tooling_name}-pip"
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_public_ip" "appdb_pip" {
  name                = "${local.appdb_name}-pip"
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "tooling_nic" {
  name                = "${local.tooling_name}-nic"
  location            = var.region
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.tooling_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tooling_pip.id
  }

  tags = local.tags
}

resource "azurerm_network_interface" "appdb_nic" {
  name                = "${local.appdb_name}-nic"
  location            = var.region
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.appdb_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.appdb_pip.id
  }

  tags = local.tags
}

resource "azurerm_network_interface_security_group_association" "tooling_nic_nsg" {
  network_interface_id      = azurerm_network_interface.tooling_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

resource "azurerm_network_interface_security_group_association" "appdb_nic_nsg" {
  network_interface_id      = azurerm_network_interface.appdb_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

resource "azurerm_linux_virtual_machine" "tooling" {
  name                = local.tooling_name
  resource_group_name = var.resource_group_name
  location            = var.region
  size                = var.tooling_vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.tooling_nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = local.tags
}

resource "azurerm_linux_virtual_machine" "appdb" {
  name                = local.appdb_name
  resource_group_name = var.resource_group_name
  location            = var.region
  size                = var.appdb_vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.appdb_nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = local.tags
}
