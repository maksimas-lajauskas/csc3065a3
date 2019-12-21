//Configure Google Cloud Platform

provider "google"{
  credentials = "${file("csc3065a3-f1d531a5dd9a.json")}"
  project = "csc3065a3"
  region = "us-west1"
}

resource "google_container_cluster" "primary" {
    name = "csc3065a3-cluster"
    location = "us-west1"
    remove_default_node_pool = true
    initial_node_count = 1
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
    cluster = "google_container_cluster".primary.name
    node_count = 1

    node_config {
        preemptible = true
        machine_time = "n1-standard-1"
    }

    oauth_scopes = [
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring"
    ]

}
