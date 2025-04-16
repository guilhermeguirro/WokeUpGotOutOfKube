# Runbook: Resposta a Incidentes de Segurança

## Objetivo

Este runbook fornece procedimentos detalhados para responder a incidentes de segurança na infraestrutura da Fintech, garantindo uma resposta rápida e eficaz para minimizar o impacto e restaurar a operação normal o mais rápido possível.

## Pré-requisitos

- Acesso ao painel de monitoramento (Grafana)
- Acesso ao ELK para análise de logs
- Credenciais de acesso ao ambiente AWS (privilégios adequados)
- Acesso ao cluster Kubernetes
- Contatos da equipe de resposta a incidentes

## Equipe de Resposta a Incidentes

| Função | Responsabilidade | Contato |
|--------|------------------|---------|
| Líder de Resposta | Coordenação geral | security-lead@fintech.com |
| Analista de Segurança | Análise técnica | security-analyst@fintech.com |
| Engenheiro DevOps | Remediação técnica | devops-oncall@fintech.com |
| Comunicação | Comunicação interna/externa | comms@fintech.com |
| Conformidade | Requisitos regulatórios | compliance@fintech.com |

## Níveis de Severidade

| Nível | Descrição | Tempo de Resposta | Exemplo |
|-------|-----------|-------------------|---------|
| SEV1 | Crítico - Violação ativa ou problema que afeta sistemas críticos | Imediato (< 15 min) | Violação de dados em produção, ransomware |
| SEV2 | Alto - Problema grave com potencial para se tornar crítico | < 1 hora | Vulnerabilidade crítica explorada, acesso não autorizado |
| SEV3 | Médio - Problema significativo que requer atenção | < 4 horas | Múltiplas tentativas de login mal-sucedidas, CVE crítica |
| SEV4 | Baixo - Problema menor sem impacto imediato | < 24 horas | Alerta de escaneamento, eventos de baixo risco |

## Fluxo de Resposta a Incidentes

### 1. Detecção e Triagem

**Fontes de Detecção:**
- Alertas do sistema de monitoramento (Prometheus/Grafana)
- Análise de logs (ELK)
- Relatórios de AWS GuardDuty
- Relatórios de usuários
- Auditorias de segurança

**Procedimento:**
1. Confirmar o alerta e verificar se é um verdadeiro positivo
2. Determinar o nível de severidade inicial
3. Registrar o incidente no sistema de tickets
4. Notificar as partes interessadas conforme a severidade

### 2. Contenção

**SEV1/SEV2:**
1. **Isolamento imediato**:
   ```bash
   # Isolar um namespace do Kubernetes (se aplicável)
   kubectl label namespace <namespace> network-policy=isolate
   kubectl apply -f security/policies/isolation/namespace-isolation.yaml
   
   # Revogar credenciais comprometidas
   aws iam update-access-key --access-key-id <ACCESS_KEY_ID> --status Inactive --user-name <USER_NAME>
   
   # Isolar instâncias EC2 (se aplicável)
   aws ec2 modify-instance-attribute --instance-id <INSTANCE_ID> --groups <ISOLATION_SECURITY_GROUP>
   ```

2. **Bloquear tráfego suspeito**:
   ```bash
   # Aplicar política de rede restritiva
   kubectl apply -f security/policies/incident-response/block-suspicious-traffic.yaml
   
   # Atualizar grupos de segurança AWS
   aws ec2 update-security-group-rule-descriptions-ingress --group-id <SECURITY_GROUP_ID> --ip-permissions <IP_PERMISSION>
   ```

**SEV3/SEV4:**
1. Monitorar de perto o problema
2. Implementar mitigações não disruptivas

### 3. Investigação

1. **Coleta de evidências**:
   ```bash
   # Captura de logs relevantes
   kubectl logs -n <namespace> <pod-name> --previous > /tmp/evidence/pod-logs.txt
   
   # Captura de tráfego
   kubectl debug node/<node-name> -it --image=nicolaka/netshoot -- tcpdump -i eth0 -w /tmp/evidence/network-capture.pcap
   
   # Coleta logs CloudTrail
   aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventSource,AttributeValue=<SOURCE> --start-time <START_TIME> --end-time <END_TIME> > /tmp/evidence/cloudtrail-events.json
   ```

2. **Análise de causa raiz**:
   - Revisar logs e alertas correlacionados
   - Analisar linhas do tempo do evento
   - Identificar vetores de ataque e métodos de exploração
   - Determinar escopo do impacto

### 4. Remediação

1. **Eliminação da ameaça**:
   ```bash
   # Remover pods comprometidos
   kubectl delete pod <pod-name> -n <namespace>
   
   # Aplicar patches de segurança
   kubectl apply -f manifests/patched-deployment.yaml
   
   # Atualizar imagens de contêiner para versões corrigidas
   kubectl set image deployment/<deployment-name> <container-name>=<new-image> -n <namespace>
   ```

