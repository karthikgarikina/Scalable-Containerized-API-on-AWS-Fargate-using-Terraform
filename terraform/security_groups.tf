# ==============================================================================
# Security Groups (Chained Least Privilege)
# ==============================================================================

# 1. Application Load Balancer Security Group
# Public-facing: allows inbound HTTP on Port 80 from the internet
resource "aws_security_group" "alb" {
  name        = "${var.app_name}-alb-sg"
  description = "Allows incoming HTTP traffic from the public internet to the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow inbound HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-alb-sg"
  }
}

# 2. ECS Task Security Group
# Private compute tier: allows ingress on API port ONLY from ALB Security Group
resource "aws_security_group" "ecs_task" {
  name        = "${var.app_name}-ecs-task-sg"
  description = "Restricts inbound traffic strictly to the ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow inbound traffic from ALB only on container port"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-ecs-task-sg"
  }
}

# 3. RDS PostgreSQL Security Group
# Private data tier: allows ingress on Port 5432 ONLY from ECS Task Security Group
resource "aws_security_group" "rds" {
  name        = "${var.app_name}-rds-sg"
  description = "Restricts PostgreSQL database access strictly to ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow inbound PostgreSQL traffic from ECS tasks only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_task.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-rds-sg"
  }
}

# 4. VPC Interface Endpoints Security Group
# Allows HTTPS ingress from ECS Task security group to AWS service endpoints (ECR, CloudWatch)
resource "aws_security_group" "vpc_endpoints" {
  count       = var.enable_vpc_endpoints ? 1 : 0
  name        = "${var.app_name}-vpc-endpoints-sg"
  description = "Allows TLS access to VPC endpoints from ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow inbound HTTPS from ECS tasks"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_task.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-vpc-endpoints-sg"
  }
}
