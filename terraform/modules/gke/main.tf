resource "google_compute_network" "vpc" {
  name                    = "${var.environment}-gke-vpc"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.environment}-gke-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = var.subnet_cidr
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # We're creating a managed node pool separately, so we delete the default one
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  # Enable GKE Workload Identity (Modern equivalent to Pod Identity on GCP)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/14"
    services_ipv4_cidr_block = "/20"
  }

  tags = {
    environment = var.environment
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      env = var.environment
    }

    machine_type = var.machine_type
    tags         = ["gke-node", "${var.environment}-gke"]

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

# Example GCP IAM Service Account for Workload Identity
resource "google_service_account" "wi_sa" {
  account_id   = "${var.cluster_name}-app-sa"
  display_name = "Workload Identity Service Account for App"
}

# IAM Binding to allow Kubernetes Service Account to assume GCP SA
resource "google_service_account_iam_binding" "wi_binding" {
  service_account_id = google_service_account.wi_sa.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[dev/api-exemplo-sa]",
    "serviceAccount:${var.project_id}.svc.id.goog[prod/xperience-climb-sa]"
  ]
}
