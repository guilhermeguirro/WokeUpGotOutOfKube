# Implantação no Google Cloud Platform

Este diretório contém configurações e instruções para implantar a infraestrutura DevSecOps no Google Cloud Platform (GCP) usando Google Kubernetes Engine (GKE).

## Pré-requisitos

- Google Cloud SDK (gcloud) instalado e configurado
- kubectl instalado
- Config Connector CLI (cnrm) instalado
- Helm instalado
- Permissões adequadas no GCP (roles/owner ou permissões específicas)

## Configuração da Infraestrutura

O arquivo `gke-deployment.yaml` utiliza Config Connector para definir recursos GCP como código Kubernetes:

- Cluster GKE privado com configurações avançadas de segurança
- VPC dedicada com subnets privadas
- Cloud NAT para acesso à internet
- Nodepools dedicados para aplicações e componentes de segurança
- Binary Authorization para validação de imagens
- Artifact Registry para armazenamento seguro de imagens
- Workload Identity para autenticação e autorização

## Preparação do Ambiente GCP

Antes de implantar, você precisa criar um projeto GCP e configurar as APIs necessárias:

```bash
# Configurar projeto GCP
export PROJECT_ID=fintech-devsecops-project
export REGION=us-central1

# Criar projeto (se necessário)
gcloud projects create $PROJECT_ID --name="Fintech DevSecOps"

# Configurar projeto como default
gcloud config set project $PROJECT_ID

# Habilitar APIs necessárias
gcloud services enable container.googleapis.com \
    compute.googleapis.com \
    artifactregistry.googleapis.com \
    cloudkms.googleapis.com \
    containeranalysis.googleapis.com \
    binaryauthorization.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iam.googleapis.com
```

## Processo de Implantação

### 1. Configurar Config Connector

```bash
# Instalar Config Connector no seu ambiente
gcloud iam service-accounts create cnrm-system

# Dar permissões necessárias
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:cnrm-system@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/owner"

# Criar configuração para Config Connector
cat > configconnector.yaml <<EOF
apiVersion: core.cnrm.cloud.google.com/v1beta1
kind: ConfigConnector
metadata:
  name: configconnector.core.cnrm.cloud.google.com
spec:
  mode: cluster
  googleServiceAccount: cnrm-system@$PROJECT_ID.iam.gserviceaccount.com
EOF

# Aplicar recursos (substitua PROJECT_ID no arquivo gke-deployment.yaml)
sed -i "s/fintech-devsecops-project/$PROJECT_ID/g" gke-deployment.yaml

# Aplicar configuração usando kubectl
kubectl apply -f configconnector.yaml
kubectl apply -f gke-deployment.yaml

# Aguardar criação dos recursos
kubectl wait --for=condition=Ready ContainerCluster/fintech-cluster --timeout=15m
```

### 2. Configurar Acesso ao Cluster

```bash
# Obter credenciais para o GKE
gcloud container clusters get-credentials fintech-cluster --region=$REGION

# Verificar conexão
kubectl get nodes
```

### 3. Implantar Componentes de Segurança e Monitoramento

```bash
# Instalar Kyverno
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace

# Aplicar Políticas de Segurança Kyverno
kubectl apply -f ../../security/kyverno/network-policies.yaml
kubectl apply -f ../../security/kyverno/policy-enforcement.yaml

# Instalar HashiCorp Vault com GCP KMS Auto-Unseal
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault --namespace vault --create-namespace \
  --set "server.dev.enabled=false" \
  --set "server.ha.enabled=true" \
  --set "server.ha.replicas=3" \
  --set "server.gcp.project=$PROJECT_ID" \
  --set "server.gcp.region=$REGION"

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

# Instalar Stack de Monitoramento
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
kubectl create namespace monitoring

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.enabled=true

# Instalar Falco
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco --namespace falco --create-namespace
```

### 4. Configurar Binary Authorization

```bash
# Criar política de Binary Authorization
gcloud container binauthz policy export > policy.yaml

# Editar policy.yaml para adicionar regras de validação de assinatura

# Importar política atualizada
gcloud container binauthz policy import policy.yaml
```

### 5. Configurar Cloud Armor para Proteção de WAF

```bash
# Criar política de segurança Cloud Armor
gcloud compute security-policies create fintech-security-policy \
    --description "WAF para proteção de aplicações Fintech"

# Adicionar regras padrão de OWASP Top 10
gcloud compute security-policies rules create 1000 \
    --security-policy fintech-security-policy \
    --expression "evaluatePreconfiguredExpr('xss-stable')" \
    --action deny-403 \
    --description "XSS Protection"

# Configurar Cloud Armor no BackendConfig para uso com Ingress
cat > backend-config.yaml <<EOF
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: fintech-backend-config
  namespace: istio-system
spec:
  securityPolicy:
    name: fintech-security-policy
EOF

kubectl apply -f backend-config.yaml
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

# Verificar Binary Authorization
gcloud container binauthz policy export

# Verificar saúde do Vault
kubectl exec -it vault-0 -n vault -- vault status

# Verificar VPC Service Controls (se configurado)
gcloud access-context-manager perimeters describe PERIMETER_NAME

# Verificar implantação do Istio
istioctl analyze
```

## Monitoramento e Observabilidade

```bash
# Acessar dashboard do Grafana
kubectl port-forward svc/prometheus-grafana 8080:80 -n monitoring
# Acesse http://localhost:8080 (usuário: admin, senha obtida via: kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode)

# Configurar Cloud Operations (Stackdriver)
kubectl apply -f stackdriver-adapter.yaml
```

## Backup e Recuperação

```bash
# Configurar Backup for GKE
gcloud beta container backup-restore backup-plans create fintech-backup-plan \
    --project=$PROJECT_ID \
    --location=$REGION \
    --cluster=projects/$PROJECT_ID/locations/$REGION/clusters/fintech-cluster \
    --include-secrets \
    --include-volume-data \
    --cron-schedule="0 2 * * *"
```

## Limpeza

Para remover a infraestrutura:

```bash
# Remover recursos via Config Connector
kubectl delete -f gke-deployment.yaml

# Ou excluir projeto completo (cuidado!)
gcloud projects delete $PROJECT_ID
``` 