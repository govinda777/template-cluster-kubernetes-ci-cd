output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "The GKE Cluster Name"
}

output "cluster_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "The GKE Cluster control plane endpoint"
}

output "gcp_service_account_email" {
  value       = google_service_account.wi_sa.email
  description = "The Workload Identity GCP Service Account Email"
}
