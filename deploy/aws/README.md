# Implantação na AWS

Este diretório contém configurações e instruções para implantar a infraestrutura DevSecOps em AWS.

## Pré-requisitos

- AWS CLI configurado com acesso administrativo
- kubectl instalado
- eksctl instalado
- helm instalado
- aws-iam-authenticator instalado

## Configuração do Cluster EKS

O arquivo `eks-deployment.yaml` define a configuração do cluster utilizando eksctl, incluindo:

- Cluster EKS com Kubernetes 1.29
- VPC com subnets privadas e públicas
- Grupos de nós com auto-scaling
- Nós dedicados para componentes de segurança
- Integrações com serviços AWS (Load Balancer, EBS CSI, etc.)
- Monitoramento com CloudWatch

## Processo de Implantação

### 1. Criar Cluster EKS

```bash
# Revisar e atualizar eks-deployment.yaml com IDs específicos da sua infraestrutura
# Modificar vpc.id, vpc.securityGroup e IDs de subnets conforme sua conta AWS

# Criar o cluster
eksctl create cluster -f eks-deployment.yaml
```

### 2. Configurar kubectl

```bash
aws eks update-kubeconfig --name fintech-cluster --region us-east-1
```

### 3. Instalar Componentes de Segurança e Monitoramento

```bash
# Instalar Kyverno
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace

# Aplicar Políticas de Segurança Kyverno
kubectl apply -f ../../security/kyverno/network-policies.yaml
kubectl apply -f ../../security/kyverno/policy-enforcement.yaml

# Instalar HashiCorp Vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault --namespace vault --create-namespace \
  --set "server.dev.enabled=false" \
  --set "server.ha.enabled=true" \
  --set "server.ha.replicas=3"

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
  --set grafana.enabled=true \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Instalar Falco
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco --namespace falco --create-namespace
```

### 4. Instalar Toolkit de Segurança

```bash
kubectl apply -f ../../security/security-toolkit/security-toolkit.yaml
```

### 5. Configurar Autenticação e RBAC

```bash
# Aplicar configurações RBAC para equipes
kubectl apply -f ../../rbac/team-permissions.yaml
```

## Verificação de Segurança

Após a implantação, execute as seguintes verificações:

```bash
# Verificar status das políticas Kyverno
kubectl get clusterpolicies

# Verificar relatórios de conformidade de políticas
kubectl get policyreports --all-namespaces

# Verificar saúde do Vault
kubectl exec -it vault-0 -n vault -- vault status

# Verificar implantação do Istio
istioctl analyze

# Verificar alertas do Falco
kubectl logs -l app=falco -n falco | grep -i critical
```

## Configuração Adicional

### AWS KMS para Criptografia

Para habilitar criptografia de segredos utilizando AWS KMS:

```bash
# Criar chave KMS para o cluster
aws kms create-key --description "EKS Secret Encryption Key" --output text --query 'KeyMetadata.Arn'

# Atualizar cluster para usar criptografia de segredos
aws eks update-cluster-config \
  --name fintech-cluster \
  --region us-east-1 \
  --encryption-config '[{"resources":["secrets"],"provider":{"keyArn":"<KMS_KEY_ARN>"}}]'
```

## Limpeza

Para remover o cluster e recursos associados:

```bash
# Remover aplicações gerenciadas pelo ArgoCD primeiro
argocd app delete --all

# Remover cluster EKS
eksctl delete cluster -f eks-deployment.yaml
``` 