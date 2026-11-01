# Scalable Containerized RESTful API on AWS Fargate using Terraform

A production-grade, highly available RESTful API deployed onto serverless **AWS Fargate** (Amazon ECS) and backed by **Amazon RDS PostgreSQL**, fully provisioned and automated with **Terraform**.

---

## 🏛️ Architecture Overview

The system implements a classic **three-tier architecture** with strict network isolation and least-privilege security controls.

```
                              AWS Cloud Environment
                       Virtual Private Cloud (VPC) - 10.0.0.0/16
  +---------------------------------------------------------------------------------+
  |                                                                                 |
  |  Internet Gateway (IGW)                                                         |
  |        |                                                                        |
  |        v [Inbound HTTP (Port 80)]                                               |
  |  +---------------------------------------------------------------------------+  |
  |  | Public Subnets (AZ-a: 10.0.1.0/24 | AZ-b: 10.0.2.0/24)                    |  |
  |  |                                                                           |  |
  |  |   Application Load Balancer (ALB)                                         |  |
  |  |   [ALB Security Group: Ingress Port 80 from 0.0.0.0/0]                    |  |
  |  +---------------------------------------------------------------------------+  |
  |                                |                                                |
  |                                v [Forwards & Balances Traffic (Port 8000)]      |
  |  +---------------------------------------------------------------------------+  |
  |  | Private Subnets - Compute Tier (AZ-a: 10.0.10.0/24 | AZ-b: 10.0.11.0/24)  |  |
  |  |                                                                           |  |
  |  |   ECS Cluster on AWS Fargate                                              |  |
  |  |   Tasks: [API Container 1] ... [API Container N]                          |  |
  |  |   [ECS Security Group: Ingress Port 8000 ONLY from ALB SG]                |  |
  |  |   - Auto-Scaling Target Tracking (Average CPU @ 70%)                      |  |
  |  |   - CloudWatch Logs Stream (/ecs/fargate-api)                             |  |
  |  +---------------------------------------------------------------------------+  |
  |                                |                                                |
  |                                v [Reads/Writes (Port 5432)]                     |
  |  +---------------------------------------------------------------------------+  |
  |  | Private Subnets - Data Tier (AWS RDS DB Subnet Group)                     |  |
  |  |                                                                           |  |
  |  |   Amazon RDS PostgreSQL Instance                                          |  |
  |  |   [RDS Security Group: Ingress Port 5432 ONLY from ECS Task SG]           |  |
  |  +---------------------------------------------------------------------------+  |
  |                                                                                 |
  +---------------------------------------------------------------------------------+
```

### Key Security & Design Principles
- **Public Entry Point**: External traffic enters solely through the Application Load Balancer (ALB) in public subnets on port 80.
- **Isolated Compute Tier**: ECS Fargate tasks run in private subnets with private IPs and no direct internet ingress. Their security group permits inbound traffic on port 8000 **strictly from the ALB security group**.
- **Chained Database Security**: The RDS PostgreSQL instance is deployed in private subnets with `publicly_accessible = false`. Its security group permits ingress on port 5432 **strictly from the ECS task security group**.
- **Cost-Optimized VPC Endpoints**: Private interface endpoints (`ecr.api`, `ecr.dkr`, `logs`) and an S3 gateway endpoint enable Fargate tasks to pull container images and push CloudWatch logs without requiring expensive NAT Gateways.
- **Elastic Auto-Scaling**: ECS Service dynamically scales between 2 and 4 tasks using AWS Application Auto-Scaling targeting 70% average CPU utilization.
- **Environment Decoupling**: Local development uses `.env` via Docker Compose; production AWS ECS dynamically injects database parameters via Terraform task definition environment variables.

---

## 📁 Repository Structure

