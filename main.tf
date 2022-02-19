#setting the provider block here to set Azure Provider source and latest version we are
#using for this project
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.96.0"
    }
  }
}

provider "azurerm" {
  features {}

  #this will be used to authenticate to to the Azure Tenant
  #where these resources will be deployed
  #subscription_id = "[Subscription_ID]"
  #  subscription_id =
}

#resource group where all the created resources will reside, contains all the metadata of resources for ease of management
resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = var.location
}

#every vnet will have a network security group that will manage the traffic flowing in and out of the vnet
# we are calling the the location and resouce group name from the resource group we created in the main.tf file
resource "azurerm_network_security_group" "example" {
  name                = "example-security-group"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

}
#create the vnet itself with some default settings in place
# make sure its in the same resource group and region

resource "azurerm_availability_set" "example" {
  name                = "example-availset"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  #tags assigned to resource for management purposes
  tags = {
    environment = "staging"
  }
}


resource "azurerm_virtual_network" "example" {
  name                = "example-network"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]


  tags = {
    environment = "staging"
  }
}

resource "azurerm_subnet" "subnet0" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.0.0/24"]
}

  resource "azurerm_subnet" "subnet1" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

  resource "azurerm_subnet" "subnet2" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
}

  resource "azurerm_subnet" "subnet3" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.3.0/24"]
}


resource "azurerm_public_ip" "lbpip" {
  name                = "examplep-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Dynamic"
}

resource "azurerm_lb" "lb" {
  resource_group_name = azurerm_resource_group.example.name
  name                = "clientenv-lb"
  location            = var.location

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = azurerm_public_ip.lbpip.id
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  resource_group_name = azurerm_resource_group.example.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "BackendPool1"
}

resource "azurerm_lb_nat_rule" "tcp" {
  resource_group_name            = azurerm_resource_group.example.name
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "RDP-VM-3"
  protocol                       = "tcp"
  frontend_port                  = 3389
  backend_port                   = 3389
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
}
#distrubute inbound traffic on port 80 to the instance in 3rd subnet
resource "azurerm_lb_rule" "lb_rule" {
  resource_group_name            = azurerm_resource_group.example.name
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "HTTPLBRule"
  protocol                       = "tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  enable_floating_ip             = false
  backend_address_pool_id        = azurerm_lb_backend_address_pool.backend_pool.id
  idle_timeout_in_minutes        = 5
  probe_id                       = azurerm_lb_probe.lb_probe.id
  depends_on                     = [azurerm_lb_probe.lb_probe]
}
#helps to determine the health status of the instances in the backend pool
#(i.e. determine if the vms are "healthy" enough to receive incoming traffic)
resource "azurerm_lb_probe" "lb_probe" {
  resource_group_name = azurerm_resource_group.example.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "tcpProbe"
  protocol            = "tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 1
}


resource "azurerm_network_security_rule" "ALB_subnet0_inbound" {
  name                       = "vnet-subnet0-allow"
  resource_group_name = azurerm_resource_group.example.name
  network_security_group_name = azurerm_network_security_group.example.name
  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "80"
  destination_port_range     = "80"
  source_address_prefix      = "AzureLoadBalancer"
  destination_address_prefix = "10.0.2.0/24"
}

resource "azurerm_network_security_rule" "vnet_subnet0_sshinbound" {
  name                       = "vnet-subnet0-allow"
  resource_group_name = azurerm_resource_group.example.name
  network_security_group_name = azurerm_network_security_group.example.name
  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "22"
  destination_port_range     = "22"
  source_address_prefix      = "10.0.0.0/16"
  destination_address_prefix = "10.0.0.0/24"
}


resource "azurerm_network_interface" "subnet0_nic0" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name


  ip_configuration {
    name                          = "testconfiguration0"
    subnet_id                     = azurerm_subnet.subnet0.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "subnet0_nic1" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name


  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.subnet0.id
    private_ip_address_allocation = "Dynamic"
  }
}



resource "azurerm_virtual_machine" "sub0vm" {
  name                  = "${var.prefix}-vm"
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = [azurerm_network_interface.subnet0_nic0.id, azurerm_network_interface.subnet0_nic1.id]
  availability_set_id   = azurerm_availability_set.example.id
  vm_size               = "Standard_DS1_v2"

  #reference to latest version of Redhat linux enterprise SKU that the vms will be based on
  storage_image_reference {
    publisher = "RedHat"
    offer     = "RedHatEnterpriseLinux"
    sku       = "8.1-Gen1"
    version   = "latest"
}
    storage_os_disk {
      name              = "myosdisk1"
      caching           = "ReadWrite"
      create_option     = "FromImage"
      managed_disk_type = "Standard_LRS"
    }

    count = 2

    depends_on = [
       azurerm_network_interface.subnet0_nic0
     ]

    tags = {
      environment = "staging"
    }

}

resource "azurerm_network_interface" "subnet2_nic" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "testconfiguration2"
    subnet_id                     = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_nat_rule_association" "natrule" {
  network_interface_id  = azurerm_network_interface.subnet2_nic.id
  ip_configuration_name = "ipconfig2"
  nat_rule_id           = azurerm_lb_nat_rule.tcp.id
}


resource "azurerm_virtual_machine" "sub2vm" {
  name                  = "subnet2-vm"
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = [azurerm_network_interface.subnet2_nic.id]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  provisioner "remote-exec" {

    inline = [
      "sudo apt update",
    "sudo apt install apache2"]
  }

  tags = {
    environment = "staging"
  }
}

resource "azurerm_storage_account" "example" {
  name                = "storageaccountname"
  resource_group_name = azurerm_resource_group.example.name

  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action             = "allow"
    virtual_network_subnet_ids = [azurerm_subnet.subnet0.id, azurerm_subnet.subnet1.id, azurerm_subnet.subnet2.id, azurerm_subnet.subnet3.id]
  }


  tags = {
    environment = "staging"
  }
}
