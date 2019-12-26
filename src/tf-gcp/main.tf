//Configure Google Cloud Platform

provider "google"{
  credentials = "${file("csc3065a3-f1d531a5dd9a.json")}"
  project = "csc3065a3"
  region = "us-west1"
}

provider "kubernetes" {}

resource "google_container_cluster" "primary" {
    name = "csc3065a3-cluster"
    location = "us-west1"
    remove_default_node_pool = true
    initial_node_count = 1
    ip_allocation_policy {}
    master_auth {
        username = ""
        password = ""

        client_certificate_config {
            issue_client_certificate = false
        }
    }
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
    name = "csc3065a3-pool"
    location = "us-west1"
    cluster = "csc3065a3-cluster"
    node_count = 0

    autoscaling {
        min_node_count= 0
        max_node_count= 3
    }

    management {
        auto_repair = true
        auto_upgrade = true
    }

    node_config {
        preemptible = false
        machine_type = "n1-standard-1"

        oauth_scopes = [
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring"
        ]
    }

    timeouts {
        create = "30m"
        update = "40m"
    }
}

resource "kubernetes_pod" "nginx" {
    metadata {
        name = "nginx-example"
        labels = {
            App = "nginx"
        }
    }

    spec {
        container {
            image = "nginx:1.7.8"
            name  = "example"

            port {
                container_port = 80
            }
        }
    }
}
