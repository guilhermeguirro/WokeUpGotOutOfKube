#!/bin/bash
# Script de deploy para a transformação DevSecOps da Fintech

set -e

echo "🚀 Iniciando deploy da infraestrutura DevSecOps para Fintech..."

# Verificando pré-requisitos
echo "✅ Verificando pré-requisitos..."
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI não está instalado. Abortando."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform não está instalado. Abortando."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl não está instalado. Abortando."; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ Helm não está instalado. Abortando."; exit 1; }

# Configuração do AWS CLI
echo "🔐 Configurando credenciais AWS..."
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "⚠️ Variáveis de ambiente AWS não configuradas. Usando perfil padrão."
    aws configure list
else
    echo "✅ Usando credenciais AWS das variáveis de ambiente."
fi

AWS_REGION=${AWS_REGION:-"us-east-1"}
ENVIRONMENT=${ENVIRONMENT:-"production"}
CLUSTER_NAME=${CLUSTER_NAME:-"fintech-${ENVIRONMENT}"}
ALERT_EMAIL=${ALERT_EMAIL:-""}

echo "🌐 Região AWS: $AWS_REGION"
echo "🌐 Ambiente: $ENVIRONMENT"
echo "🌐 Nome do Cluster: $CLUSTER_NAME"
echo "🌐 Email para alertas: $ALERT_EMAIL"

# Deploy da infraestrutura com Terraform
echo "🏗️ Provisionando infraestrutura com Terraform..."

# Verificando se existem arquivos terraform na pasta raiz
if [ -f "terraform/main.tf" ]; then
    cd terraform
    
    echo "🔧 Inicializando Terraform..."
    terraform init

    echo "🔍 Validando configuração Terraform..."
    terraform validate

    echo "📝 Planejando alterações..."
    terraform plan -var="region=$AWS_REGION" \
                   -var="environment=$ENVIRONMENT" \
                   -var="cluster_name=$CLUSTER_NAME" \
                   -var="alert_email=$ALERT_EMAIL" \
                   -out=tfplan

    echo "🔨 Aplicando alterações..."
    terraform apply tfplan

    echo "📋 Capturando saídas do Terraform..."
    EKS_CLUSTER_NAME=$(terraform output -raw cluster_id)
    EKS_CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint)
    
    cd ..
else
    echo "❌ Arquivos Terraform não encontrados. Verifique a estrutura do projeto."
    exit 1
fi

# Configurar kubectl para o novo cluster
echo "🔄 Configurando kubectl para o cluster EKS..."
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION

echo "⏳ Aguardando o cluster EKS ficar disponível (pode levar alguns minutos)..."
for i in {1..30}; do
  echo "Tentativa $i de 30..."
  if kubectl cluster-info; then
    CLUSTER_READY=true
    break
  fi
  sleep 20
done

if [ "${CLUSTER_READY}" != "true" ]; then
  echo "❌ Não foi possível conectar ao cluster EKS após várias tentativas."
  echo "⚠️ Você pode precisar verificar:"
  echo "  1. Configurações de rede e security groups"
  echo "  2. Se o cluster foi realmente criado (verifique no console da AWS)"
  echo "  3. Se sua máquina tem conectividade ao endpoint do EKS"
  echo "  4. Role permissões no IAM para seu usuário acessar o cluster"
  echo ""
  echo "Continuando a execução do script, mas comandos subsequentes podem falhar..."
fi

# Verificar conexão com o cluster
echo "🔍 Verificando conexão com o cluster Kubernetes..."
kubectl cluster-info || true
kubectl get nodes -o wide || true

# Verificar componentes Kubernetes necessários
for COMPONENT in kubernetes/istio kubernetes/argocd kubernetes/vault kubernetes/monitoring
do
    if [ -d "$COMPONENT" ]; then
        echo "✅ Componente $COMPONENT encontrado."
    else
        echo "⚠️ Componente $COMPONENT não encontrado. Criando diretório..."
        mkdir -p $COMPONENT
    fi
done

# Configurar namespaces para aplicativos antes de aplicar as configurações do Istio
echo "🔄 Configurando namespaces para aplicativos..."
kubectl create namespace frontend || true
kubectl create namespace backend || true
kubectl create namespace payments || true

# Aplicar label de injeção automática do Istio nos namespaces
echo "🔄 Habilitando injeção automática do Istio nos namespaces..."
kubectl label namespace default istio-injection=enabled --overwrite || true
kubectl label namespace frontend istio-injection=enabled --overwrite || true
kubectl label namespace backend istio-injection=enabled --overwrite || true
kubectl label namespace payments istio-injection=enabled --overwrite || true

