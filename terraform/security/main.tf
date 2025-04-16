# AWS KMS Keys para criptografia
resource "aws_kms_key" "eks" {
  description             = "KMS key para segredos do Kubernetes"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-eks-kms-key"
    }
  )
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.environment}-eks-kms-key"
  target_key_id = aws_kms_key.eks.key_id
}

resource "aws_kms_key" "ebs" {
  description             = "KMS key para volumes EBS"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-ebs-kms-key"
    }
  )
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/${var.environment}-ebs-kms-key"
  target_key_id = aws_kms_key.ebs.key_id
}

# AWS Secrets Manager para armazenamento seguro de segredos
resource "aws_secretsmanager_secret" "database" {
  name        = "${var.environment}/fintech/database"
  description = "Credenciais do banco de dados para a aplicação Fintech"
  kms_key_id  = aws_kms_key.eks.arn
  
  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-database-credentials"
    }
  )
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    username = "fintech_app"
    password = random_password.db_password.result
    engine   = "postgres"
    host     = "db.fintech.internal"
    port     = 5432
    dbname   = "fintech"
  })
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# AWS IAM Roles e Políticas para acesso seguro
resource "aws_iam_role" "eks_secrets_access" {
  name = "${var.environment}-eks-secrets-access"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.eks_oidc_provider}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.eks_oidc_provider}:sub" = "system:serviceaccount:${var.environment}:fintech-app"
          }
        }
      }
    ]
  })
  
  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-eks-secrets-access"
    }
  )
}

resource "aws_iam_policy" "secrets_access" {
  name        = "${var.environment}-secrets-access-policy"
  description = "Política para acesso a segredos do Secrets Manager"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.database.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          aws_kms_key.eks.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_access" {
  role       = aws_iam_role.eks_secrets_access.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# Security Groups para proteção de rede
resource "aws_security_group" "secrets_endpoint" {
  name        = "${var.environment}-secrets-endpoint-sg"
  description = "Security group para endpoint VPC de Secrets Manager"
  vpc_id      = var.vpc_id
  
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-secrets-endpoint-sg"
    }
  )
}

# VPC Endpoint para acesso privado ao Secrets Manager
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.secrets_endpoint.id]
  private_dns_enabled = false
  
  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-secretsmanager-endpoint"
    }
  )
}

# Data sources
data "aws_caller_identity" "current" {}

data "aws_vpc" "this" {
  id = var.vpc_id
}

# Outputs
output "kms_key_eks_arn" {
  description = "ARN da KMS key para o EKS"
  value       = aws_kms_key.eks.arn
}

output "kms_key_ebs_arn" {
  description = "ARN da KMS key para volumes EBS"
  value       = aws_kms_key.ebs.arn
}

output "secrets_access_role_arn" {
  description = "ARN do papel IAM para acesso a segredos"
  value       = aws_iam_role.eks_secrets_access.arn
}

output "database_secret_arn" {
  description = "ARN do segredo das credenciais do banco de dados"
  value       = aws_secretsmanager_secret.database.arn
} 