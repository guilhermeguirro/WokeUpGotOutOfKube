#!/bin/bash
# Script master para restaurar toda a infraestrutura DevSecOps da fintech

set -e

echo "🚀 Iniciando restauração completa da infraestrutura DevSecOps para Fintech..."

# Tornar scripts executáveis
chmod +x fix-deployment.sh fix-argocd.sh fix-security.sh

# Verificar conexão com AWS e Kubernetes
echo "🔄 Executando diagnóstico inicial e correções de infraestrutura..."
./fix-deployment.sh

# Instalar ArgoCD corretamente
echo "🔄 Instalando ArgoCD corretamente..."
./fix-argocd.sh

# Instalar componentes de segurança
echo "🔄 Instalando componentes de segurança..."
./fix-security.sh

# Esperar que os componentes estejam prontos
echo "⏳ Aguardando componentes críticos estarem prontos..."
sleep 10

# Aplicar labels de injeção do Istio nos namespaces
echo "🔄 Configurando injeção do Istio..."
for NS in default frontend backend payments; do
  kubectl label namespace $NS istio-injection=enabled --overwrite
done

# Verificar integridade final
echo "🔍 Verificação final da infraestrutura..."

echo "Nodes do Kubernetes:"
kubectl get nodes

echo "Namespaces:"
kubectl get namespaces

echo "Pods em namespaces críticos:"
for NS in argocd istio-system vault monitoring security kyverno falco cert-manager security-tools; do
  echo "Namespace $NS:"
  kubectl get pods -n $NS 2>/dev/null || echo "  Namespace não encontrado ou sem pods"
done

# Instruções finais e links de acesso
echo ""
echo "✅ Restauração concluída com sucesso!"
echo ""
echo "Para acessar os componentes:"
echo ""
echo "1. ArgoCD:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Acesse: https://localhost:8080"
echo "   Usuário: admin"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "não disponível")
echo "   Senha: $ARGOCD_PASSWORD"
echo ""
echo "2. Vault:"
echo "   kubectl port-forward svc/vault -n vault 8200:8200"
echo "   Acesse: http://localhost:8200"
echo "   Token: root (modo dev)"
echo ""
echo "3. Grafana:"
echo "   kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
echo "   Acesse: http://localhost:3000"
echo "   Usuário: admin"
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d || echo "não disponível")
echo "   Senha: $GRAFANA_PASSWORD"
echo ""
echo "4. Kyverno Dashboard:"
echo "   kubectl port-forward svc/kyverno-ui -n kyverno 8081:8080 (se disponível)"
echo "   Acesse: http://localhost:8081"

echo ""
echo "Para verificar alertas de segurança:"
echo "kubectl get policyreports -A"
echo ""
echo "Para visualizar logs do Falco:"
echo "kubectl logs -f -n falco -l app.kubernetes.io/name=falco" 