# Implantação na Azure

Este diretório contém configurações e instruções para implantar a infraestrutura DevSecOps no Azure usando AKS (Azure Kubernetes Service).

## Pré-requisitos

- Azure CLI instalado e configurado
- kubectl instalado
- Terraform instalado
- Helm instalado
- Permissões adequadas na sua subscrição Azure (Contributor ou Owner)

## Configuração da Infraestrutura

O template Terraform em `aks-deployment.yaml` define:

- Cluster AKS com Kubernetes 1.29
- Virtual Network dedicada com subnets segregadas
- Web Application Firewall (WAF) integrado via Application Gateway
- Azure Key Vault para gestão de segredos
- Log Analytics para monitoramento e observabilidade
- Node pools dedicados para componentes de segurança
- Azure Policy (Azure Policy for AKS) habilitado

## Preparação do Ambiente Azure

```bash
# Login no Azure
az login

# Definir subscrição a ser usada
az account set --subscription "Sua-Subscrição"

# Registrar providers necessários
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.PolicyInsights
```

## Processo de Implantação

### 1. Preparar Terraform

```bash
# Inicializar diretório de trabalho Terraform
mkdir -p terraform && cd terraform

# Criar arquivo main.tf
cat ../aks-deployment.yaml | yq -r '.data.template' > main.tf

# Adicionar provider Azure
cat > providers.tf <<EOF
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_public_ip" "app_gw_ip" {
  name                = "app-gw-public-ip"
  resource_group_name = azurerm_resource_group.fintech_rg.name
  location            = azurerm_resource_group.fintech_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_user_assigned_identity" "app_gw_identity" {
  resource_group_name = azurerm_resource_group.fintech_rg.name
  location            = azurerm_resource_group.fintech_rg.location
  name                = "app-gw-identity"
}
EOF

# Inicializar Terraform
terraform init
```

### 2. Implantar Infraestrutura

```bash
# Validar configuração
terraform validate

# Planejar implantação
terraform plan -out=terraform.plan

# Aplicar configuração
terraform apply terraform.plan
```

### 3. Configurar Acesso ao Cluster

```bash
# Obter credenciais para o AKS
az aks get-credentials --resource-group fintech-devsecops-rg --name fintech-cluster

# Verificar conexão
kubectl get nodes
```

### 4. Implantar Componentes de Segurança e Monitoramento

```bash
# Instalar Kyverno
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace

# Aplicar Políticas de Segurança Kyverno
kubectl apply -f ../../security/kyverno/network-policies.yaml
kubectl apply -f ../../security/kyverno/policy-enforcement.yaml

# Instalar HashiCorp Vault integrado com Azure Key Vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault --namespace vault --create-namespace \
  --set "server.dev.enabled=false" \
  --set "server.ha.enabled=true" \
  --set "server.ha.replicas=3" \
  --set "server.extraEnvironmentVars.AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)"

# Instalar Istio
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
kubectl create namespace istio-system
helm install istio-base istio/base -n istio-system
helm install istiod istio/istiod -n istio-system --wait
helm install istio-ingress istio/gateway -n istio-system

# Instalar ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Configurar Azure Monitor (Prometheus integrado)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring

# Instalar Falco
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco --namespace falco --create-namespace
```

### 5. Integrar AGIC (Application Gateway Ingress Controller)

```bash
# Obter IDs necessários
APPGW_ID=$(terraform output -raw app_gateway_id)
AKS_MC_RG=$(az aks show -g fintech-devsecops-rg -n fintech-cluster --query nodeResourceGroup -o tsv)
AKS_SUBID=$(az account show --query id -o tsv)

# Instalar AGIC
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update
helm install ingress-azure application-gateway-kubernetes-ingress/ingress-azure \
  --namespace ingress-azure \
  --create-namespace \
  --set appgw.subscriptionId=$AKS_SUBID \
  --set appgw.resourceGroup=fintech-devsecops-rg \
  --set appgw.name=fintech-app-gateway \
  --set appgw.usePrivateIP=false \
  --set armAuth.type=aadPodIdentity \
  --set armAuth.identityResourceID=$(az identity show -g fintech-devsecops-rg -n app-gw-identity --query id -o tsv) \
  --set armAuth.identityClientID=$(az identity show -g fintech-devsecops-rg -n app-gw-identity --query clientId -o tsv) \
  --set rbac.enabled=true
```

### 6. Instalar Toolkit de Segurança

```bash
kubectl apply -f ../../security/security-toolkit/security-toolkit.yaml
```

## Verificações de Segurança

Após a implantação, execute as seguintes verificações:

```bash
# Verificar status das políticas Kyverno
kubectl get clusterpolicies

# Verificar status de Azure Policies
az policy state list --resource $AKS_ID --query "[].{PolicyDefinitionName:policyDefinitionName, ComplianceState:complianceState}" -o table

# Verificar saúde do Vault
kubectl exec -it vault-0 -n vault -- vault status

# Verificar configuração do Application Gateway WAF
az network application-gateway waf-policy list -g fintech-devsecops-rg -o table

# Verificar implantação do Istio
istioctl analyze
```

## Monitoramento e Observabilidade

```bash
# Acessar dashboard do Grafana
kubectl port-forward svc/prometheus-grafana 8080:80 -n monitoring
# Acesse http://localhost:8080 (usuário: admin, senha obtida via: kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode)

# Acessar Kibana via Azure Portal
# Navegue até o Log Analytics Workspace no portal Azure
```

## Limpeza

Para remover a infraestrutura:

```bash
# Remover aplicações gerenciadas pelo ArgoCD primeiro
kubectl delete namespace argocd

# Remover infraestrutura via Terraform
terraform destroy
``` 