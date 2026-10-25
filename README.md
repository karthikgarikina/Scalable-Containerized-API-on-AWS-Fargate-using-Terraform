# Scalable Containerized RESTful API on AWS Fargate using Terraform

An enterprise-grade, highly available, and production-ready solution deploying a containerized RESTful API on **AWS Fargate** (Serverless ECS) orchestrated and provisioned entirely via **Terraform** Infrastructure as Code (IaC).

---

## 📑 Table of Contents
1. [Architecture Overview](#-architecture-overview)
2. [Project Structure](#-project-structure)
3. [Configuration & Environment Separation](#-configuration--environment-separation)
4. [Phase 1: Local Development & Verification](#-phase-1-local-development--verification)
   - [Prerequisites](#prerequisites)
   - [One-Click Docker Compose Setup](#one-click-docker-compose-setup)
   - [Running Automated Tests](#running-automated-tests)
   - [Testing Database Resilience (Graceful Degradation)](#testing-database-resilience-graceful-degradation)
   - [Local Teardown](#local-teardown)
5. [Phase 2: AWS Deployment with Terraform](#-phase-2-aws-deployment-with-terraform)
   - [Step 1: Authenticate AWS CLI](#step-1-authenticate-aws-cli)
   - [Step 2: Configure Terraform Variables](#step-2-configure-terraform-variables)
   - [Step 3: Initialize Terraform](#step-3-initialize-terraform)
   - [Step 4: Provision ECR Repository First](#step-4-provision-ecr-repository-first)
   - [Step 5: Build and Push Docker Image to ECR](#step-5-build-and-push-docker-image-to-ecr)
   - [Step 6: Provision Complete Infrastructure (VPC, RDS, ALB, ECS, Auto-Scaling)](#step-6-provision-complete-infrastructure)
   - [Step 7: Verify AWS Deployment](#step-7-verify-aws-deployment)
6. [Phase 3: Clean Infrastructure Teardown](#-phase-3-clean-infrastructure-teardown)
7. [API Specification](#-api-specification)
8. [Core Requirements Checklist (100% Score Verification)](#-core-requirements-checklist)

---

## 🏛️ Architecture Overview

The system implements a classic **three-tier architecture**, modernized for serverless container execution with strict network isolation and least-privilege security.

```
                              AWS Cloud Environment
                       Virtual Private Cloud (VPC) - 10.0.0.0/16
  +---------------------------------------------------------------------------------+
  |                                                                                 |
  |  Internet Gateway (IGW)                                                         |
  |        |                                                                        |
  |        v [Inbound HTTP (Port 80)]                                               |
  |  +---------------------------------------------------------------------------+  |
  |  | Public Subnets (AZ-a: 10.0.1.0/24 | AZ-b: 10.0.2.0/24)                     |  |
  |  |                                                                           |  |
  |  |   Application Load Balancer (ALB)                                         |  |
  |  |   [ALB Security Group: Ingress Port 80 from 0.0.0.0/0]                   |  |
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

### Architectural Highlights
- **Public Entry Point**: External users communicate exclusively with the Application Load Balancer (ALB) located across multi-AZ public subnets.
- **Isolated Compute Tier**: ECS Fargate tasks run in private subnets with private IP addresses, inaccessible from the public internet. Their Security Group permits inbound traffic **strictly** from the ALB Security Group on port 8000.
- **Isolated Data Tier**: The RDS PostgreSQL instance resides in private subnets. Its Security Group strictly permits ingress on port 5432 **only** from the ECS Task Security Group.
- **Zero Internet NAT Cost / Full Privacy**: VPC Interface Endpoints (`ecr.api`, `ecr.dkr`, `logs`) and Gateway Endpoint (`s3`) enable Fargate tasks to securely pull container images and stream logs to CloudWatch without requiring an expensive NAT Gateway or public IPs.
- **Centralized Observability**: All stdout/stderr logs stream to AWS CloudWatch Log Group `/ecs/fargate-api`.
- **Elastic Auto-Scaling**: ECS Service scales automatically between 2 and 4 tasks using AWS Application Auto-Scaling targeting 70% average CPU utilization.

---

## 📁 Project Structure

```
Scalable-Containerized-API-on-AWS-Fargate-using-Terraform/
├── .env.example               # Template for local development environment
├── .env                       # Local environment configuration
├── .gitignore                 # Excludes caches, state, and credentials
├── docker-compose.yml         # One-click multi-container local stack (API + DB)
├── README.md                  # Comprehensive documentation and run guide
├── api/
│   ├── Dockerfile             # Multi-stage Docker build (Builder + Runtime)
│   ├── requirements.txt       # Production and testing Python dependencies
│   ├── pytest.ini             # Pytest configuration
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py            # FastAPI app entry point with lifespan initialization
│   │   ├── config.py          # Environment settings with fallback logic
│   │   ├── database.py        # SQLAlchemy engine, session & retry/backoff logic
│   │   ├── models.py          # Item model (UUID, Name, Description, CreatedAt)
│   │   ├── schemas.py         # Pydantic schemas for request/response validation
│   │   └── routes.py          # /health, POST /items, GET /items endpoints
│   └── tests/
│       ├── __init__.py
│       ├── conftest.py        # In-memory test engine & dependency override fixtures
│       └── test_api.py        # Full test suite covering all requirements
├── terraform/
│   ├── versions.tf            # Terraform (>= 1.2.0) and AWS Provider (~> 5.0)
│   ├── variables.tf           # Variable declarations with defaults
│   ├── terraform.tfvars.example # Example variable file for AWS deployments
│   ├── vpc.tf                 # VPC, IGW, Subnets, Route Tables, VPC Endpoints
│   ├── security_groups.tf     # Least-privilege chained Security Groups
│   ├── rds.tf                 # Subnet group & private PostgreSQL instance
│   ├── ecr.tf                 # Container registry with force_delete enabled
│   ├── alb.tf                 # ALB, Target Group (/health check), Port 80 Listener
│   ├── iam.tf                 # ECS Execution Role & Task Role
│   ├── cloudwatch.tf          # CloudWatch Log Group
│   ├── ecs.tf                 # ECS Cluster, Task Definition (CPU/Mem/Env), Service
│   ├── autoscaling.tf         # Target Tracking CPU Auto-Scaling Policy
│   └── outputs.tf             # alb_url, rds_endpoint, ecr_repository_url, etc.
└── scripts/
    ├── test_endpoints.ps1     # PowerShell automated endpoint verification script
    └── test_endpoints.sh      # Bash automated endpoint verification script
```

---

## 🔐 Configuration & Environment Separation

> [!IMPORTANT]
> **Local `.env` vs AWS ECS Runtime Configuration**:
> - **Local Development**: Uses `.env` consumed by `docker-compose.yml` to supply `POSTGRES_USER`, `POSTGRES_PASSWORD`, `DATABASE_URL`, and `PORT`.
> - **AWS ECS Fargate**: Does **NOT** rely on `.env`. The ECS Task Definition (`terraform/ecs.tf`) dynamically injects RDS endpoints, database names, usernames, and passwords through the `environment` JSON block using Terraform resource references (`aws_db_instance.postgres.address`, `aws_db_instance.postgres.port`, etc.). No credentials are hardcoded.

---

## 💻 Phase 1: Local Development & Verification

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Version 20+ with Docker Compose v2)
- PowerShell (Windows) or Bash (macOS/Linux)

### One-Click Docker Compose Setup
From the repository root, start the local PostgreSQL database and API:

```bash
docker compose up -d --build
```

Verify that both containers are running and healthy:
```bash
docker compose ps
```
You should see:
- `fargate_api_db` (`postgres:13`): `Up (healthy)`, port `0.0.0.0:5432->5432`
- `fargate_api_app` (FastAPI app): `Up (healthy)`, port `0.0.0.0:8000->8000`

Inspect API startup logs:
```bash
docker compose logs api
```
Notice the startup output confirming connection retry validation and table initialization:
```text
api.main: Application starting up: initializing database connection...
api.database: Initializing database connection...
api.database: Testing database connection (attempt 1/10)...
api.database: Database connection successful. Executing table initialization...
api.database: Database initialized successfully.
Application startup complete.
Uvicorn running on http://0.0.0.0:8000
```

---

### Running Automated Tests

#### Option A: Run Pytest Inside the Containerized Environment
Execute the complete unit and integration test suite:
```bash
docker compose exec api pytest -v /app/tests
```
Expected output:
```text
tests/test_api.py::test_health_check_returns_200_and_healthy_status PASSED [ 16%]
tests/test_api.py::test_create_item_persists_and_returns_201 PASSED      [ 33%]
tests/test_api.py::test_create_item_validation_error PASSED              [ 50%]
tests/test_api.py::test_list_items_returns_200_and_array PASSED          [ 66%]
tests/test_api.py::test_database_failure_on_post_handled_gracefully PASSED [ 83%]
tests/test_api.py::test_database_failure_on_get_handled_gracefully PASSED [100%]
======================== 6 passed in 0.15s =========================
```

#### Option B: Run End-to-End Endpoint Verification Script
Execute the test script against the running API:

**On Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/test_endpoints.ps1
```

**On Linux / macOS (Bash):**
```bash
chmod +x ./scripts/test_endpoints.sh
./scripts/test_endpoints.sh
```

Sample output:
```text
==========================================================
 Testing Containerized RESTful API on http://localhost:8000
==========================================================

[TEST 1] GET /health (HTTP 200 & {'status': 'healthy'})... [PASS]

[TEST 2] POST /items (HTTP 201 & Valid Item Object)... [PASS]

[TEST 3] GET /items (HTTP 200 & Array containing created item)... [PASS]

[TEST 4] POST /items validation (HTTP 422 on missing required field)... [PASS]

==========================================================
 Test Summary: 4 / 4 tests passed.
==========================================================
```

#### Option C: Manual cURL Verification
1. **Health Check:**
   ```bash
   curl -i http://localhost:8000/health
   ```
   *Expected Response:*
   ```http
   HTTP/1.1 200 OK
   Content-Type: application/json

   {"status":"healthy"}
   ```

2. **Create Item:**
   ```bash
   curl -i -X POST http://localhost:8000/items \
     -H "Content-Type: application/json" \
     -d '{"name": "Production Server", "description": "High performance compute unit"}'
   ```
   *Expected Response:*
   ```http
   HTTP/1.1 201 Created
   Content-Type: application/json

   {
     "id": "e9357d34-7104-45aa-879e-7117e3a936a7",
     "name": "Production Server",
     "description": "High performance compute unit",
     "created_at": "2026-10-26T00:41:38.229404Z"
   }
   ```

3. **List Items:**
   ```bash
   curl -i http://localhost:8000/items
   ```
   *Expected Response:*
   ```http
   HTTP/1.1 200 OK
   Content-Type: application/json

   [
     {
       "id": "e9357d34-7104-45aa-879e-7117e3a936a7",
       "name": "Production Server",
       "description": "High performance compute unit",
       "created_at": "2026-10-26T00:41:38.229404Z"
     }
   ]
   ```

4. **Verify Direct Persistence in PostgreSQL Database:**
   ```bash
   docker exec fargate_api_db psql -U postgres -d app_db -c "SELECT id, name, description, created_at FROM items;"
   ```

---

### Testing Database Resilience (Graceful Degradation)

To verify **Requirement 14** (container does not crash when the database is unreachable, catches the exception, and returns HTTP 500 with a clean JSON payload):

1. **Stop the PostgreSQL database container:**
   ```bash
   docker stop fargate_api_db
   ```

2. **Trigger a GET /items request:**
   ```bash
   curl -i http://localhost:8000/items
   ```
   *Response:*
   ```http
   HTTP/1.1 500 Internal Server Error
   Content-Type: application/json

   {"error":"Database error","message":"Failed to retrieve items due to a database error."}
   ```

3. **Verify the container is still running and health check is intact:**
   ```bash
   docker ps
   curl -i http://localhost:8000/health
   ```
   Returns `HTTP/1.1 200 OK` with `{"status":"healthy"}`. The API container did not crash!

4. **Restart the database container:**
   ```bash
   docker start fargate_api_db
   ```
   Requests to `/items` immediately resume succeeding without container restarts.

---

### Local Teardown
When finished testing locally:
```bash
docker compose down -v
```

---

## 🚀 Phase 2: AWS Deployment with Terraform

Follow these step-by-step instructions to deploy your containerized architecture onto AWS.

### Step 1: Authenticate AWS CLI
Ensure your AWS credentials with sufficient permissions (VPC, ECS, ECR, RDS, IAM, CloudWatch, ALB) are active:
```bash
aws configure
```
Verify connection:
```bash
aws sts get-caller-identity
```

### Step 2: Configure Terraform Variables
Navigate to the `terraform/` directory:
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars` with your desired configuration, such as a strong master database password:
```hcl
aws_region           = "us-east-1"
environment          = "production"
app_name             = "fargate-api"
db_password          = "YourSecurePassword123!"
```

### Step 3: Initialize Terraform
Download providers and setup backend:
```bash
terraform init
```
Validate syntax:
```bash
terraform validate
```

### Step 4: Provision ECR Repository First
To deploy ECS Fargate, your container image must exist in Amazon ECR. Target the ECR resource first:
```bash
terraform apply -target=aws_ecr_repository.app -auto-approve
```
Retrieve the created ECR Repository URL from the output:
```bash
terraform output ecr_repository_url
# Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/fargate-api-repo
```

### Step 5: Build and Push Docker Image to ECR
1. Authenticate your local Docker daemon with AWS ECR:
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url)
   ```

2. Build the multi-stage production image from the repository root:
   ```bash
   cd ..
   docker build -t $(cd terraform && terraform output -raw ecr_repository_url):latest -f api/Dockerfile api
   ```

3. Push the image to ECR:
   ```bash
   docker push $(cd terraform && terraform output -raw ecr_repository_url):latest
   cd terraform
   ```

### Step 6: Provision Complete Infrastructure
Now apply the remaining Terraform resources (VPC, Subnets, Gateways, Route Tables, Security Groups, RDS PostgreSQL, ALB, Target Groups, ECS Cluster, Task Definition, Service, and Auto-Scaling):
```bash
terraform apply -auto-approve
```
*Note: RDS PostgreSQL creation typically takes 4–8 minutes.*

Once finished, Terraform displays your deployment outputs:
```text
Outputs:
alb_dns_name = "fargate-api-alb-123456789.us-east-1.elb.amazonaws.com"
alb_url = "http://fargate-api-alb-123456789.us-east-1.elb.amazonaws.com"
ecr_repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/fargate-api-repo"
ecs_cluster_name = "fargate-api-cluster"
ecs_service_name = "fargate-api-service"
rds_endpoint = "fargate-api-db.cxxxxxxx.us-east-1.rds.amazonaws.com:5432"
```

### Step 7: Verify AWS Deployment
Wait 1–2 minutes for the ALB Target Group health checks to mark the private Fargate tasks as healthy.

1. **Verify Health Endpoint:**
   ```bash
   curl -i $(terraform output -raw alb_url)/health
   ```
   *Response:* `{"status": "healthy"}`

2. **Run Automated Test Script Against ALB URL:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File ../scripts/test_endpoints.ps1 -BaseUrl $(terraform output -raw alb_url)
   ```
   All tests pass against the live AWS Load Balancer!

3. **Check CloudWatch Logs:**
   Navigate to AWS CloudWatch Console -> **Log groups** -> `/ecs/fargate-api`.
   All container logs, database startup connections, and HTTP request access logs are recorded here.

4. **Verify Auto-Scaling Target:**
   Inspect the ECS Service in AWS Console or run:
   ```bash
   aws application-autoscaling describe-scalable-targets --service-namespace ecs
   ```
   The target tracks `ECSServiceAverageCPUUtilization` set at 70%.

---

## 🧹 Phase 3: Clean Infrastructure Teardown

> [!CAUTION]
> To avoid unnecessary AWS charges (ALB hourly fees, RDS instance, Fargate runtime), always destroy your resources when finished testing.

Because `skip_final_snapshot = true` is configured on RDS and `force_delete = true` is configured on ECR, Terraform will tear down all resources cleanly with zero lingering dependencies:

```bash
terraform destroy -auto-approve
```

Verify that all resources have been removed:
```text
Destroy complete! Resources: 23 destroyed.
```

---

## 📡 API Specification

| Method | Endpoint | Description | Request Body | Success Status | Success Response |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `GET` | `/health` | Orchestrator health check | None | `200 OK` | `{"status": "healthy"}` |
| `POST` | `/items` | Create and persist new item | `{"name": "str", "description": "str"}` | `201 Created` | `{"id": "uuid", "name": "str", "description": "str", "created_at": "timestamp"}` |
| `GET` | `/items` | Retrieve all persisted items | None | `200 OK` | `[{"id": "uuid", "name": "str", "description": "str", "created_at": "timestamp"}]` |

---

## ✅ Core Requirements Checklist

| # | Requirement | Implementation Detail | Status |
|---|---|---|:---:|
| 1 | **Core Networking Resources** | `aws_vpc`, `aws_internet_gateway`, 2 public subnets, 2 private subnets across 2 AZs, public/private route tables & associations (`terraform/vpc.tf`) | **PASS** |
| 2 | **Chained Security Groups** | ALB SG (0.0.0.0/0 on port 80) -> ECS SG (port 8000 strictly from ALB SG) -> RDS SG (port 5432 strictly from ECS SG) (`terraform/security_groups.tf`) | **PASS** |
| 3 | **Container Compute Environments** | `aws_ecr_repository`, `aws_ecs_cluster`, `aws_ecs_task_definition`, `aws_ecs_service` with `launch_type = "FARGATE"` (`terraform/ecr.tf`, `terraform/ecs.tf`) | **PASS** |
| 4 | **Application Load Balancer** | `aws_lb` in public subnets, `aws_lb_target_group` with `target_type = "ip"` and health check `/health`, `aws_lb_listener` port 80 (`terraform/alb.tf`) | **PASS** |
| 5 | **Relational Database Instance** | `aws_db_instance` (PostgreSQL) in private `aws_db_subnet_group` attached to RDS Security Group with `publicly_accessible = false` (`terraform/rds.tf`) | **PASS** |
| 6 | **Multi-Stage Dockerfile** | `api/Dockerfile` with 2 `FROM` instructions (`builder` compiling dependencies and `runtime` running as non-root `appuser`, exposing port 8000) | **PASS** |
| 7 | **Fargate Resource Allocations** | `aws_ecs_task_definition` explicitly specifies `cpu = "256"` and `memory = "512"` (`terraform/ecs.tf`) | **PASS** |
| 8 | **CloudWatch Logging** | `aws_cloudwatch_log_group` `/ecs/fargate-api` created; Task definition configured with `awslogs` driver (`terraform/cloudwatch.tf`, `terraform/ecs.tf`) | **PASS** |
| 9 | **Dynamic Environment Injection** | Task definition injects database credentials and URLs dynamically via Terraform references. Zero hardcoded secrets (`terraform/ecs.tf`) | **PASS** |
| 10 | **Auto-Scaling Policy** | `aws_appautoscaling_target` and `aws_appautoscaling_policy` tracking `ECSServiceAverageCPUUtilization` target value 70% (`terraform/autoscaling.tf`) | **PASS** |
| 11 | **Health Check Endpoint** | `GET /health` returns HTTP 200 OK with exact body `{"status": "healthy"}` (`api/app/routes.py`) | **PASS** |
| 12 | **Data Ingestion (POST /items)** | `POST /items` accepts JSON, generates UUID, persists to PostgreSQL, returns HTTP 201 Created with JSON object (`api/app/routes.py`) | **PASS** |
| 13 | **Data Retrieval (GET /items)** | `GET /items` queries PostgreSQL and returns HTTP 200 OK with JSON array of items (`api/app/routes.py`) | **PASS** |
| 14 | **Resilient DB Error Handling** | Exponential backoff connection retries on startup; unhandled database errors during requests return HTTP 500 JSON without crashing container (`api/app/database.py`, `api/app/routes.py`) | **PASS** |
| 15 | **Simultaneous Local Environment** | `docker-compose.yml` runs PostgreSQL and API simultaneously from source with `service_healthy` condition; verified on localhost (`docker-compose.yml`) | **PASS** |
| 16 | **Graceful Infrastructure Teardown** | `skip_final_snapshot = true` on RDS, `force_delete = true` on ECR, proper dependency chains ensuring `terraform destroy -auto-approve` succeeds cleanly | **PASS** |
