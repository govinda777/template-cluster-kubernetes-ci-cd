output "cluster_name" {
  value       = azurerm_kubernetes_cluster.aks.name
  description = "The AKS Cluster Name"
}

output "cluster_endpoint" {
  value       = azurerm_kubernetes_cluster.aks.fqdn
  description = "The AKS Cluster control plane endpoint"
}

output "oidc_issuer_url" {
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  description = "The AKS Cluster OIDC Issuer URL"
}

output "azure_client_id" {
  value       = azurerm_user_assigned_identity.aks_identity.client_id
  description = "The Client ID of the associated Azure User Assigned Identity"
}
