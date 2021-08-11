resource "google_service_account" "default" {
  account_id   = "terraform-sa"
  display_name = "Terraform Service Account"
}


resource "google_container_cluster" "primary" {
  name     = "gke-ntu-asr-cluster"
  location = "asia-southeast1-a"
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}


resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "ntu-asr-node-pool"
  location   = "asia-southeast1-a"
  cluster    = google_container_cluster.primary.name
  node_count = 0

  node_config {
    preemptible  = true
    machine_type = "e2-standard-4"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}


resource "google_filestore_instance" "instance" {
  name = "asr-filestore-instance"
  zone = "asia-southeast1-a"
  tier = "BASIC_HDD"

  file_shares {
    capacity_gb = 1024
    name        = "modelshare"
  }


  networks {
    network = "default"
    modes   = ["MODE_IPV4"]
  }
}
