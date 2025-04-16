# Creating Your DevSecOps Architecture Diagram: Step-by-Step Tutorial

This guide provides detailed instructions for creating your platform architecture diagram using either Lucidchart or draw.io.

## Option 1: Using Lucidchart

### Step 1: Setup & Preparation

1. **Create an account or log in:**
   - Go to [Lucidchart.com](https://www.lucidchart.com/)
   - Sign up for a free account or log in if you already have one

2. **Start a new diagram:**
   - From your dashboard, click "+ Create New Document"
   - Select "Blank Diagram" or choose a template from "Technology & Engineering" category

3. **Set up your canvas:**
   - Click "Page Setup" in the File menu
   - Set your canvas to "Custom" size with dimensions approximately 2000 x 1200 pixels
   - Select "Landscape" orientation

### Step 2: Setting Up Shape Libraries

1. **Enable the right shape libraries:**
   - Click on the shapes panel icon on the left (or press "M")
   - Click "More Shapes" at the bottom
   - Check the following libraries:
     - AWS Architecture 2021 (or latest)
     - Azure (or latest)
     - Google Cloud Platform
     - Network
     - Kubernetes
     - Containers
     - Security
   - Click "Save" to add these libraries to your toolbar

2. **Customize your quick shapes:**
   - Drag frequently used shapes to your "Favorites" tray for quick access

### Step 3: Building the Multi-Cloud Infrastructure Layer

1. **Create cloud provider sections:**
   - Drag a large rectangle to the bottom of the canvas
   - Create three sections for AWS, Azure, and GCP (either using dividers or separate rectangles)
   - Label each section clearly

2. **Add Kubernetes clusters:**
   - From the Kubernetes library, drag cluster icons into each cloud section
   - Add EKS to AWS section, AKS to Azure section, and GKE to GCP section

3. **Add WAF components:**
   - From respective cloud libraries, add WAF icons at the edge of each cloud section
   - Use AWS WAF, Azure Application Gateway, and Cloud Armor icons

4. **Create node pools:**
   - Add node pool representations inside each cluster
   - Create separate pools for application and security workloads
   - Use different colors or borders to distinguish them
   - Add appropriate labels

### Step 4: Building the Kubernetes Security Layer

1. **Add Kyverno policies:**
   - Add shield icons or policy symbols around your clusters
   - Group them visually and label as "Kyverno Policies"
   - Add small text boxes listing key policies

2. **Create network policies:**
   - Use wall or boundary symbols between components
   - Add directional arrows to show allowed traffic
   - Label as "Network Policies"

3. **Add Istio service mesh:**
   - Create a mesh pattern across services using connection lines
   - Use the Istio icon if available
   - Label as "Istio Service Mesh - mTLS"

4. **Add container security components:**
   - Add icons for Trivy scanner, image signing
   - Label these components appropriately

### Step 5: Adding Secret Management Layer

1. **Place HashiCorp Vault:**
   - Add the Vault icon as a central component
   - Create connection lines to your clusters

2. **Show dynamic secrets workflow:**
   - Use arrows and process icons to show:
     - Secret request
     - Time-limited secret generation
     - Automatic rotation
   - Use lock icons to represent secrets

3. **Show cloud IAM integration:**
   - Connect Vault to cloud IAM systems with lines
   - Add appropriate cloud IAM icons

### Step 6: Building the CI/CD Pipeline (Left Side)

1. **Create the pipeline flow:**
   - On the left side, create a vertical flow using rectangles or process shapes
   - Start with a developer icon at the bottom

2. **Add scanning stages:**
   - Create boxes for each scanning tool:
     - SonarCloud
     - Snyk
     - Checkov
     - Gitleaks
   - Add appropriate icons for each
   - Connect them with arrows showing the flow

3. **Add ArgoCD deployment:**
   - Add the ArgoCD icon at the end of the pipeline
   - Connect it to your Kubernetes clusters with arrows
   - Add a verification step box

### Step 7: Monitoring and Response (Right Side)

1. **Add Falco security monitoring:**
   - Place the Falco icon or a monitoring symbol
   - Connect it to your clusters
   - Add alert icons to represent monitoring

2. **Create observability stack:**
   - Add icons for Prometheus, Loki, Tempo, and Grafana
   - Group them visually and label as "Observability Stack"
   - Add dashboard representations

### Step 8: Adding Compliance Layer (Top)

1. **Add compliance reporting:**
   - Create report icons or document symbols
   - Label for automated compliance reporting

2. **Show policy enforcement:**
   - Add verification symbols connecting to your clusters
   - Use checkmark icons to show compliance validation

3. **Add audit trail collection:**
   - Add database or logging icons
   - Connect them to your monitoring and Kubernetes components

### Step 9: Final Touches

1. **Add directional arrows:**
   - Create a clear flow from development (bottom left) to production (top right)
   - Use consistent arrow styles

2. **Add a legend:**
   - Create a small box with examples of your security symbols
   - Explain what each type of icon represents

3. **Review and style:**
   - Apply consistent colors (blue/teal financial services theme)
   - Ensure all text is readable
   - Use consistent icon sizes

4. **Export your diagram:**
   - Select File > Export as > PNG
   - Choose high resolution (300 DPI)
   - Save to your computer

---

## Option 2: Using draw.io (diagrams.net)

### Step 1: Setup & Preparation

1. **Access draw.io:**
   - Go to [draw.io](https://app.diagrams.net/) or [diagrams.net](https://app.diagrams.net/)
   - No account required, but you can connect to Google Drive or OneDrive if desired

2. **Start a new diagram:**
   - Click "Create New Diagram"
   - Select "Blank Diagram"
   - Choose where to save your work (Device, Google Drive, etc.)

3. **Set up your canvas:**
   - Go to File > Page Setup
   - Set your page to Custom size with dimensions approximately 2000 x 1200 pixels
   - Select "Landscape" orientation

### Step 2: Setting Up Shape Libraries

1. **Enable the right shape libraries:**
   - Click More Shapes... at the bottom of the left sidebar
   - Check the following libraries:
     - AWS (4 or latest)
     - Azure
     - Google Cloud Platform
     - Network
     - Kubernetes
     - Containers
     - Cisco (for network elements)
     - BPMN (for process flows)
   - Click Apply to add these libraries to your sidebar

2. **Create a custom cloud security library (optional):**
   - Create a new library via Arrange > Create Library
   - Name it "Security Icons"
   - You can drag security-related icons here for reuse

### Step 3: Building the Multi-Cloud Infrastructure Layer

1. **Create container for infrastructure:**
   - Draw a large rectangle at the bottom of your diagram
   - Right-click and select "Edit Style"
   - Use a light background color and dashed or solid border
   - Label it "Multi-Cloud Infrastructure"

2. **Divide into cloud sections:**
   - Create three sections using either:
     - Rectangle shapes with different background colors, or
     - Swimlane containers (from Advanced shapes)
   - Label each as AWS, Azure, and GCP

3. **Add Kubernetes clusters:**
   - From the Kubernetes library, drag the appropriate cluster icons
   - Place in each cloud section
   - Label as EKS, AKS, and GKE respectively

4. **Add WAF components and node pools:**
   - Add the WAF icons from each respective cloud provider library
   - Add node representations and create visual distinction between security and application workloads
   - Use grouping (Ctrl+G or Cmd+G) to organize related elements

### Step 4: Building the Kubernetes Security Layer

1. **Create a container for security controls:**
   - Add a large rounded rectangle above your infrastructure
   - Label it "Kubernetes Security Controls"
   - Use a different background color than your infrastructure layer

2. **Add Kyverno policies:**
   - Use shield shapes or policy symbols
   - Group related policies visually
   - Add text for key policies

3. **Create network policies visualization:**
   - Use firewall symbols or boundary lines
   - Add direction arrows with the Arrow tool
   - Label clearly

4. **Add Istio service mesh:**
   - Create a network overlay using connecting lines
   - Use dotted or colored lines to show mTLS connections
   - Group and label appropriately

5. **Add container security components:**
   - Add icons for container scanning, verification
   - Label each component clearly

### Step 5: Adding Secret Management Layer

1. **Create secrets management section:**
   - Add a container shape for this section
   - Place HashiCorp Vault icon in center
   - Label appropriately

2. **Create dynamic secrets workflow:**
   - Add process flow shapes showing:
     - Secret request
     - TTL assignment
     - Automatic rotation
   - Use curved connectors with arrows to show the flow

3. **Show cloud IAM integration:**
   - Connect to appropriate cloud IAM icons
   - Use consistent connector styles

### Step 6: Building the CI/CD Pipeline (Left Side)

1. **Create pipeline framework:**
   - On the left side, create a vertical flow
   - Start with developer icon at bottom
   - Use process arrows pointing upward

2. **Add security scanning stages:**
   - Create boxes for each tool:
     - SonarCloud (SAST)
     - Snyk (Dependencies)
     - Checkov (IaC)
     - Gitleaks (Secrets)
   - Connect with directional arrows
   - Add appropriate icons or logos for each tool

3. **Add GitOps deployment:**
   - Add ArgoCD component at the top of pipeline
   - Connect to Kubernetes clusters
   - Use different arrow style to show deployment flow

### Step 7: Monitoring and Response (Right Side)

1. **Create monitoring container:**
   - Add container on right side
   - Label "Security Monitoring & Response"

2. **Add Falco components:**
   - Place Falco icon or monitoring symbol
   - Connect to clusters
   - Add alert symbology 

3. **Add observability stack:**
   - Create group with Prometheus, Loki, Tempo icons
   - Add Grafana dashboard visualization
   - Connect to both infrastructure and security controls

### Step 8: Adding Compliance Layer (Top)

1. **Create compliance container:**
   - Add container at top of diagram
   - Label "Automated Compliance"

2. **Add compliance components:**
   - Add report icons
   - Add policy verification symbols
   - Add audit collection representation
   - Connect to other layers with appropriate arrows

### Step 9: Final Touches

1. **Add flow indicators:**
   - Use arrows to show overall flow from dev to production
   - Use consistent arrow styles

2. **Create legend:**
   - Add small box in corner
   - Include examples of your security control symbols
   - Include brief descriptions

3. **Style consistently:**
   - Right-click elements to access style options
   - Apply consistent colors to related components
   - Use the eyedropper tool to match colors exactly
   - Check text is readable against backgrounds

4. **Export your diagram:**
   - Go to File > Export as > PNG
   - Select resolution (300 DPI recommended)
   - Check "Transparent Background" option
   - Save to your computer

---

## Tips for Both Tools

1. **Use layers effectively:**
   - Both tools support layers to organize complex diagrams
   - Create separate layers for infrastructure, security, processes
   - Lock layers you're not currently editing

2. **Maintain visual hierarchy:**
   - Make important components larger or more prominent
   - Use color consistently to distinguish different types of components
   - Keep related items visually grouped

3. **Create templates for reuse:**
   - Save custom component groups you create for future diagrams
   - Create a consistent design system for security diagrams

4. **Optimize for readability:**
   - Don't overcrowd your diagram
   - Use a readable font (Sans-serif works best)
   - Test readability at different sizes

5. **Add helpful annotations:**
   - Consider adding small numbered references that correspond to article sections
   - Use brief text explanations for complex security controls

Remember to periodically save your work as you go. Both tools have autosave features but manual saves are recommended for important milestones. 