module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr             = var.vpc_cidr
  environment          = var.environment
  cluster_name         = var.cluster_name
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

# AWS Cluster deployment (enabled by default)
module "eks" {
  source = "../../modules/eks"

  cluster_name        = var.cluster_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_max_size       = 4
  node_min_size       = 1
}

# Dev environment specific Pod Identity mapping for example API
module "pod_identity_api_example" {
  source = "../../modules/pod-identity"

  cluster_name         = module.eks.cluster_name
  environment          = var.environment
  service_account_name = "api-example-sa"
  namespace            = "dev"
}

# ===============================================================================
# GCP GKE DEPLOYMENT (Enabled by default as per project requirements)
# ===============================================================================
module "gke" {
  source       = "../../modules/gke"
  project_id   = var.gcp_project_id
  region       = var.gcp_region
  environment  = var.environment
  cluster_name = "template-gke-cluster-dev"
  vpc_cidr     = "10.2.0.0/16"
  subnet_cidr  = "10.2.1.0/24"
}

# ===============================================================================
# AZURE AKS EXTENSION (DEMO PURPOSES / OPTIONAL)
# ===============================================================================
#
# Para provisionar o cluster correspondente em Azure, descomente a seção abaixo
# e configure o provider azurerm no arquivo providers.tf.
/*
module "aks" {
  source              = "../../modules/aks"
  resource_group_name = "template-aks-rg-dev"
  location            = "eastus2"
  environment         = var.environment
  cluster_name        = "template-aks-cluster-dev"
  vnet_cidr           = "10.3.0.0/16"
  subnet_cidr         = "10.3.1.0/24"
}
*/
