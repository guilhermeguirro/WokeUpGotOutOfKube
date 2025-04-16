#!/bin/bash
# Script para configuração do HashiCorp Vault com integração Kubernetes

set -e

echo "🔐 Iniciando configuração do HashiCorp Vault..."

# Variáveis
export VAULT_ADDR=https://vault.vault.svc.cluster.local:8200
export VAULT_SKIP_VERIFY=true  # Apenas para ambiente de desenvolvimento, remover em produção

# Aguardar Vault estar pronto
echo "⏳ Aguardando Vault ficar disponível..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=vault -n vault --timeout=300s

# Obter status inicial
echo "🔍 Verificando status do Vault..."
kubectl exec -n vault vault-0 -- vault status || true

# Inicializar se necessário
INITIALIZED=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.initialized' || echo "false")
if [ "$INITIALIZED" == "false" ]; then
  echo "🔑 Inicializando Vault..."
  INIT_OUTPUT=$(kubectl exec -n vault vault-0 -- vault operator init -key-shares=5 -key-threshold=3 -format=json)
  
  # Salvar chaves e token em secrets do Kubernetes para backup
  echo "💾 Salvando chaves de inicialização (apenas para desenvolvimento - use HSM em produção)..."
  echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[]' > /tmp/vault-unseal-keys.txt
  echo $INIT_OUTPUT | jq -r '.root_token' > /tmp/vault-root-token.txt
  
  kubectl create secret generic vault-init -n vault \
    --from-file=unseal-keys=/tmp/vault-unseal-keys.txt \
    --from-file=root-token=/tmp/vault-root-token.txt
  
  # Limpar arquivos temporários
  rm /tmp/vault-unseal-keys.txt /tmp/vault-root-token.txt
  
  # Capturar token e chaves para uso posterior no script
  ROOT_TOKEN=$(echo $INIT_OUTPUT | jq -r '.root_token')
  UNSEAL_KEYS=($(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[]'))
else
  echo "✅ Vault já inicializado"
  
  # Recuperar token e chaves
  ROOT_TOKEN=$(kubectl get secret vault-init -n vault -o jsonpath='{.data.root-token}' | base64 --decode)
  readarray -t UNSEAL_KEYS < <(kubectl get secret vault-init -n vault -o jsonpath='{.data.unseal-keys}' | base64 --decode)
fi

# Unseal Vault em todos os pods
for i in {0..2}; do
  if kubectl get pod -n vault vault-$i &>/dev/null; then
    SEALED=$(kubectl exec -n vault vault-$i -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
    if [ "$SEALED" == "true" ]; then
      echo "🔓 Desbloqueando Vault no pod vault-$i..."
      for key in "${UNSEAL_KEYS[@]:0:3}"; do
        kubectl exec -n vault vault-$i -- vault operator unseal $key
      done
    else
      echo "✅ Vault no pod vault-$i já está desbloqueado"
    fi
  fi
done

# Configurar autenticação
echo "🔐 Configurando Vault..."
kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault auth enable kubernetes" || echo "Kubernetes auth já habilitado"

echo "🔧 Configurando papel do Kubernetes..."
kubectl exec -n vault vault-0 -- sh -c "
  VAULT_TOKEN=$ROOT_TOKEN vault write auth/kubernetes/config \
    kubernetes_host=\"https://\$KUBERNETES_PORT_443_TCP_ADDR:443\" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token
"

# Habilitar segredos
echo "🔧 Habilitando mecanismos de segredos..."
kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault secrets enable -path=secret kv-v2" || echo "Secret engine já habilitado"
kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault secrets enable transit" || echo "Transit já habilitado"
kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault secrets enable database" || echo "Database já habilitado"

# Configurar políticas para aplicações
echo "📝 Criando políticas para aplicações..."

cat <<EOF > /tmp/app-policy.hcl
path "secret/data/fintech/*" {
  capabilities = ["read"]
}

path "transit/decrypt/fintech-*" {
  capabilities = ["update"]
}

path "transit/encrypt/fintech-*" {
  capabilities = ["update"]
}
EOF

kubectl cp /tmp/app-policy.hcl vault/vault-0:/tmp/app-policy.hcl
kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault policy write fintech-app /tmp/app-policy.hcl"

# Configurar chaves de criptografia para a aplicação
echo "🔑 Configurando chaves de criptografia..."
kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault write -f transit/keys/fintech-payment"
kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault write -f transit/keys/fintech-user"

# Configurar role de Kubernetes
echo "👥 Configurando perfis de Kubernetes para aplicações..."
kubectl exec -n vault vault-0 -- sh -c "
  VAULT_TOKEN=$ROOT_TOKEN vault write auth/kubernetes/role/fintech-frontend \
    bound_service_account_names=frontend-sa \
    bound_service_account_namespaces=frontend \
    policies=fintech-app \
    ttl=1h
"

kubectl exec -n vault vault-0 -- sh -c "
  VAULT_TOKEN=$ROOT_TOKEN vault write auth/kubernetes/role/fintech-backend \
    bound_service_account_names=backend-sa \
    bound_service_account_namespaces=backend \
    policies=fintech-app \
    ttl=1h
"

kubectl exec -n vault vault-0 -- sh -c "
  VAULT_TOKEN=$ROOT_TOKEN vault write auth/kubernetes/role/fintech-payments \
    bound_service_account_names=payments-sa \
    bound_service_account_namespaces=payments \
    policies=fintech-app \
    ttl=1h
"

# Inserir alguns segredos de exemplo
echo "🔒 Inserindo segredos de exemplo..."
kubectl exec -n vault vault-0 -- sh -c "
  VAULT_TOKEN=$ROOT_TOKEN vault kv put secret/fintech/config \
    api_url=https://api.fintech.com \
    logging_level=info
"

kubectl exec -n vault vault-0 -- sh -c "
  VAULT_TOKEN=$ROOT_TOKEN vault kv put secret/fintech/database \
    username=app_user \
    password=ChangeMe!InProduction123 \
    connection_string=postgresql://db.fintech.internal:5432/fintech
"

# Configurar rotação automática de segredos
echo "🔄 Configurando rotação automática de segredos..."
kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault secrets tune -default-lease-ttl=24h -max-lease-ttl=768h secret/"

echo "✅ Configuração do Vault concluída!"
echo "🔑 Você pode acessar o Vault via https://vault.fintech.internal"
echo "💡 Use o token raiz apenas para administração inicial e crie tokens específicos para uso operacional"
echo "⚠️ Em ambiente de produção, considere usar um HSM para armazenar as chaves de unseal e rotacionar todas as senhas iniciais" 