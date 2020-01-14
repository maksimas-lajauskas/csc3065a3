#vars needed:
#var.qse-azure-service-principal-id
#var.qse-azure-service-principal-secret
#end vars

provider "azurerm" {}

resource "azurerm_resource_group" "qse" {
  name     = "qse-resources"
  location = "West Europe"
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_account" "qse" {
  name                     = "qsestoreacc"
  resource_group_name      = azurerm_resource_group.qse.name
  location                 = azurerm_resource_group.qse.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "qse" {
  name                  = var.qse_storage_bucket_name
  resource_group_name   = azurerm_resource_group.qse.name
  storage_account_name  = azurerm_storage_account.qse.name
  container_access_type = "private"
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_kubernetes_cluster" "k8s" {
   name                = "qse-aks1-k8s"
   location            = azurerm_resource_group.qse.location
   resource_group_name = azurerm_resource_group.qse.name
   dns_prefix          = "qseaks1"

   default_node_pool {
     name       = "default"
     node_count = 1
     max_count = 3
     min_count = 1
     vm_size    = "Standard_D2_v2"
     enable_auto_scaling = true
   }

   service_principal {
     client_id     = var.qse-azure-service-principal-id
     client_secret =  var.qse-azure-service-principal-secret
   }

   tags = {
     Environment = "Production"
   }
   lifecycle {
    create_before_destroy = true
    ignore_changes = [default_node_pool]
  }
 }

 provider "kubernetes" {
     load_config_file = false
     host = azurerm_kubernetes_cluster.k8s.kube_config.0.host
     username = azurerm_kubernetes_cluster.k8s.kube_config.0.username
     password = azurerm_kubernetes_cluster.k8s.kube_config.0.password
     client_certificate = base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_certificate)
     client_key = base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_key)
     cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.cluster_ca_certificate)
 }

 output "kube_config" {
   value = azurerm_kubernetes_cluster.k8s.kube_config_raw
 }