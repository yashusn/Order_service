# order-service — Enterprise DevOps Practice Project

A production-grade Spring Boot microservice with a complete CI/CD pipeline.
Use this to practice every layer of the DevOps toolchain hands-on.

---

## 🏗️ Tech Stack

| Layer | Tool |
|-------|------|
| Language | Java 17 + Spring Boot 3.2 |
| Build | Maven + JaCoCo (80% coverage gate) |
| CI | Jenkins (Jenkinsfile) + GitHub Actions |
| Code Quality | SonarQube |
| Security Scan | Trivy (container) + OWASP (deps) + Checkov (IaC) |
| Container Registry | AWS ECR |
| Artifact Repo | JFrog Artifactory |
| IaC | Terraform (EKS, VPC, ECR) |
| Config Management | Ansible |
| K8s Packaging | Helm Charts |
| GitOps | Argo CD |
| Database | PostgreSQL + Flyway migrations |
| Cache | Redis |
| Metrics | Prometheus + Grafana |
| Alerts | Prometheus AlertManager → PagerDuty |

---

## 🚀 Quick Start (Local)

```bash
# 1. Start full local stack (app + postgres + redis + prometheus + grafana + sonarqube)
docker-compose up -d

# 2. Hit the API
curl -X POST http://localhost:8080/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "CUST-001",
    "productId": "PROD-001",
    "quantity": 2,
    "totalPrice": 199.99,
    "shippingAddress": "Bengaluru, Karnataka"
  }'

# 3. Check Prometheus metrics
curl http://localhost:8080/actuator/prometheus

# 4. Open Grafana: http://localhost:3000  (admin/admin)
# 5. Open SonarQube: http://localhost:9000  (admin/admin)
```

---

## 🔁 CI/CD Pipeline Flow

```
git push
  └── GitHub webhook → Jenkins / GitHub Actions
        ├── mvn clean package        (Build)
        ├── mvn test                 (Unit Tests + JaCoCo)
        ├── sonar:sonar              (SonarQube → Quality Gate)
        ├── dependency-check:check   (OWASP)
        ├── docker build             (Multi-stage)
        ├── trivy image scan         (CVE check — fail on CRITICAL)
        ├── docker push → AWS ECR    (Immutable tag = git SHA)
        └── yq update values-dev.yaml → push gitops-config
              └── Argo CD detects change → auto-sync → K8s
```

---

## 🌍 Terraform — Provision Infrastructure

```bash
cd terraform/

# Init with S3 remote state
terraform init

# Plan for dev
terraform plan -var-file=environments/dev.tfvars

# Apply
terraform apply -var-file=environments/dev.tfvars

# Destroy when done practising
terraform destroy -var-file=environments/dev.tfvars
```

---

## 📋 Ansible — Bootstrap Nodes

```bash
cd ansible/
ansible-playbook -i inventory/dev playbook.yml --check   # dry run
ansible-playbook -i inventory/dev playbook.yml           # apply
```

---

## ⎈ Helm — Deploy to Kubernetes

```bash
# Add your kubeconfig
aws eks update-kubeconfig --region us-east-1 --name devops-practice-dev

# Install/upgrade
helm upgrade --install order-service ./helm/order-service \
  -f helm/order-service/values.yaml \
  -f helm/order-service/values-dev.yaml \
  --namespace dev --create-namespace \
  --set image.tag=$(git rev-parse --short HEAD)

# Check rollout
kubectl rollout status deployment/order-service -n dev
```

---

## 🛡️ Run Security Scans Locally

```bash
# Trivy — scan built image
trivy image order-service:latest

# Trivy — scan repo filesystem (secrets, misconfigs)
trivy fs . --scanners secret,misconfig

# Checkov — scan Terraform
checkov -d terraform/ --framework terraform

# OWASP
mvn org.owasp:dependency-check-maven:check
```

---

## 📊 API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/v1/orders | Create order |
| GET | /api/v1/orders/{id} | Get by ID |
| GET | /api/v1/orders/number/{orderNumber} | Get by order number |
| GET | /api/v1/orders/customer/{customerId} | List customer orders |
| PATCH | /api/v1/orders/{id}/status | Update status |
| DELETE | /api/v1/orders/{id} | Cancel order |
| GET | /actuator/health | Health check |
| GET | /actuator/prometheus | Prometheus metrics |

---

## 🔄 Order State Machine

```
PENDING → CONFIRMED → SHIPPED → DELIVERED
PENDING → CANCELLED
CONFIRMED → CANCELLED
```

---

## 📁 Project Structure

```
order-service/
├── src/                    # Java source + tests
├── Dockerfile              # Multi-stage (builder → distroless)
├── Jenkinsfile             # Declarative CI pipeline
├── .github/workflows/      # GitHub Actions (alternative CI)
├── helm/order-service/     # Helm chart (all environments)
├── terraform/              # EKS + VPC + ECR infrastructure
├── ansible/                # Node bootstrap playbook
├── k8s/                    # Argo CD application + Prometheus rules
├── docker-compose.yml      # Full local dev stack
├── sonar-project.properties
└── trivy.yaml
```
