provider "aws" {
  region = var.region
}

module "networking" {
  source        = "./networking"
  region        = var.region
  environment   = var.environment
  cluster_name  = var.cluster_name
  vpc_cidr      = var.vpc_cidr
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  tags          = var.tags
}

module "eks" {
  source        = "./eks"
  region        = var.region
  environment   = var.environment
  cluster_name  = var.cluster_name
  vpc_id        = module.networking.vpc_id
  private_subnets = module.networking.private_subnets
  tags          = var.tags
}

# Sistema de gestão de segredos
module "security" {
  source      = "./security"
  region      = var.region
  environment = var.environment
  vpc_id      = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnets
  eks_oidc_provider = module.eks.oidc_provider_arn != "" ? trimprefix(module.eks.oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/") : ""
  tags        = var.tags
}

# Monitoramento e observabilidade
module "monitoring" {
  source      = "./monitoring"
  region      = var.region
  environment = var.environment
  vpc_id      = module.networking.vpc_id
  cluster_name = var.cluster_name
  alert_email = var.alert_email
  tags        = var.tags
}

# Data Sources
data "aws_caller_identity" "current" {}

# Outputs importantes
output "cluster_id" {
  description = "O ID do cluster EKS"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "O endpoint do plano de controle do EKS"
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "O ID da VPC criada"
  value       = module.networking.vpc_id
}

output "private_subnets" {
  description = "IDs das subnets privadas"
  value       = module.networking.private_subnets
}

output "public_subnets" {
  description = "IDs das subnets públicas"
  value       = module.networking.public_subnets
}

output "eks_security_group_id" {
  description = "ID do security group do cluster EKS"
  value       = module.eks.security_group_id
} 