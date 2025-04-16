# ArgoCD Configuration for Fintech Application

This directory contains the ArgoCD configurations for managing the deployment of our Fintech application and required infrastructure components in a Kubernetes cluster.

## Structure

```
kubernetes/argocd/
├── applications/           # Individual Application manifests
│   ├── fintech-app.yaml    # Core fintech application
│   ├── monitoring.yaml     # Monitoring stack
│   └── security.yaml       # Security components
├── applicationsets/        # ApplicationSet definitions for automated application creation
│   └── fintech-deployments.yaml # Generates applications for all environments
├── projects/               # AppProject definitions
│   ├── fintech-app.yaml    # Project for application components
│   └── infrastructure.yaml # Project for infrastructure components 
└── values.yaml            # ArgoCD Helm chart values
```

## Usage

1. Install ArgoCD using Helm with our custom values:
   ```
   helm install argocd argo/argo-cd -n argocd --create-namespace -f values.yaml
   ```

2. Apply the AppProject definitions:
   ```
   kubectl apply -f projects/
   ```

3. Apply the ApplicationSet definitions:
   ```
   kubectl apply -f applicationsets/
   ```

4. Apply individual applications:
   ```
   kubectl apply -f applications/
   ```

## Security Considerations

Our ArgoCD setup includes several security enhancements:

- RBAC with fine-grained access control
- TLS enabled for all components
- Integration with external auth provider
- Network policies to restrict traffic
- Resources configured with security contexts
- Regular syncing of security components

## Projects

### fintech-app
Contains applications related to the core business functionality, with restricted permissions.

### infrastructure
Contains infrastructure components with elevated cluster-wide permissions, including monitoring and security tools.

## Auto-syncing

Most applications are configured for automatic syncing to ensure GitOps practices are followed. This includes:

- Automatic pruning of removed resources
- Self-healing for drift detection
- Retry mechanisms for transient failures

## Troubleshooting

If sync issues occur:
1. Check application status: `kubectl get applications -n argocd`
2. View sync details: `kubectl describe application <app-name> -n argocd`
3. Check ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server` 