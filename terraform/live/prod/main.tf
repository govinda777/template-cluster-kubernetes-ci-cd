module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr             = var.vpc_cidr
  environment          = var.environment
  cluster_name         = var.cluster_name
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]
}

# AWS Cluster deployment
module "eks" {
  source = "../../modules/eks"

  cluster_name        = var.cluster_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  node_instance_types = ["t3.large"]
  node_desired_size   = 3
  node_max_size       = 6
  node_min_size       = 2
}

# Prod environment specific Pod Identity mapping for example API
module "pod_identity_api_exemplo" {
  source = "../../modules/pod-identity"

  cluster_name         = module.eks.cluster_name
  environment          = var.environment
  service_account_name = "api-exemplo-sa"
  namespace            = "prod"
}

# ===============================================================================
# MULTI-CLOUD EXTENSIONS (DEMO PURPOSES)
# ===============================================================================
#
# Para provisionar clusters correspondentes em GCP ou Azure no mesmo ambiente,
# descomente as seções abaixo e configure os respectivos providers no arquivo providers.tf.

/*
module "gke" {
  source       = "../../modules/gke"
  project_id   = "my-gcp-project-prod"
  region       = "us-west1"
  environment  = var.environment
  cluster_name = "template-gke-cluster-prod"
  vpc_cidr     = "10.2.0.0/16"
  subnet_cidr  = "10.2.1.0/24"
}

module "aks" {
  source              = "../../modules/aks"
  resource_group_name = "template-aks-rg-prod"
  location            = "westus2"
  environment         = var.environment
  cluster_name        = "template-aks-cluster-prod"
  vnet_cidr           = "10.3.0.0/16"
  subnet_cidr         = "10.3.1.0/24"
}
*/
