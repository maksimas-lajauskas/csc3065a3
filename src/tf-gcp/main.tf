//Configure Google Cloud Platform

#needs vars:
#gcp_key_json
#gcp_proj_id
#region

provider "google"{
  credentials = file(var.gcp_key_json)
  project = var.gcp_proj_id
  region = var.region
}

provider "kubernetes" {}

resource "google_container_cluster" "primary" {
    name = "${var.gcp_proj_id}-cluster"
    location = var.region
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

resource "google_container_node_pool" "primary_node_pool" {
    name = "${var.gcp_proj_id}-pool"
    location = var.region
    cluster = google_container_cluster.primary.name
    node_count = 1

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
        machine_type = "g1-small"

        oauth_scopes = [
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring",
        "https://www.googleapis.com/auth/devstorage.read_only"
        ]
    }

    timeouts {
        create = "30m"
        update = "40m"
    }

    lifecycle {
      create_before_destroy = true
    }

}

resource "google_storage_bucket" "qse-bucket" {
  name     = var.qse_storage_bucket_name
  lifecycle {
    prevent_destroy = true
  }
}