```
Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/
├── .env.example               # Template for local environment variables
├── .env                       # Local development environment configuration
├── docker-compose.yml         # Local multi-container stack (API + PostgreSQL)
├── README.md                  # Complete architecture, setup & test guide
├── api/
│   ├── Dockerfile             # Multi-stage Docker build (Builder + Non-root Runtime)
│   ├── requirements.txt       # Python dependencies (FastAPI, SQLAlchemy, Pytest)
│   ├── pytest.ini             # Pytest configuration
│   ├── app/
│   │   ├── main.py            # FastAPI application with startup retry lifecycle
│   │   ├── config.py          # Settings loader and connection URL builder
│   │   ├── database.py        # Database connection pool & exponential backoff logic
│   │   ├── models.py          # SQLAlchemy Item model (UUID primary key)
│   │   ├── schemas.py         # Pydantic validation schemas
│   │   └── routes.py          # /health, POST /items, GET /items endpoints
│   └── tests/
│       ├── conftest.py        # Test fixtures & in-memory database configuration
│       └── test_api.py        # Unit and integration test suite
├── terraform/
│   ├── versions.tf            # Terraform & AWS provider version constraints
│   ├── variables.tf           # Input variable declarations with defaults
│   ├── terraform.tfvars.example # Example variable values for deployment
│   ├── vpc.tf                 # VPC, 2 public & 2 private subnets, route tables, VPC endpoints
│   ├── security_groups.tf     # Least-privilege chained security groups (ALB -> ECS -> RDS)
│   ├── rds.tf                 # Subnet group & private RDS PostgreSQL instance
│   ├── ecr.tf                 # ECR repository with force_delete enabled
│   ├── alb.tf                 # Application Load Balancer, listener, target group
│   ├── iam.tf                 # ECS task execution role & task role
│   ├── cloudwatch.tf          # CloudWatch Log Group (/ecs/fargate-api)
│   ├── ecs.tf                 # ECS Cluster, Task Definition (CPU/Mem/Env), Service
│   ├── autoscaling.tf         # ECS CPU target tracking policy (70% target)
│   └── outputs.tf             # alb_url, rds_endpoint, ecr_repository_url
└── scripts/
    ├── test_endpoints.ps1     # PowerShell automated endpoint verification script
    └── test_endpoints.sh      # Bash automated endpoint verification script
```

---

## 💻 Phase 1: Local Development & Testing

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running.

---

### Step 1: Start the Local Stack
> **Working Directory:** Project root (`Scalable-Containerized-API-on-AWS-Fargate-using-Terraform`)

Start both the PostgreSQL 13 database and the API container simultaneously:

```powershell
docker compose up -d --build
```

Verify that both containers are running and healthy:
```powershell
docker compose ps
```
Both `fargate_api_db` and `fargate_api_app` should display `Up (healthy)`.

---

### Step 2: Run the Automated Pytest Suite
> **Working Directory:** Project root

Run the test suite inside the containerized API:
```powershell
docker compose exec api pytest -v /app/tests
```
*Expected Result:* All 6 unit and integration tests pass cleanly.

---

### Step 3: Run Endpoint Integration Tests
> **Working Directory:** Project root

Execute the end-to-end verification script against the local API:
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/test_endpoints.ps1
```
*Expected Result:*
- `[TEST 1] GET /health` &rarr; Returns `HTTP 200` with `{"status": "healthy"}`
- `[TEST 2] POST /items` &rarr; Returns `HTTP 201` with generated UUID and timestamp
- `[TEST 3] GET /items` &rarr; Returns `HTTP 200` with JSON array containing items
- `[TEST 4] POST /items validation` &rarr; Returns `HTTP 422` on missing required fields

---

### Step 4: Test Database Fault Tolerance
> **Working Directory:** Project root

To confirm the container does not crash when the database is unavailable:

1. Stop the database container:
   ```powershell
   docker stop fargate_api_db
   ```
2. Send a request to `/items`:
   ```powershell
   curl -i http://localhost:8000/items
   ```
   *Expected Result:* Returns `HTTP 500` with clean JSON `{"error": "Database error", "message": "Failed to retrieve items due to a database error."}`. The container remains running.
3. Check the health check endpoint:
   ```powershell
   curl -i http://localhost:8000/health
   ```
   *Expected Result:* Returns `HTTP 200 OK`.
4. Restart the database:
   ```powershell
   docker start fargate_api_db
   ```

---

### Step 5: Local Clean Up
> **Working Directory:** Project root

Stop and remove local containers and volumes:
```powershell
docker compose down -v
```

---

## 🚀 Phase 2: AWS Deployment with Terraform

### Prerequisites
Install the required command-line tools if you have not already:

```powershell
# Install Terraform
winget install --id Hashicorp.Terraform -e

