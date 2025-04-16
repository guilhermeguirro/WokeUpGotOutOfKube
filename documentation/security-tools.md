# Security Tools Documentation

This document provides details on the security tools integrated into our DevSecOps pipeline and how to use them.

## Table of Contents

1. [Kyverno Policy Enforcement](#kyverno-policy-enforcement)
2. [Secret Scanning with Gitleaks](#secret-scanning-with-gitleaks)
3. [Infrastructure as Code Security with Checkov](#infrastructure-as-code-security-with-checkov)
4. [Container Security with Trivy](#container-security-with-trivy)
5. [Dependency Scanning with Snyk](#dependency-scanning-with-snyk)
6. [Security Toolkit Pod](#security-toolkit-pod)

## Kyverno Policy Enforcement

Our Kubernetes policy engine is Kyverno, which enforces security best practices across the cluster.

### How to Use

Current policies applied:
- Require resource limits and requests
- Disallow privileged containers
- Enforce non-root users
- Require security labels
- Block host network access
- Require security scanning
- Require seccomp profiles

### Testing Policy Compliance

Test a deployment manifest against policies:
```bash
kubectl create -f your-deployment.yaml --dry-run=server
```

## Secret Scanning with Gitleaks

Gitleaks scans repositories for secrets to prevent accidental exposure.

### How to Use

Run locally:
```bash
gitleaks detect --source . --config .github/gitleaks.toml
```

Scan is automatically run in the CI/CD pipeline on each PR.

## Infrastructure as Code Security with Checkov

Checkov performs static analysis of infrastructure code to find misconfigurations.

### How to Use

Run locally:
```bash
checkov -d terraform/ --config-file security/checkov/.checkov.yaml
```

### Custom Policies

Custom policies can be added to:
```
security/checkov/custom_policies/
```

## Container Security with Trivy

Trivy scans container images for vulnerabilities.

### How to Use

Scan a local image:
```bash
trivy image --config security/trivy/trivy-config.yaml your-image:tag
```

Scan running Kubernetes workloads:
```bash
trivy kubernetes --config security/trivy/trivy-config.yaml --namespace default all
```

## Dependency Scanning with Snyk

Snyk checks for vulnerabilities in application dependencies.

### How to Use

Run locally:
```bash
snyk test --all-projects --policy-path=security/snyk/.snyk
```

### Policy Management

To ignore vulnerabilities:
```bash
snyk ignore --id=SNYK-JS-SOMEPACKAGE-12345 --reason="Not exploitable in our setup" --expiry="2025-12-31"
```

## Security Toolkit Pod

The Security Toolkit provides a pod with security tools that can be used for incident response and security analysis.

### How to Use

Access the toolkit:
```bash
kubectl exec -it -n security-tools $(kubectl get pods -n security-tools -o jsonpath='{.items[0].metadata.name}') -- bash
```

### Available Commands

```bash
# Scan vulnerabilities in a namespace
scan_vulnerabilities default

# Investigate a pod
investigate_pod my-pod default

# Network isolation of a namespace
isolate_namespace compromised-namespace

# Restore network access
restore_namespace compromised-namespace
``` 