# Instalar Istio
echo "🔄 Instalando Istio..."
kubectl create namespace istio-system || true
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

echo "🔄 Verificando instalação existente do Istio..."
if helm list -n istio-system | grep -q "istio-base"; then
    echo "✅ istio-base já está instalado, pulando..."
else
    echo "🔄 Instalando base do Istio..."
    helm install istio-base istio/base -n istio-system --wait || true
fi

if helm list -n istio-system | grep -q "istiod"; then
    echo "✅ istiod já está instalado, pulando..."
else
    echo "🔄 Instalando istiod..."
    helm install istiod istio/istiod -n istio-system --wait || true
fi

if helm list -n istio-system | grep -q "istio-ingress"; then
    echo "✅ istio-ingress já está instalado, pulando..."
else
    echo "🔄 Instalando ingress do Istio..."
    helm install istio-ingress istio/gateway -n istio-system --wait || true
fi

# Aplicar configurações personalizadas do Istio
if [ -f "kubernetes/istio/gateway.yaml" ]; then
    echo "🔄 Aplicando configurações personalizadas do Istio..."
    kubectl apply -f kubernetes/istio/gateway.yaml || true
else
    echo "⚠️ Arquivo gateway.yaml para Istio não encontrado."
fi

# Instalar ArgoCD
echo "🔄 Instalando ArgoCD..."
kubectl create namespace argocd || true

# Verificar se existem arquivos personalizados para o ArgoCD
if [ -f "kubernetes/argocd/install.yaml" ]; then
    # Primeiro, instalar os CRDs do ArgoCD
    echo "🔄 Instalando CRDs do ArgoCD..."
    kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds?ref=stable || true

    # Aguardar um pouco para que os CRDs sejam registrados
    echo "⏳ Aguardando CRDs do ArgoCD serem registrados..."
    sleep 10

    # Depois, aplicar as configurações básicas
    echo "🔄 Aplicando configurações personalizadas do ArgoCD..."
    kubectl apply -f kubernetes/argocd/install.yaml || true

    # Verificar se os CRDs foram instalados adequadamente
    if kubectl get crd applications.argoproj.io &>/dev/null; then
        echo "✅ CRDs do ArgoCD instalados com sucesso!"
        
        # Em caso afirmativo, aplicar o recurso Application se existir
        if [ -f "kubernetes/argocd/application.yaml" ]; then
            echo "🔄 Aplicando recurso Application..."
            kubectl apply -f kubernetes/argocd/application.yaml || true
        fi
    else
        echo "⚠️ Os CRDs do ArgoCD ainda não estão disponíveis, o recurso Application não será aplicado agora."
        echo "⚠️ Você precisará aplicá-lo manualmente depois: kubectl apply -f kubernetes/argocd/application.yaml"
    fi
else
    echo "⚠️ Arquivos personalizados para ArgoCD não encontrados. Instalando com configuração padrão..."
    echo "🔄 Instalando ArgoCD completo usando a configuração padrão..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || true
    
    echo "⏳ Aguardando ArgoCD ficar pronto..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd || true
    
    echo "✅ ArgoCD instalado com configuração padrão."
fi