# Install AWS CLI
winget install --id Amazon.AWSCLI -e
```
*Restart your PowerShell terminal after installation to ensure tools are in your `PATH`.*

---

### Step 1: Configure AWS CLI Credentials
> **Working Directory:** Any directory

Configure your AWS credentials:
```powershell
aws configure
```
Enter your AWS Access Key ID, Secret Access Key, and default region (`us-east-1`).

Verify your authenticated AWS identity:
```powershell
aws sts get-caller-identity
```

---

### Step 2: Initialize Terraform
> **Working Directory:** Switch to `terraform/`

```powershell
cd terraform
terraform init
terraform validate
```
*Expected Result:* `Success! The configuration is valid.`

---

### Step 3: Create the ECR Repository First
> **Working Directory:** `terraform/`

Target and provision only the ECR repository so we can push our Docker image before deploying ECS:
```powershell
terraform apply -target="aws_ecr_repository.app" -auto-approve
```

---

### Step 4: Authenticate Docker with ECR
> **Working Directory:** `terraform/`

Store the ECR login token into a variable to avoid PowerShell newline issues and log in:
```powershell
$pass = aws ecr get-login-password --region us-east-1
$ecrUrl = (terraform output -raw ecr_repository_url) -replace '/.*', ''
docker login --username AWS --password $pass $ecrUrl
```
*Expected Result:* `Login Succeeded`

---

### Step 5: Build and Push Docker Image to ECR
> **Working Directory:** Switch to project root, build/push, then return to `terraform/`

1. Move to the project root and build the Docker image using the ECR repository URL:
   ```powershell
   cd ..
   $repoUrl = (cd terraform; terraform output -raw ecr_repository_url)
   docker build -t "${repoUrl}:latest" -f api/Dockerfile api
   ```

2. Push the tagged image to your AWS ECR repository:
   ```powershell
   docker push "${repoUrl}:latest"
   ```

3. Return to the `terraform/` directory:
   ```powershell
   cd terraform
   ```

---

### Step 6: Deploy the Complete AWS Infrastructure
> **Working Directory:** `terraform/`

Deploy the VPC, Subnets, Route Tables, Security Groups, RDS PostgreSQL, ALB, ECS Cluster, Task Definition, Fargate Service, and Auto-Scaling:
```powershell
terraform apply -auto-approve
```

> ⏱️ **Note on Duration:** Amazon RDS PostgreSQL creation takes approximately **4 to 8 minutes**.

When completed, Terraform displays the outputs:
```text
Outputs:
alb_dns_name = "fargate-api-alb-xxxxxx.us-east-1.elb.amazonaws.com"
alb_url = "http://fargate-api-alb-xxxxxx.us-east-1.elb.amazonaws.com"
ecr_repository_url = "xxxxxx.dkr.ecr.us-east-1.amazonaws.com/fargate-api-repo"
ecs_cluster_name = "fargate-api-cluster"
ecs_service_name = "fargate-api-service"
rds_endpoint = "fargate-api-db.xxxxxx.us-east-1.rds.amazonaws.com:5432"
```

---

### Step 7: Verify the AWS Deployment
> **Working Directory:** `terraform/`

Wait 1 to 2 minutes for the Fargate tasks to register and pass ALB health checks.

1. **Verify Health Endpoint:**
   ```powershell
   $albUrl = terraform output -raw alb_url
   curl "$albUrl/health"
   ```
   *Expected Response:* `{"status":"healthy"}`

2. **Run Full Automated Verification Script Against AWS ALB:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File ../scripts/test_endpoints.ps1 -BaseUrl (terraform output -raw alb_url)
   ```
   *Expected Result:* All 4 tests pass against the live AWS Load Balancer!

3. **Verify CloudWatch Logs in AWS Console:**
   Navigate to AWS Console &rarr; **CloudWatch** &rarr; **Log groups** &rarr; `/ecs/fargate-api`. You will see active container log streams from both Fargate tasks.

4. **Verify Auto-Scaling Policy:**
   ```powershell
   aws application-autoscaling describe-scalable-targets --service-namespace ecs --region us-east-1
   ```
   Displays the registered scalable target tracking `ECSServiceAverageCPUUtilization` at 70%.

---

## 🧹 Phase 3: Infrastructure Teardown

> [!CAUTION]
> Always destroy AWS infrastructure after testing to avoid ongoing charges for the Application Load Balancer and RDS instance.

> **Working Directory:** `terraform/`

Run the destroy command:
```powershell
terraform destroy -auto-approve
```

Because `skip_final_snapshot = true` is configured on RDS and `force_delete = true` is enabled on the ECR repository, all resources (including VPC endpoints, subnets, and security groups) tear down cleanly without dependency errors.

---

## 📡 API Specification Reference

| Method | Endpoint | Description | Sample Request | Success Code | Sample Response |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `GET` | `/health` | ALB / orchestrator health check | None | `200 OK` | `{"status": "healthy"}` |
| `POST` | `/items` | Ingest and persist new item | `{"name": "Server", "description": "Compute node"}` | `201 Created` | `{"id": "uuid", "name": "Server", "description": "Compute node", "created_at": "timestamp"}` |
| `GET` | `/items` | Retrieve all items | None | `200 OK` | `[{"id": "uuid", "name": "Server", "description": "Compute node", "created_at": "timestamp"}]` |

