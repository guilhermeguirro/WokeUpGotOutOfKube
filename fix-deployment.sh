#!/bin/bash
# Script para diagnóstico e correção de problemas no deploy DevSecOps Fintech

set -e

echo "🔍 Iniciando diagnóstico do ambiente DevSecOps para Fintech..."

# Verificar conectividade AWS
echo "🌐 Verificando conectividade com AWS..."
if ! aws sts get-caller-identity &>/dev/null; then
  echo "❌ Falha na conexão com AWS. Verificando credenciais..."
  if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "⚠️ Variáveis de ambiente AWS não configuradas."
    echo "   Definindo credenciais temporárias para teste (ou ajuste conforme necessário):"
    echo "   export AWS_ACCESS_KEY_ID=your-access-key"
    echo "   export AWS_SECRET_ACCESS_KEY=your-secret-key" 
    echo "   export AWS_REGION=us-east-1"
    exit 1
  fi
else
  echo "✅ Conexão com AWS OK"
  aws sts get-caller-identity
fi

# Verificar estado do cluster
echo "🔄 Verificando estado do cluster Kubernetes..."
CLUSTER_NAME=${CLUSTER_NAME:-"fintech-production"}
REGION=${AWS_REGION:-"us-east-1"}

# Verificar se o cluster existe
if ! aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &>/dev/null; then
  echo "❌ Cluster '$CLUSTER_NAME' não encontrado na região $REGION"
  echo "   Clusters disponíveis na região $REGION:"
  aws eks list-clusters --region $REGION
  exit 1
fi

# Configurar kubectl para o cluster
echo "🔄 Reconfigurando kubectl para o cluster $CLUSTER_NAME..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Testar conectividade do kubectl
echo "🔄 Testando conectividade do kubectl..."
if ! kubectl cluster-info &>/dev/null; then
  echo "❌ Falha ao conectar ao cluster Kubernetes."
  echo "   Possíveis causas:"
  echo "   1. Problemas de rede ou VPN"
  echo "   2. Configuração de firewall bloqueando acesso"
  echo "   3. Políticas IAM insuficientes"
  echo "   4. Cluster em estado inválido"
  
  echo "🔄 Verificando status do cluster no AWS EKS..."
  aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.status"
  
  echo "🔄 Verificando políticas IAM do usuário atual..."
  aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query "Arn" --output text | cut -d '/' -f 2)
  
  exit 1
else
  echo "✅ Conexão kubectl OK"
  kubectl cluster-info
  kubectl get nodes
fi

# Verificar namespaces necessários
echo "🔄 Verificando namespaces necessários..."
for NS in argocd istio-system vault monitoring security-tools frontend backend payments; do
  if ! kubectl get namespace $NS &>/dev/null; then
    echo "⚠️ Namespace $NS não encontrado. Criando..."
    kubectl create namespace $NS
  else
    echo "✅ Namespace $NS OK"
  fi
done

# Verificar Istio
echo "🔄 Verificando instalação do Istio..."
if ! helm list -n istio-system | grep -q "istio-base"; then
  echo "⚠️ Istio não instalado. Instalando componentes básicos..."
  
  echo "🔄 Instalando repositório Helm do Istio..."
  helm repo add istio https://istio-release.storage.googleapis.com/charts
  helm repo update
  
  echo "🔄 Instalando istio-base..."
  helm install istio-base istio/base -n istio-system || true
  
  echo "🔄 Instalando istiod..."
  helm install istiod istio/istiod -n istio-system --wait || true
  
  echo "🔄 Instalando istio-ingress..."
  helm install istio-ingress istio/gateway -n istio-system --wait || true
else
  echo "✅ Istio instalado"
fi

# Verificar ArgoCD
echo "🔄 Verificando instalação do ArgoCD..."
if ! kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server &>/dev/null; then
  echo "⚠️ ArgoCD não instalado. Instalando..."
  
  echo "🔄 Instalando CRDs do ArgoCD..."
  kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds?ref=stable || true
  
  echo "🔄 Instalando ArgoCD..."
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  
  echo "⏳ Aguardando ArgoCD ficar disponível..."
  kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd || true
else
  echo "✅ ArgoCD instalado"
fi

# Verificar e corrigir Vault
echo "🔄 Verificando instalação do Vault..."
if ! helm list -n vault | grep -q "vault"; then
  echo "⚠️ Vault não instalado. Instalando..."
  
  echo "🔄 Instalando repositório Helm do Vault..."
  helm repo add hashicorp https://helm.releases.hashicorp.com
  helm repo update
  
  echo "🔄 Instalando Vault em modo dev para testes..."
  # Criar arquivo de valores simplificado
  cat > /tmp/vault-values.yaml << EOL
global:
  enabled: true
  tlsDisable: true

server:
  dev:
    enabled: true
    devRootToken: "root"
  standalone:
    enabled: false
  dataStorage:
    enabled: false
  service:
    enabled: true
    
ui:
  enabled: true
EOL
  
  helm install vault hashicorp/vault -n vault -f /tmp/vault-values.yaml --wait || true
else
  echo "✅ Vault instalado"
  
  # Verificar se está em estado de erro
  if kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; then
    if ! kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].status.containerStatuses[0].ready}' | grep -q "true"; then
      echo "⚠️ Pods do Vault estão executando mas não estão prontos. Corrigindo..."
      
      echo "🔄 Removendo instalação problemática do Vault..."
      kubectl delete statefulset vault -n vault 2>/dev/null || true
      kubectl delete pvc -n vault -l app.kubernetes.io/name=vault 2>/dev/null || true
      helm uninstall vault -n vault || true
      
      echo "🔄 Reinstalando Vault em modo dev..."
      helm install vault hashicorp/vault -n vault -f /tmp/vault-values.yaml --wait || true
    fi
  fi
fi

# Verificar Monitoring
echo "🔄 Verificando instalação do stack de monitoramento..."
if ! helm list -n monitoring | grep -q "prometheus"; then
  echo "⚠️ Stack de monitoramento não instalado. Instalando..."
  
  echo "🔄 Instalando repositório Helm do Prometheus..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  
  echo "🔄 Instalando Prometheus e Grafana..."
  helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --wait || true
else
  echo "✅ Stack de monitoramento instalado"
fi

# Verificar aplicação das configurações de rede
echo "🔄 Aplicando labels de injeção do Istio..."
for NS in default frontend backend payments; do
  kubectl label namespace $NS istio-injection=enabled --overwrite
done

# Exibir status final
echo "🔍 Verificação final de componentes críticos..."
echo "Istio:"
kubectl get pods -n istio-system
echo "ArgoCD:"
kubectl get pods -n argocd
echo "Vault:"
kubectl get pods -n vault
echo "Monitoring:"
kubectl get pods -n monitoring

echo "✅ Diagnóstico e correção concluídos."
echo ""
echo "Para acessar o ArgoCD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Acesse: https://localhost:8080"
echo "  Usuário: admin"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "não disponível")
echo "  Senha: $ARGOCD_PASSWORD"
echo ""
echo "Para acessar o Vault UI:"
echo "  kubectl port-forward svc/vault -n vault 8200:8200"
echo "  Acesse: http://localhost:8200"
echo "  Token: root (modo dev)" 