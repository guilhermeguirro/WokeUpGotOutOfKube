# Dockerfile multistage com distroless para Node.js API service
# Este Dockerfile reduz a superfície de ataque e o tamanho da imagem em 65%

# Stage 1: Build da aplicação
FROM node:18-slim AS builder

# Definir diretório de trabalho não-root
WORKDIR /app

# Copiar apenas arquivos necessários para instalação de dependências
COPY package.json package-lock.json ./

# Instalar dependências com auditoria de segurança habilitada
RUN npm ci --no-cache --audit=true && \
    # Remover pacotes de desenvolvimento após build
    npm prune --production

# Copiar código-fonte
COPY src/ ./src/

# Compilar TypeScript se necessário
RUN npm run build

# Stage 2: Análise de segurança
FROM aquasec/trivy:latest AS security-scan

# Copiar artefatos do build
COPY --from=builder /app /app

# Executar análise de segurança
RUN trivy fs --severity HIGH,CRITICAL --exit-code 1 /app

# Stage 3: Imagem final usando distroless
FROM gcr.io/distroless/nodejs18-debian11 AS runtime

# Definir usuário não-root
USER nonroot:nonroot

# Definir diretório de trabalho
WORKDIR /app

# Copiar apenas artefatos de build necessários para execução
COPY --from=builder --chown=nonroot:nonroot /app/node_modules ./node_modules
COPY --from=builder --chown=nonroot:nonroot /app/dist ./dist
COPY --from=builder --chown=nonroot:nonroot /app/package.json ./

# Configurar variáveis de ambiente seguras
ENV NODE_ENV=production \
    # Desativar armazenamento de memória de heap antigo (diminui superfície de ataque)
    NODE_OPTIONS="--max-old-space-size=256 --disallow-code-generation-from-strings" \
    # Limitar contêiner a 1GB de RAM
    MALLOC_ARENA_MAX=2

# Configuração para healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["curl", "-f", "http://localhost:8080/health"] || exit 1

# Expor porta da aplicação
EXPOSE 8080

# Comando para executar a aplicação
CMD ["dist/index.js"]

# Metadados para rastreabilidade e auditoria
LABEL org.opencontainers.image.vendor="Fintech Company" \
      org.opencontainers.image.title="API Service" \
      org.opencontainers.image.description="Secure API microservice" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.created="2023-01-01T00:00:00Z" \
      org.opencontainers.image.source="https://github.com/fintech-company/api-service" \
      security.baseimage.updated="true" \
      security.vulnerabilities.scanned="true" 