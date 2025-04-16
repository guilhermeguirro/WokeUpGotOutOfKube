#!/bin/bash
# Script para instalar e configurar o ArgoCD corretamente

set -e

echo "🔄 Instalando ArgoCD no cluster Kubernetes..."

# Criar namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Aplicar CRDs primeiro
echo "🔄 Instalando CRDs do ArgoCD..."
kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds?ref=stable

# Aguardar que os CRDs sejam registrados
echo "⏳ Aguardando CRDs serem registrados..."
sleep 5

# Instalar ArgoCD
echo "🔄 Instalando componentes do ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aguardar pods ficarem disponíveis
echo "⏳ Aguardando pods do ArgoCD ficarem disponíveis..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd || true
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd || true
kubectl wait --for=condition=available --timeout=300s deployment/argocd-redis -n argocd || true
kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n argocd || true

# Verificar instalação
echo "🔍 Verificando instalação do ArgoCD..."
kubectl get pods -n argocd
kubectl get svc -n argocd

# Obter senha admin
echo "🔑 Obtendo senha de admin do ArgoCD..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "não disponível")

# Aplicar aplicações ArgoCD iniciais 
echo "🔄 Aplicando GitOps configs..."
if [ -f "kubernetes/argocd/applications/fintech-app.yaml" ]; then
  echo "🔄 Aplicando definição de fintech-app..."
  kubectl apply -f kubernetes/argocd/applications/fintech-app.yaml || true
fi

if [ -f "kubernetes/argocd/applications/monitoring.yaml" ]; then
  echo "🔄 Aplicando definição de monitoring..."
  kubectl apply -f kubernetes/argocd/applications/monitoring.yaml || true
fi

if [ -f "kubernetes/argocd/applications/security.yaml" ]; then
  echo "🔄 Aplicando definição de security..."
  kubectl apply -f kubernetes/argocd/applications/security.yaml || true
fi

# Instruções finais
echo "✅ Instalação do ArgoCD concluída!"
echo ""
echo "Para acessar o ArgoCD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Acesse: https://localhost:8080"
echo "  Usuário: admin"
echo "  Senha: $ARGOCD_PASSWORD" 