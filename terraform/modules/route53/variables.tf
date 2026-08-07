variable "domain_name" {
  type        = string
  description = "Domínio principal para a zona hospedada do Route 53"
  default     = "yourcompany.com"
}

variable "subdomain" {
  type        = string
  description = "Subdomínio do serviço (ex: n8n)"
  default     = "n8n"
}

variable "aws_target" {
  type        = string
  description = "Endereço do Application Load Balancer na AWS"
  default     = "alb-placeholder.us-east-1.elb.amazonaws.com"
}

variable "gcp_target" {
  type        = string
  description = "Endereço IP ou DNS do Load Balancer no GCP"
  default     = "34.120.120.120"
}

variable "aws_weight" {
  type        = number
  description = "Peso inicial para a rota AWS"
  default     = 50
}

variable "gcp_weight" {
  type        = number
  description = "Peso inicial para a rota GCP"
  default     = 50
}

variable "environment" {
  type        = string
  description = "Ambiente (ex: dev, prod)"
}