2. **Restauração do serviço**:
   ```bash
   # Reimplantação de serviços a partir de imagens verificadas
   kubectl apply -f manifests/secure-deployment.yaml
   
   # Restaurar a partir de backups se necessário
   aws efs restore-backup --backup-id <BACKUP_ID> --target-path <TARGET_PATH>
   ```

3. **Verificação de segurança**:
   ```bash
   # Executar verificação de vulnerabilidades
   kubectl exec -it security-toolkit -- trivy image <image-name>
   
   # Verificar configurações
   kubectl exec -it security-toolkit -- kube-bench
   ```

### 5. Recuperação

1. **Monitoramento pós-incidente**:
   - Configurar alertas específicos baseados no incidente
   - Monitorar sinais de persistência ou retorno da ameaça
   - Verificar desempenho e comportamento do sistema

2. **Teste de segurança**:
   ```bash
   # Executar escaneamento de segurança
   kubectl exec -it security-toolkit -- nikto -h <target-service>
   
   # Verificar políticas de rede
   kubectl exec -it security-toolkit -- kube-hunter
   ```

### 6. Lições Aprendidas

1. Conduzir análise pós-incidente (com template documentado)
2. Documentar melhorias para prevenção futura
3. Atualizar runbooks e procedimentos com base nas lições aprendidas
4. Implementar quaisquer medidas preventivas identificadas

## Procedimentos Específicos

### Resposta a Violação de Dados

1. Identificar os dados afetados e seu escopo
2. Implementar contenção imediata dos sistemas afetados
3. Notificar o responsável de conformidade para avaliação regulatória
4. Preservar evidências para investigação forense
5. Preparar comunicação interna e externa conforme necessário

### Resposta a Malware/Ransomware

1. Isolar imediatamente os sistemas afetados
2. Desconectar sistemas da rede se necessário
3. Identificar o tipo e vetor de ataque
4. Restaurar a partir de backups limpos após contenção
5. Verificar a integridade dos sistemas restaurados

### Resposta a Acesso Não Autorizado

1. Revogar imediatamente as credenciais comprometidas
2. Implementar autenticação multifator se não estiver habilitada
3. Rotacionar todas as chaves e segredos relacionados
4. Revisar logs para determinar o escopo do acesso
5. Verificar alterações feitas durante o período de compromisso

## Ferramentas de Resposta a Incidentes

| Ferramenta | Propósito | Comando de Acesso |
|------------|-----------|-------------------|
| ELK Stack | Análise de logs | `https://elk.fintech.internal` |
| Grafana | Visualização de métricas | `https://grafana.fintech.internal` |
| Incident Response Toolkit | Conjunto de ferramentas forenses | `kubectl apply -f security/incident-response/toolkit.yaml` |
| AWS CLI | Gestão de recursos AWS | `aws --profile emergency-response` |
| Vault CLI | Rotação de segredos | `vault lease revoke -prefix <PREFIX>` |

## Notificação e Escalação

### Matriz de Notificação

| Severidade | Notificar | Método | Tempo |
|------------|-----------|--------|-------|
| SEV1 | Equipe de resposta, CTO, CISO | Telefone, SMS, Email | Imediato |
| SEV2 | Equipe de resposta, Gerentes | SMS, Email | < 30 min |
| SEV3 | Equipe de resposta | Email, Slack | < 2 horas |
| SEV4 | Analista de plantão | Email, Ticket | < 8 horas |

### Contatos Externos

| Organização | Circunstância | Contato |
|-------------|---------------|---------|
| AWS Support | Incidentes relacionados à infraestrutura AWS | Enterprise Support |
| CERT | Incidentes de segurança que afetam terceiros | incident@cert.org |
| Autoridades Financeiras | Violações de dados que afetam informações financeiras | compliance@fintech.com |

## Requisitos de Documentação

Para cada incidente de segurança, registre:

1. **Linha do tempo detalhada do incidente**
2. **Ações realizadas durante a resposta**
3. **Evidências coletadas**
4. **Escopo do impacto**
5. **Medidas de remediação implementadas**
6. **Lições aprendidas e recomendações**

## Conformidade e Relatórios

- Incidentes SEV1/SEV2 requerem notificação ao departamento jurídico dentro de 2 horas
- Violações de dados podem exigir notificação às autoridades reguladoras dentro de 72 horas
- Manter registros de todos os incidentes por pelo menos 3 anos para fins de auditoria

## Referências

- [Política de Segurança da Informação](../compliance/security-policy.md)
- [Plano de Resposta a Incidentes](../compliance/incident-response-plan.md)
- [Requisitos Regulatórios Financeiros](../compliance/regulatory-requirements.md)
- [Matriz de Contatos de Emergência](../contacts.md) 