# 🛡️ Fintech Application DevSecOps Infrastructure

[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://github.com/fintech-organization/devsecops-infrastructure)
[![Security: Fortified](https://img.shields.io/badge/security-fortified-blue.svg)](https://github.com/fintech-organization/devsecops-infrastructure)
[![Kubernetes](https://img.shields.io/badge/kubernetes-1.24+-informational?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=flat&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D.svg?style=flat&logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)

This repository contains the DevSecOps infrastructure for a financial technology application, implementing security best practices throughout the CI/CD pipeline and infrastructure.

## 🔑 Key Components

- 🚢 **ArgoCD**: GitOps deployment management
- 🕸️ **Istio**: Service mesh for traffic management and security
- 🔐 **Vault**: Secrets management
- 🛂 **Kyverno/OPA Gatekeeper**: Policy enforcement
- 🔍 **Falco**: Runtime security monitoring
- 📊 **Monitoring Stack**: Prometheus and Grafana

## 🚀 Getting Started

### Prerequisites

- Kubernetes v1.24+
- Helm v3.8+
- kubectl configured with cluster access
- AWS CLI v2

### Installation

1. Clone this repository:

```bash
git clone https://github.com/fintech-organization/devsecops-infrastructure.git
cd devsecops-infrastructure
```

2. Set up your AWS credentials:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"
```

3. Run the deployment script:

```bash
./deploy.sh
```

## 🔄 Deployment Recovery Scripts

If you encounter issues with the deployment, we've included several scripts to help you recover:

### 🛠️ Full Infrastructure Recovery

The master script that fixes all components:

```bash
./restore-fintech.sh
```

### 🔧 Individual Component Fixes

- **ArgoCD recovery**: `./fix-argocd.sh`
- **Security components**: `./fix-security.sh`
- **Infrastructure diagnosis**: `./fix-deployment.sh`

## ⚠️ Troubleshooting Common Issues

### Vault Deployment Issues 🔐

If you encounter issues with Vault deployment:

1. Check if Vault is running in dev mode (not for production):

```bash
kubectl get statefulset vault -n vault -o yaml | grep -i "dev\|ha"
```

2. For persistence issues, you can switch to a simpler configuration:

```bash
kubectl delete statefulset vault -n vault
kubectl delete pvc -n vault -l app.kubernetes.io/name=vault
```

3. Then apply simpler values:

```bash
helm upgrade --install vault hashicorp/vault -n vault \
  --set "server.dev.enabled=true" \
  --set "server.standalone.enabled=false" \
  --set "server.dataStorage.enabled=false"
```

### Istio Issues 🕸️

If Istio components don't install properly:

1. Check for existing installations:

```bash
helm list -n istio-system
```

2. Verify individual component status:

```bash
kubectl get pods -n istio-system
kubectl describe pod -n istio-system [pod-name]
```

3. For gateway issues, apply configs manually:

```bash
kubectl apply -f kubernetes/istio/gateway.yaml
```

### ArgoCD Synchronization Issues 🚢

If applications fail to sync:

1. Check application status:

```bash
kubectl get applications -n argocd
```

2. View detailed sync info:

```bash
kubectl describe application [app-name] -n argocd
```

3. Verify ArgoCD server logs:

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

## 🔒 Security Components

The security infrastructure includes:

| Component | Purpose | Status |
|-----------|---------|--------|
| 🔒 **Network Policies** | Zero-trust network architecture | ✅ Enabled |
| 🛡️ **Pod Security Policies** | Enforce secure pod configuration | ✅ Enabled |
| 🗝️ **Secret Management** | HashiCorp Vault integration | ✅ Enabled |
| 👁️ **Runtime Security** | Falco for behavior monitoring | ✅ Enabled |
| 📜 **Policy Enforcement** | Gatekeeper and Kyverno | ✅ Enabled |
| 🔐 **Encryption** | TLS everywhere | ✅ Enabled |

## 🔄 CI/CD Security Pipeline

Our CI/CD pipeline includes:

| Stage | Tool | Purpose |
|-------|------|---------|
| 🔍 **Secret Scanning** | Gitleaks | Detect secrets in code |
| 🧪 **SAST** | SonarCloud | Static code analysis |
| 📦 **Dependency Scanning** | Snyk | Detect vulnerable dependencies |
| ☁️ **IaC Security** | Checkov | Infrastructure as Code scanning |
| 🐳 **Container Scanning** | Trivy | Image vulnerability scanning |

## 📂 Repository Structure

```
.
├── kubernetes/           # Kubernetes manifests
│   ├── argocd/           # ArgoCD configuration
│   ├── istio/            # Istio service mesh configs
│   ├── security/         # Security components
│   └── monitoring/       # Prometheus & Grafana
├── scripts/              # Deployment scripts
├── terraform/            # Infrastructure as Code
├── docs/                 # Documentation
└── tests/                # Infrastructure tests
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📝 License

[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)

This project is proprietary and confidential.

---

<p align="center">
  <img src="https://img.shields.io/badge/Built%20with-💙-blue" alt="Built with love">
  <img src="https://img.shields.io/badge/Secured%20with-🔒-green" alt="Secured">  
  <img src="https://img.shields.io/badge/DevSecOps-✅-success" alt="DevSecOps">
</p> 