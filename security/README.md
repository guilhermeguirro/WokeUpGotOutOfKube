# Políticas de Segurança (Security Policies)

Este diretório contém políticas de segurança para proteger nosso ambiente Kubernetes usando [Kyverno](https://kyverno.io/), uma engine de políticas para Kubernetes que aplica regras de segurança automaticamente.

## Estrutura do Diretório

```
security/
├── kyverno/
│   ├── network-policies.yaml       # Políticas para rede
│   └── policy-enforcement.yaml     # Políticas para segurança de pods
```

## Políticas de Rede (`network-policies.yaml`)

Estas políticas garantem que todo o tráfego de rede no cluster seja explicitamente controlado:

- **Require Network Policy** - Garante que cada namespace tenha pelo menos uma NetworkPolicy definida
- **Validate Default Deny Policy** - Valida que cada namespace tem uma política padrão de negação para tráfego de entrada e saída
- **Restrict External IPs** - Evita o uso de IPs externos em serviços para mitigar ataques de spoofing
- **Restrict Service Types** - Proíbe serviços NodePort e restringe serviços LoadBalancer a namespaces específicos
- **Validate Pod Probes** - Garante que os pods tenham probes de liveness e readiness configurados

## Políticas de Segurança de Pods (`policy-enforcement.yaml`)

Estas políticas aplicam as melhores práticas de segurança para todos os pods executados no cluster:

- **Restrict Privileged Containers** - Proíbe contêineres privilegiados com acesso completo ao host
- **Restrict HostPath Volumes** - Restringe o uso de volumes hostPath que montam diretórios do host
- **Restrict Host Namespaces** - Restringe o uso de namespaces do host (hostNetwork, hostPID, hostIPC)
- **Require Seccomp Profile** - Requer que todos os pods usem perfis Seccomp para limitar chamadas de sistema
- **Disallow Capabilities** - Proíbe capabilities perigosas do Linux (NET_ADMIN, SYS_ADMIN, etc.)
- **Restrict Proc Mount** - Restringe o tipo de montagem do diretório /proc
- **Require Non-Root User** - Requer que contêineres sejam executados como usuário não-root
- **Require Resource Limits** - Exige que todos os contêineres definam limites de recursos

## Como Usar

As políticas são aplicadas automaticamente a todos os recursos correspondentes em todo o cluster. Para instalar:

```bash
kubectl apply -f security/kyverno/network-policies.yaml
kubectl apply -f security/kyverno/policy-enforcement.yaml
```

Para verificar o status das políticas:

```bash
kubectl get clusterpolicies
```

## Exclusões

Algumas políticas têm exclusões para namespaces do sistema (como `kube-system`) ou tipos específicos de recursos (como `DaemonSets`) onde estas restrições podem não ser aplicáveis.

## Relatórios e Auditoria

O Kyverno fornece relatórios detalhados sobre o status de conformidade. Para verificar se seus recursos estão em conformidade:

```bash
kubectl get policyreports
``` 