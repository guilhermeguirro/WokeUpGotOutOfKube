# Diretrizes de Segurança para Containers

## Introdução

Este documento fornece diretrizes para construção, distribuição e execução segura de containers na nossa plataforma Kubernetes. Seguir estas práticas é essencial para manter a postura de segurança da organização e atender aos requisitos regulatórios do setor financeiro.

## Requisitos Obrigatórios

### 1. Construção de Imagens

#### 1.1 Imagens Base
- Use apenas imagens base de fontes confiáveis e verificadas (Docker Hub Official, Google Container Registry, Amazon ECR)
- Prefira imagens minimais como Alpine, Distroless ou UBI Minimal
- Mantenha suas imagens base atualizadas para eliminar vulnerabilidades conhecidas

#### 1.2 Multistage Builds
- Utilize multistage builds para reduzir o tamanho final da imagem
- Separe ambientes de compilação e runtime para minimizar a superfície de ataque
- Exemplo:
  ```dockerfile
  FROM golang:1.20 as builder
  WORKDIR /app
  COPY . .
  RUN go build -o /app/myapp
  
  FROM alpine:3.17
  COPY --from=builder /app/myapp /usr/local/bin/
  USER 1000
  ENTRYPOINT ["myapp"]
  ```

#### 1.3 Pacotes e Dependências
- Instale apenas pacotes essenciais para a aplicação
- Remova ferramentas de desenvolvimento e debugging das imagens de produção
- Atualize regularmente pacotes para corrigir vulnerabilidades
- Use `--no-cache` durante instalação de pacotes quando apropriado

#### 1.4 Usuários Não-Root
- **NUNCA** execute aplicações como usuário root
- Crie usuários dedicados para aplicações
- Configure permissões apropriadas:
  ```dockerfile
  RUN addgroup -S appgroup && adduser -S appuser -G appgroup
  RUN chown -R appuser:appgroup /app
  USER appuser
  ```

#### 1.5 Secrets
- **NUNCA** inclua secrets diretamente no Dockerfile
- Use variáveis de ambiente, montagens de volume, ou Kubernetes Secrets/HashiCorp Vault
- Utilize o `docker build --secret` para injetar secrets durante o build

#### 1.6 Hadolint
- Valide todos os Dockerfiles com Hadolint antes de commit
- Configure a verificação Hadolint no pipeline CI/CD

### 2. Segurança de Distribuição

#### 2.1 Registros de Container
- Use apenas registros de containers privados e autenticados
- Habilite escaneamento de vulnerabilidades no registro
- Implemente controle de acesso baseado em papéis para o registro

#### 2.2 Assinatura de Imagens
- Assine todas as imagens utilizando Cosign ou Notary
- Verifique assinaturas antes da implantação
- Exemplo:
  ```bash
  # Assinatura
  cosign sign --key cosign.key ${REGISTRY}/${IMAGE}:${TAG}
  
  # Verificação
  cosign verify --key cosign.pub ${REGISTRY}/${IMAGE}:${TAG}
  ```

#### 2.3 Escaneamento de Vulnerabilidades
- Escaneie todas as imagens com Trivy antes do push para o registro
- Bloqueie o deployment de imagens com vulnerabilidades críticas ou altas
- Resescaneie periodicamente imagens implantadas

### 3. Runtime Seguro

#### 3.1 Configuração de Containers
- Configure `readOnlyRootFilesystem: true` sempre que possível
- Defina limites de CPU e memória explícitos para cada container
- Implemente health e readiness probes
- Configure `securityContext` apropriado:
  ```yaml
  securityContext:
    capabilities:
      drop:
      - ALL
    runAsNonRoot: true
    runAsUser: 1000
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
  ```

#### 3.2 Segurança de Rede
- Implemente políticas de rede restritivas
- Utilize mTLS com Istio para comunicação entre serviços
- Minimize a exposição de portas

#### 3.3 Perfis Seccomp
- Utilize perfis Seccomp para limitar syscalls disponíveis
- Configure `seccompProfile` no pod:
  ```yaml
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  ```

#### 3.4 AppArmor/SELinux
- Utilize AppArmor ou SELinux quando apropriado
- Desenvolva perfis personalizados para aplicações críticas

#### 3.5 Detecção de Runtime
- Implemente Falco para detecção de comportamentos suspeitos
- Configure alertas para atividades anômalas
- Estabeleça procedimentos de resposta a incidentes

## Verificação Automatizada

A conformidade com estas diretrizes é verificada automaticamente por:

1. **Pipeline de CI/CD**:
   - Hadolint para verificação de Dockerfile
   - Trivy para escaneamento de vulnerabilidades
   - Checkov para verificação de configuração Kubernetes

2. **Kubernetes**:
   - Políticas Kyverno para garantir conformidade
   - Gatekeeper para validação de admissão
   - Falco para detecção de comportamento em runtime

## Exemplos de Arquivos Conformes

### Dockerfile Seguro
```dockerfile
FROM alpine:3.17 AS builder
WORKDIR /app
COPY . .
RUN apk add --no-cache build-base && \
    make build && \
    rm -rf /var/cache/apk/*

FROM alpine:3.17
RUN apk add --no-cache ca-certificates && \
    addgroup -S appgroup && adduser -S appuser -G appgroup && \
    mkdir -p /app/data && \
    chown -R appuser:appgroup /app
COPY --from=builder --chown=appuser:appgroup /app/bin/myapp /app/
WORKDIR /app
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O- http://localhost:8080/health || exit 1
ENTRYPOINT ["/app/myapp"]
```

### Kubernetes Deployment Seguro
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: prod
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: api
    app.kubernetes.io/part-of: finance-system
    app.kubernetes.io/managed-by: argocd
    security.fintech.io/scanned: "true"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        app.kubernetes.io/name: myapp
        app.kubernetes.io/instance: prod
        app.kubernetes.io/version: "1.0.0"
        app.kubernetes.io/component: api
        app.kubernetes.io/part-of: finance-system
        app.kubernetes.io/managed-by: argocd
        security.fintech.io/scanned: "true"
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
        fsGroup: 1000
      containers:
      - name: myapp
        image: registry.example.com/myapp:1.0.0
        imagePullPolicy: Always
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 1000
          runAsGroup: 1000
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
        ports:
        - containerPort: 8080
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: data
          mountPath: /app/data
      volumes:
      - name: tmp
        emptyDir: {}
      - name: data
        persistentVolumeClaim:
          claimName: myapp-data
```

## Exceções

Exceções a estas diretrizes serão concedidas apenas nos seguintes casos:
1. Necessidade técnica documentada e aprovada pelo time de segurança
2. Componentes de terceiros que não podem ser modificados
3. Sistemas legados em processo de migração

Todas as exceções devem ser documentadas, aprovadas formalmente, e revisadas trimestralmente.

## Atualizações e Governança

Estas diretrizes serão revisadas e atualizadas:
- Trimestralmente
- Após incidentes de segurança relevantes
- Quando novas tecnologias ou práticas forem adotadas

Sugestões de alterações devem ser enviadas via pull request para revisão pela equipe de segurança. 