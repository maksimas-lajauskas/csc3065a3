provider "azurerm" {}

resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_storage_account" "example" {
  name                     = "examplestoracc"
  resource_group_name      = "${azurerm_resource_group.example.name}"
  location                 = "${azurerm_resource_group.example.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "example" {
  name                  = "content"
  resource_group_name   = "${azurerm_resource_group.example.name}"
  storage_account_name  = "${azurerm_storage_account.example.name}"
  container_access_type = "private"
}

resource "azurerm_storage_blob" "example" {
  name                   = "my-awesome-content.zip"
  resource_group_name    = "${azurerm_resource_group.example.name}"
  storage_account_name   = "${azurerm_storage_account.example.name}"
  storage_container_name = "${azurerm_storage_container.example.name}"
  type                   = "Block"
  source                 = "some-local-file.zip"
}


#resource "azurerm_kubernetes_cluster" "k8s" {
#   name                = "example-aks1-k8s"
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name
#   dns_prefix          = "exampleaks1"

#   default_node_pool {
#     name       = "default"
#     node_count = 1
#     vm_size    = "Standard_D2_v2"
#   }

#   service_principal {
#     client_id     = "96475548-e6ea-4095-bb69-53032dec25d9"
#     client_secret = "?uUWHiJ/L.OW-ekCM16Zdj523Kb8y]RJ"
#   }

#   tags = {
#     Environment = "Production"
#   }
# }


# provider "kubernetes" {
#     load_config_file = false
#     host = azurerm_kubernetes_cluster.k8s.kube_config.0.host
#     username = azurerm_kubernetes_cluster.k8s.kube_config.0.username
#     password = azurerm_kubernetes_cluster.k8s.kube_config.0.password
#     client_certificate = base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_certificate)
#     client_key = base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_key)
#     cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.cluster_ca_certificate)
# }

# resource "kubernetes_deployment" "qse-crawler" {
#     metadata {
#         name = "qse-crawler"
#         labels = {
#             App = "qse-crawler"
#         }
#     }
#     spec {
#         replicas = 1
#         strategy {
#             type = "RollingUpdate"
#             rolling_update {
#                 max_surge = 4
#                 max_unavailable = 3
#             }
#         }
#         selector {
#            match_labels = {
#                 App = "qse-crawler"
#             }
#         }
#         template {
#             metadata{
#                 labels = {
#                     App = "qse-crawler"
#                 }
#             }
#             spec {
#                container {
#                     image = "docker.io/mlajauskas01/docker-hub:cca3-crawler"
#                     name  = "qse-crawler"
#                     resources {
#                                 limits {
#                                   cpu    = "0.5"
#                                   memory = "256Mi"
#                                }
#                                 requests {
#                                   cpu    = "250m"
#                                   memory = "50Mi"
#                                 }
#                     }
#                     env {
#                         name = "QSEPROVIDER"
#                         value = "AZURE"
#                     }
#                     env {
#                         name = "COMMON_PAGE_CONTENT_COLUMN_NAME"
#                         value = "pagetext"
#                     }
#                     port {
#                         container_port = 80
#                    }
#                 }
#             }
#         }
#     }
# }

# output "kube_config" {
#   value = azurerm_kubernetes_cluster.k8s.kube_config_raw
# }