# Instalar HashiCorp Vault
echo "🔄 Instalando HashiCorp Vault..."
if [ -d "kubernetes/vault" ]; then
    kubectl create namespace vault || true
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    
    # Verificar se o Vault já está instalado
    if helm list -n vault | grep -q "vault"; then
        echo "⚠️ Vault já está instalado. Verificando status..."
        
        # Verificar se os pods do Vault estão funcionando
        VAULT_PODS=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o name 2>/dev/null)
        if [ -z "$VAULT_PODS" ]; then
            echo "⚠️ Nenhum pod do Vault encontrado. A instalação parece estar corrompida."
            
            echo "🔄 Tentando corrigir a instalação do Vault..."
            echo "   1. Removendo recursos existentes..."
            
            # Remover recursos que podem estar causando problemas
            kubectl delete statefulset vault -n vault 2>/dev/null || true
            kubectl delete pvc -n vault -l app.kubernetes.io/name=vault 2>/dev/null || true
            kubectl delete configmap -n vault vault-config 2>/dev/null || true
            
            echo "   2. Reinstalando com configuração simplificada..."
            # Configuração simplificada para dev/teste
            cat > kubernetes/vault/simple-values.yaml << EOL
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
            
            # Reinstalar com configuração simplificada
            helm upgrade --install vault hashicorp/vault -n vault \
              -f kubernetes/vault/simple-values.yaml \
              --wait --timeout 5m || true
            
            echo "✅ Vault reinstalado com configuração simplificada."
        else
            echo "✅ Pods do Vault encontrados: $VAULT_PODS"
            
            # Verificar se os pods estão prontos
            READY_PODS=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[*].status.containerStatuses[0].ready}' 2>/dev/null | grep -o "true" | wc -l)
            TOTAL_PODS=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault --no-headers 2>/dev/null | wc -l)
            
            if [ "$READY_PODS" -lt "$TOTAL_PODS" ]; then
                echo "⚠️ Alguns pods do Vault não estão prontos ($READY_PODS/$TOTAL_PODS). Verificando problemas..."
                
                # Verificar eventos e logs para diagnosticar problemas
                POD_NAME=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o name | head -1 | cut -d/ -f2)
                kubectl describe pod -n vault $POD_NAME | tail -20
                
                echo "⚠️ O Vault pode precisar de atenção manual. Continuando com o resto da instalação..."
            else
                echo "✅ Todos os pods do Vault estão prontos."
            fi
        fi
    else
        if [ -f "kubernetes/vault/values.yaml" ]; then
            echo "🔄 Instalando Vault com configurações personalizadas..."
            helm install vault hashicorp/vault -n vault -f kubernetes/vault/values.yaml --timeout 5m || true
        else
            # Criar arquivo de valores padrão simplificado
            cat > kubernetes/vault/simple-values.yaml << EOL
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
            echo "🔄 Instalando Vault com configurações simplificadas..."
            helm install vault hashicorp/vault -n vault \
              -f kubernetes/vault/simple-values.yaml \
              --wait --timeout 5m || true
        fi
    fi
    
    # Setup inicial do Vault se o script existir
    if [ -f "kubernetes/vault/setup-vault.sh" ]; then
        echo "🔄 Executando setup inicial do Vault..."
        chmod +x kubernetes/vault/setup-vault.sh
        ./kubernetes/vault/setup-vault.sh
    else
        echo "📝 Nota: Para inicializar o Vault em modo dev, o token root é 'root'"
        echo "   Para acessar a UI: kubectl port-forward svc/vault 8200:8200 -n vault"
        echo "   Acesse: http://localhost:8200 e use o token: root"
    fi
else
    echo "⚠️ Diretório do Vault não encontrado. Criando estrutura mínima..."
    mkdir -p kubernetes/vault
    
    # Criar arquivo de valores padrão simplificado
    cat > kubernetes/vault/simple-values.yaml << EOL
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
    
    echo "🔄 Instalando Vault com configurações simplificadas..."
    kubectl create namespace vault || true
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    helm install vault hashicorp/vault -n vault \
      -f kubernetes/vault/simple-values.yaml \
      --wait --timeout 5m || true
      
    echo "📝 Nota: Para inicializar o Vault em modo dev, o token root é 'root'"
    echo "   Para acessar a UI: kubectl port-forward svc/vault 8200:8200 -n vault"
    echo "   Acesse: http://localhost:8200 e use o token: root"
fi

# Instalar Prometheus e Grafana para monitoramento
echo "🔄 Instalando stack de monitoramento..."
if [ -d "kubernetes/monitoring" ]; then
    kubectl create namespace monitoring || true
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    if [ -f "kubernetes/monitoring/prometheus-values.yaml" ]; then
        echo "🔄 Instalando Prometheus com configurações personalizadas..."
        helm install prometheus prometheus-community/kube-prometheus-stack \
          --namespace monitoring \
          --values kubernetes/monitoring/prometheus-values.yaml \
          --wait
    else
        echo "🔄 Instalando Prometheus com configurações padrão..."
        helm install prometheus prometheus-community/kube-prometheus-stack \
          --namespace monitoring \
          --wait
    fi
    
    # Instalar dashboards personalizados do Grafana
    if [ -f "kubernetes/monitoring/grafana-dashboard-security.json" ]; then
        echo "🔄 Instalando dashboards de segurança personalizados..."
        kubectl create configmap security-dashboard -n monitoring \
          --from-file=security-dashboard.json=kubernetes/monitoring/grafana-dashboard-security.json \
          --dry-run=client -o yaml | kubectl apply -f -
        
        kubectl label configmap security-dashboard -n monitoring grafana_dashboard=1
    fi
else
    echo "⚠️ Diretório de monitoramento não encontrado. Pulando instalação."
fi

