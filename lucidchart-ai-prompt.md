# Lucidchart AI Diagram Prompt

Copy and paste this prompt into Lucidchart's "Create a diagram with AI" input field:

```
Create a comprehensive DevSecOps platform architecture diagram for financial applications using Kubernetes. Include:

1. Multi-cloud infrastructure layer with AWS EKS, Azure AKS, and GCP GKE clusters
2. Security controls layer with Kyverno policies, network policies, and Istio service mesh
3. Secrets management with HashiCorp Vault showing dynamic secrets workflow
4. CI/CD pipeline on the left with SonarCloud, Snyk, Checkov, and Gitleaks security scanning
5. GitOps deployment with ArgoCD 
6. Monitoring and response on the right with Falco and observability stack (Prometheus, Loki, Tempo, Grafana)
7. Compliance and audit layer at the top

Use a blue/teal color scheme appropriate for financial services. Show directional flow from development (bottom left) to production deployment. Include a small legend explaining security control types.
```

## Tips for Using the Generated Diagram

1. The AI-generated diagram will give you a solid starting point, but you'll likely need to refine it:
   - Rearrange components for better visual flow
   - Add more specific details from your implementation
   - Ensure all connections between components make logical sense

2. After generation, customize with specific details:
   - Add your specific Kyverno policy names
   - Include actual cloud region names for your deployments
   - Add any custom security tools specific to your implementation

3. Consider adding these elements that the AI might miss:
   - WAF components at edge (AWS WAF, Azure Application Gateway, Cloud Armor)
   - Dedicated node pools for security workloads with appropriate taints
   - Specific details of your container security approach
   - Integration points with cloud IAM systems

4. Follow the detailed tutorial in your diagram-creation-tutorial.md file to refine the generated diagram. 