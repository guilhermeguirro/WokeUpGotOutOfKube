provider "aws" {
  region = var.region
}

# Módulo de rede para a infraestrutura Fintech

# Criação da VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-vpc"
    }
  )
}

# Subnets privadas
resource "aws_subnet" "private" {
  count = length(var.private_subnets)
  
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  
  tags = merge(
    var.tags,
    {
      Name                              = "${var.cluster_name}-private-${data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]}"
      "kubernetes.io/role/internal-elb" = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# Subnets públicas
resource "aws_subnet" "public" {
  count = length(var.public_subnets)
  
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  map_public_ip_on_launch = true
  
  tags = merge(
    var.tags,
    {
      Name                              = "${var.cluster_name}-public-${data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]}"
      "kubernetes.io/role/elb"          = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-igw"
    }
  )
}

# Elastic IPs para NAT Gateways
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
  domain = "vpc"
  
  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-nat-eip-${count.index + 1}"
    }
  )
}

# NAT Gateways
resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-nat-gw-${count.index + 1}"
    }
  )
  
  depends_on = [aws_internet_gateway.this]
}

# Tabela de rotas para subnets públicas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-public-rt"
    }
  )
}

# Rotas para subnets públicas (via Internet Gateway)
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Associar tabela de rotas às subnets públicas
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Tabela de rotas para subnets privadas
resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnets)) : length(var.private_subnets)
  
  vpc_id = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = var.single_nat_gateway ? "${var.cluster_name}-private-rt" : "${var.cluster_name}-private-rt-${count.index + 1}"
    }
  )
}

# Rotas para subnets privadas (via NAT Gateway)
resource "aws_route" "private_nat_gateway" {
  count = var.enable_nat_gateway ? length(aws_route_table.private) : 0
  
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
}

# Associar tabela de rotas às subnets privadas
resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# CloudWatch VPC Flow Logs (opcional)
resource "aws_flow_log" "this" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  
  iam_role_arn    = aws_iam_role.vpc_flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-vpc-flow-log"
    }
  )
}

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  
  name              = "/aws/vpc-flow-log/${var.cluster_name}"
  retention_in_days = var.flow_logs_retention_days
  
  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-vpc-flow-log-group"
    }
  )
}

resource "aws_iam_role" "vpc_flow_log" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  
  name = "${var.cluster_name}-vpc-flow-log-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
  
  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-vpc-flow-log-role"
    }
  )
}

resource "aws_iam_role_policy" "vpc_flow_log" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  
  name   = "${var.cluster_name}-vpc-flow-log-policy"
  role   = aws_iam_role.vpc_flow_log[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

# Data Sources
data "aws_availability_zones" "available" {}

# Outputs
output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.this.id
}

output "private_subnets" {
  description = "Lista de IDs das subnets privadas"
  value       = aws_subnet.private[*].id
}

output "public_subnets" {
  description = "Lista de IDs das subnets públicas"
  value       = aws_subnet.public[*].id
}

output "nat_gateway_ips" {
  description = "Lista de IPs elásticos dos NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "vpc_cidr_block" {
  description = "Bloco CIDR da VPC"
  value       = aws_vpc.this.cidr_block
}

# Security Group para Bastion Host
resource "aws_security_group" "bastion" {
  name        = "${var.environment}-bastion-sg"
  description = "Security group for bastion instances"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidr
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
      Name        = "${var.environment}-bastion-sg"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# Security Group para RDS
resource "aws_security_group" "database" {
  name        = "${var.environment}-database-sg"
  description = "Security group for database instances"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "PostgreSQL from private subnets"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = var.private_subnets
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
      Name        = "${var.environment}-database-sg"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# Security Group para o cluster EKS
resource "aws_security_group" "eks_control_plane" {
  name        = "${var.environment}-eks-control-plane-sg"
  description = "Security group for EKS Control Plane"
  vpc_id      = aws_vpc.this.id
  
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
      Name = "${var.cluster_name}-eks-control-plane-sg"
    }
  )
}

# Network ACLs para camada adicional de segurança
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.private[*].id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-private-nacl"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# Endpoint da VPC para AWS Services (elimina tráfego pela internet)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = aws_route_table.private[*].id

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-s3-endpoint"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-ecr-api-endpoint"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-ecr-dkr-endpoint"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-secretsmanager-endpoint"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# Security Group para VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.environment}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
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
      Name        = "${var.environment}-vpc-endpoints-sg"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
} 