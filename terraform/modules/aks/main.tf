resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.environment}-aks-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.environment}-aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr]
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.cluster_name}-dns"

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size
    vnet_subnet_id = azurerm_subnet.subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  # Enable OIDC Issuer & Azure AD Workload Identity
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = {
    Environment = var.environment
  }
}

# Example User Assigned Identity for AKS Workload Identity
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "${var.cluster_name}-app-identity"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Federated Identity Credential to link Kubernetes ServiceAccount with Azure Managed Identity
resource "azurerm_federated_identity_credential" "aks_federated" {
  name                = "${var.cluster_name}-federated-credential"
  resource_group_name = azurerm_resource_group.rg.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.aks_identity.id
  subject             = "system:serviceaccount:dev:api-exemplo-sa"
}
