# ==============================================================================
# Terraform Outputs
# ==============================================================================

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "The public URL to access the API endpoints"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository to push container images to"
  value       = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  description = "The connection endpoint for the private RDS PostgreSQL instance"
  value       = aws_db_instance.postgres.endpoint
}

output "ecs_cluster_name" {
  description = "Name of the ECS Cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS Service"
  value       = aws_ecs_service.app.name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of IDs for the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs for the private subnets"
  value       = aws_subnet.private[*].id
}