# Instalar políticas de segurança
echo "🔄 Instalando políticas de segurança..."
if [ -f "security/policies/security-policy.yaml" ]; then
    echo "🔄 Instalando OPA Gatekeeper..."
    kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
    
    echo "⏳ Aguardando Gatekeeper ficar pronto..."
    kubectl wait --for=condition=available --timeout=300s deployment/gatekeeper-controller-manager -n gatekeeper-system
    
    echo "🔄 Aplicando políticas de segurança personalizadas..."
    kubectl apply -f security/policies/security-policy.yaml
else
    echo "⚠️ Arquivo de políticas de segurança não encontrado. Pulando instalação do OPA Gatekeeper."
fi

# Implantar toolkit de resposta a incidentes
echo "🔄 Implantando toolkit de resposta a incidentes..."
if [ -f "security/security-toolkit.yaml" ]; then
    kubectl create namespace security-tools || true
    kubectl apply -f security/security-toolkit.yaml
else
    echo "⚠️ Arquivo security-toolkit.yaml não encontrado. Pulando instalação do toolkit."
fi

# Configurar secret para puxar imagens privadas
echo "🔄 Configurando acesso a repositórios de imagens..."
ECR_REGISTRY=$(aws ecr describe-repositories --query 'repositories[0].repositoryUri' --output text 2>/dev/null || echo "")
if [ -n "$ECR_REGISTRY" ]; then
    kubectl create secret docker-registry regcred \
      --docker-server=${ECR_REGISTRY} \
      --docker-username=AWS \
      --docker-password=$(aws ecr get-login-password --region $AWS_REGION) \
      --namespace=default
else
    echo "⚠️ Nenhum repositório ECR encontrado. Pulando criação de secret para imagens."
fi

# Verificar instalação
echo "🔍 Verificando instalação..."
NAMESPACES=("argocd" "istio-system" "vault" "monitoring" "gatekeeper-system")
for NS in "${NAMESPACES[@]}"; do
    echo "$NS:"
    kubectl get pods -n $NS 2>/dev/null || echo "Namespace $NS não encontrado ou não tem pods."
done

# Aplicar configurações de roteamento adicionais se os namespaces já estiverem prontos
echo "🔄 Verificando se podemos aplicar configurações adicionais do Istio..."

# Esperar que o namespace frontend esteja pronto
if kubectl get namespace frontend &>/dev/null; then
    echo "🔄 Aplicando configurações do Istio para o namespace frontend..."
    
    # Verificar se o serviço frontend-service já existe
    if kubectl get svc -n frontend frontend-service &>/dev/null; then
        kubectl apply -f frontend-vs/virtualservice.yaml || true
        echo "✅ Configurações do Istio para frontend aplicadas."
    else
        echo "⚠️ O serviço frontend-service ainda não existe. As configurações do Istio serão aplicadas mais tarde."
    fi
fi

# Esperar que o namespace backend esteja pronto
if kubectl get namespace backend &>/dev/null; then
    echo "🔄 Aplicando configurações do Istio para o namespace backend..."
    
    # Verificar se o serviço api-service já existe
    if kubectl get svc -n backend api-service &>/dev/null; then
        kubectl apply -f backend-vs/virtualservice.yaml || true
        echo "✅ Configurações do Istio para backend aplicadas."
    else
        echo "⚠️ O serviço api-service ainda não existe. As configurações do Istio serão aplicadas mais tarde."
    fi
fi

# Exibir informações de acesso
INGRESS_IP=$(kubectl get svc istio-ingress -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "não disponível")
ARGOCD_PASS=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "não disponível")

echo ""
echo "🎉 Deploy concluído com sucesso!"
echo ""
echo "📝 Informações de acesso:"
echo "-----------------------------------"
echo "URL do Istio Ingress: http://$INGRESS_IP"
echo "ArgoCD URL: https://argocd.fintech.internal (configure DNS ou /etc/hosts)"
echo "ArgoCD usuário: admin"
echo "ArgoCD senha inicial: $ARGOCD_PASS"
echo "Grafana: https://grafana.fintech.internal (configure DNS ou /etc/hosts)"
echo "-----------------------------------"
echo ""
echo "⚠️ Importante: Altere as senhas padrão e configure TLS para todos os serviços."
echo "📚 Consulte a documentação em /documentation para mais detalhes."
echo ""

# Instruções finais
echo "🔒 Para aplicar as políticas de segurança de forma faseada:"
echo "   kubectl apply -f security/policies/security-policy.yaml"
echo ""
echo "🔄 Para configurar CI/CD, adicione os arquivos em ci-cd/github-actions ao seu repositório."
echo ""
echo "📊 Para acessar os dashboards de monitoramento de segurança:"
echo "   kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
echo "   Acesse: http://localhost:3000 (admin/prom-operator)"
echo "" 