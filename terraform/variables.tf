variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Target deployment environment"
  type        = string
  default     = "production"
}

variable "app_name" {
  description = "Base name applied to resources"
  type        = string
  default     = "fargate-api"
}

# --- Networking Variables ---
variable "vpc_cidr" {
  description = "CIDR block for the Virtual Private Cloud"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (minimum 2 across different AZs)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (minimum 2 across different AZs)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "Availability Zones to deploy subnets into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# --- Database Variables ---
variable "db_name" {
  description = "Database name for PostgreSQL"
  type        = string
  default     = "app_db"
}

variable "db_username" {
  description = "Master username for PostgreSQL RDS"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master password for PostgreSQL RDS"
  type        = string
  sensitive   = true
  default     = "ChangeMeInProdSecure123!"
}

variable "db_allocated_storage" {
  description = "Allocated storage capacity in GB for RDS"
  type        = number
  default     = 20
}

variable "db_instance_class" {
  description = "Instance type for RDS database"
  type        = string
  default     = "db.t3.micro"
}

# --- Compute & Container Variables ---
variable "container_port" {
  description = "Port exposed by the container application"
  type        = number
  default     = 8000
}

variable "container_cpu" {
  description = "Fargate CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Fargate memory allocation in MiB (512 = 0.5 GB)"
  type        = number
  default     = 512
}

variable "desired_task_count" {
  description = "Baseline desired count of running Fargate tasks"
  type        = number
  default     = 2
}

variable "min_task_count" {
  description = "Minimum count of tasks for auto-scaling"
  type        = number
  default     = 2
}

variable "max_task_count" {
  description = "Maximum count of tasks for auto-scaling"
  type        = number
  default     = 4
}

variable "container_image" {
  description = "Override container image URL. If left empty, uses the ECR repository URL created in this stack with the 'latest' tag."
  type        = string
  default     = ""
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for ECR and CloudWatch to allow private Fargate tasks to pull images and stream logs without a NAT gateway"
  type        = bool
  default     = true
}
