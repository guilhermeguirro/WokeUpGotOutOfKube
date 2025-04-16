#!/bin/bash
# Script para instalar e configurar os componentes de segurança

set -e

echo "🔄 Instalando componentes de segurança para fintech..."

# Criar namespace
kubectl create namespace security --dry-run=client -o yaml | kubectl apply -f -

# Verificar se precisamos criar diretórios
if [ ! -d "kubernetes/security/gatekeeper" ]; then
  echo "🔄 Criando estrutura de diretórios para componentes de segurança..."
  mkdir -p kubernetes/security/{gatekeeper,falco,kyverno,cert-manager,vault}
fi

# Instalar OPA Gatekeeper
echo "🔄 Instalando OPA Gatekeeper..."
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.13/deploy/gatekeeper.yaml || true

# Esperar que o Gatekeeper esteja instalado
echo "⏳ Aguardando OPA Gatekeeper ficar disponível..."
kubectl wait --for=condition=available --timeout=300s deployment/gatekeeper-controller-manager -n gatekeeper-system || true

# Instalar Kyverno
echo "🔄 Instalando Kyverno..."
kubectl create namespace kyverno --dry-run=client -o yaml | kubectl apply -f -
helm repo add kyverno https://kyverno.github.io/kyverno/ || true
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --wait || true

# Instalar Falco
echo "🔄 Instalando Falco..."
helm repo add falcosecurity https://falcosecurity.github.io/charts || true
helm repo update
kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f -
helm install falco falcosecurity/falco -n falco --set falco.jsonOutput=true --wait || true

# Instalar cert-manager
echo "🔄 Instalando cert-manager..."
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
helm repo add jetstack https://charts.jetstack.io || true
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.13.0 --set installCRDs=true --wait || true

# Aplicar Kustomize para a configuração de segurança
if [ -f "kubernetes/security/kustomization.yaml" ]; then
  echo "🔄 Aplicando configurações de Kustomize para segurança..."
  kubectl apply -k kubernetes/security/ || true
fi

# Verificar instalação dos componentes
echo "🔍 Verificando instalação dos componentes de segurança..."

echo "Gatekeeper:"
kubectl get pods -n gatekeeper-system

echo "Kyverno:"
kubectl get pods -n kyverno

echo "Falco:"
kubectl get pods -n falco

echo "cert-manager:"
kubectl get pods -n cert-manager

# Aplicar políticas de segurança se existirem
if [ -f "security/policies/security-policy.yaml" ]; then
  echo "🔄 Aplicando políticas de segurança..."
  kubectl apply -f security/policies/security-policy.yaml || true
fi

# Instalar toolkit de resposta a incidentes
if [ -f "security/security-toolkit.yaml" ]; then
  echo "🔄 Instalando toolkit de resposta a incidentes..."
  kubectl create namespace security-tools --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f security/security-toolkit.yaml || true
  
  echo "Toolkit de resposta a incidentes:"
  kubectl get pods -n security-tools
fi

# Instruções finais
echo "✅ Instalação dos componentes de segurança concluída!"
echo ""
echo "Para acessar o Dashboard de políticas do Kyverno:"
echo "  kubectl port-forward svc/kyverno-ui -n kyverno 8081:8080"
echo "  Acesse: http://localhost:8081"
echo ""
echo "Para verificar as políticas de segurança:"
echo "  kubectl get constraints -A" 