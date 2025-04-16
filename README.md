# Fintech Application DevSecOps Infrastructure

This repository contains the DevSecOps infrastructure for a financial technology application, implementing security best practices throughout the CI/CD pipeline and infrastructure.

## Key Components

- **ArgoCD:** GitOps deployment management
- **Istio:** Service mesh for traffic management and security
- **Vault:** Secrets management
- **Kyverno/OPA Gatekeeper:** Policy enforcement
- **Falco:** Runtime security monitoring
- **Monitoring Stack:** Prometheus and Grafana

## Getting Started

1. Clone this repository:
   ```
   git clone https://github.com/fintech-organization/devsecops-infrastructure.git
   cd devsecops-infrastructure
   ```

2. Set up your AWS credentials:
   ```
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_REGION="us-east-1"
   ```

3. Run the deployment script:
   ```
   ./deploy.sh
   ```

## Deployment Recovery Scripts

If you encounter issues with the deployment, we've included several scripts to help you recover:

1. **Full Infrastructure Recovery**

   The master script that fixes all components:
   ```
   ./restore-fintech.sh
   ```

2. **Individual Component Fixes**

   - ArgoCD recovery: `./fix-argocd.sh`
   - Security components: `./fix-security.sh`
   - Infrastructure diagnosis: `./fix-deployment.sh`

## Troubleshooting Common Issues

### Vault Deployment Issues

If you encounter issues with Vault deployment:

1. Check if Vault is running in dev mode (not for production):
   ```
   kubectl get statefulset vault -n vault -o yaml | grep -i "dev\|ha"
   ```

2. For persistence issues, you can switch to a simpler configuration:
   ```
   kubectl delete statefulset vault -n vault
   kubectl delete pvc -n vault -l app.kubernetes.io/name=vault
   ```

3. Then apply simpler values:
   ```
   helm upgrade --install vault hashicorp/vault -n vault --set "server.dev.enabled=true" --set "server.standalone.enabled=false" --set "server.dataStorage.enabled=false"
   ```

### Istio Issues

If Istio components don't install properly:

1. Check for existing installations:
   ```
   helm list -n istio-system
   ```

2. Verify individual component status:
   ```
   kubectl get pods -n istio-system
   kubectl describe pod -n istio-system [pod-name]
   ```

3. For gateway issues, apply configs manually:
   ```
   kubectl apply -f kubernetes/istio/gateway.yaml
   ```

### ArgoCD Synchronization Issues

If applications fail to sync:

1. Check application status:
   ```
   kubectl get applications -n argocd
   ```

2. View detailed sync info:
   ```
   kubectl describe application [app-name] -n argocd
   ```

3. Verify ArgoCD server logs:
   ```
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
   ```

## Security Components

The security infrastructure includes:

- **Network Policies:** Zero-trust network architecture
- **Pod Security Policies:** Enforce secure pod configuration
- **Secret Management:** HashiCorp Vault integration
- **Runtime Security:** Falco for behavior monitoring
- **Policy Enforcement:** Gatekeeper and Kyverno
- **Encryption:** TLS everywhere

## CI/CD Security Pipeline

Our CI/CD pipeline includes:

- Secret scanning with Gitleaks
- SAST with SonarCloud
- Dependency scanning with Snyk
- IaC security with Checkov
- Container scanning with Trivy

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## License

This project is proprietary and confidential. # fintech-devsecops
# fintech-devsecops
