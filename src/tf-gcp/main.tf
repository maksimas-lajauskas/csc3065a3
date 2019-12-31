//Configure Google Cloud Platform

provider "google"{
  credentials = file(var.gcp_key_json)
  project = var.gcp_proj_id
  region = var.gcp_region
}

provider "kubernetes" {}

resource "google_container_cluster" "primary" {
    name = "${var.gcp_proj_id}-cluster"
    location = "${var.gcp_zone}"
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
    location = "${var.gcp_zone}"
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
        machine_type = "n1-standard-1"

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

}

resource "google_bigtable_instance" "qse-bigtable" {
  name = var.gcp_bigtable_instance
  project =  var.gcp_proj_id

  cluster {
    cluster_id   = "${var.gcp_proj_id}-cluster"
    zone         = var.gcp_zone
    num_nodes    = 3
    storage_type = "HDD"
  }
}

resource "google_bigtable_table" "qse-index" {
  name = var.gcp_bigtable_index_table
  project =  var.gcp_proj_id
  instance_name = google_bigtable_instance.qse-bigtable.name
}

resource "google_bigtable_table" "qse-ads" {
  name = var.gcp_bigtable_ads_table
  project =  var.gcp_proj_id
  instance_name = google_bigtable_instance.qse-bigtable.name
}