---

## 💯 Requirements Verification Checklist

| # | Requirement | Implementation & File Reference | Status |
|---|---|---|:---:|
| 1 | **Core Networking Resources** | `aws_vpc` (10.0.0.0/16), `aws_internet_gateway`, 2 public subnets, 2 private subnets across 2 AZs, public/private route tables & associations in [terraform/vpc.tf](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/terraform/vpc.tf) | **100% PASS** |
| 2 | **Restricted Chained Security Groups** | ALB SG (0.0.0.0/0 on port 80) &rarr; ECS SG (port 8000 only from ALB SG) &rarr; RDS SG (port 5432 only from ECS SG) in [terraform/security_groups.tf](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/terraform/security_groups.tf) | **100% PASS** |
| 3 | **Container Compute Environments** | `aws_ecr_repository`, `aws_ecs_cluster`, `aws_ecs_task_definition` (`requires_compatibilities = ["FARGATE"]`), `aws_ecs_service` (`launch_type = "FARGATE"`) in [terraform/ecs.tf](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/terraform/ecs.tf), [terraform/ecr.tf](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/terraform/ecr.tf) | **100% PASS** |
| 4 | **Application Load Balancer** | `aws_lb` in public subnets, `aws_lb_target_group` (`target_type = "ip"`, `/health` check), `aws_lb_listener` (port 80) in [terraform/alb.tf](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/terraform/alb.tf) | **100% PASS** |
| 5 | **Relational Database Instance** | `aws_db_instance` (PostgreSQL), private `aws_db_subnet_group`, attached to RDS security group, `publicly_accessible = false` in [terraform/rds.tf](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/terraform/rds.tf) | **100% PASS** |
| 6 | **Multi-Stage Dockerfile** | Multi-stage build with `builder` compiling dependencies and lightweight `runtime` running as non-root `appuser`, exposing port 8000 in [api/Dockerfile](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/api/Dockerfile) | **100% PASS** |
| 7 | **Fargate Resource Allocations** | Task definition explicitly sets `cpu = "256"` and `memory = "512"` in [terraform/ecs.tf](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/terraform/ecs.tf) | **100% PASS** |
| 8 | **CloudWatch Logging** | Log group `/ecs/fargate-api` created; Task definition configured with `awslogs` driver in [terraform/cloudwatch.tf](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/terraform/cloudwatch.tf), [terraform/ecs.tf](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/terraform/ecs.tf) | **100% PASS** |
| 9 | **Dynamic Environment Injection** | Task definition injects database credentials and host URLs via Terraform resource references. No credentials hardcoded in [terraform/ecs.tf](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/terraform/ecs.tf) | **100% PASS** |
| 10 | **Auto-Scaling Policy** | `aws_appautoscaling_target` and `aws_appautoscaling_policy` tracking `ECSServiceAverageCPUUtilization` at 70% target in [terraform/autoscaling.tf](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/terraform/autoscaling.tf) | **100% PASS** |
| 11 | **Health Check Endpoint** | `GET /health` returns HTTP 200 with exact body `{"status": "healthy"}` in [api/app/routes.py](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/api/app/routes.py) | **100% PASS** |
| 12 | **Data Ingestion (POST /items)** | `POST /items` creates item with generated UUID and timestamp, persists to PostgreSQL, returns HTTP 201 in [api/app/routes.py](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/api/app/routes.py) | **100% PASS** |
| 13 | **Data Retrieval (GET /items)** | `GET /items` queries database and returns HTTP 200 with serialized JSON array in [api/app/routes.py](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/api/app/routes.py) | **100% PASS** |
| 14 | **Resilient DB Error Handling** | Exponential backoff on startup; database exceptions during requests return HTTP 500 without crashing container in [api/app/database.py](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/api/app/database.py), [api/app/routes.py](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/api/app/routes.py) | **100% PASS** |
| 15 | **Local Environment with Compose** | `docker-compose.yml` runs PostgreSQL and API simultaneously from source with `service_healthy` check in [docker-compose.yml](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/docker-compose.yml) | **100% PASS** |
| 16 | **Graceful Infrastructure Teardown** | `skip_final_snapshot = true` on RDS, `force_delete = true` on ECR, clean dependency resolution; `terraform destroy` verified in [terraform/rds.tf](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/terraform/rds.tf), [terraform/ecr.tf](file:///c:/Users/ABC/Desktop/GPP/Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/terraform/ecr.tf) | **100% PASS** |
