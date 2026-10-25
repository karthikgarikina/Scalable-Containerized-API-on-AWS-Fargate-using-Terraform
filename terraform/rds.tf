# ==============================================================================
# Relational Database Service (RDS PostgreSQL)
# ==============================================================================

# DB Subnet Group across private subnets
resource "aws_db_subnet_group" "main" {
  name        = "${var.app_name}-db-subnet-group"
  description = "Subnet group for RDS PostgreSQL instance in private subnets"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

# PostgreSQL Database Instance
resource "aws_db_instance" "postgres" {
  identifier        = "${var.app_name}-db"
  engine            = "postgres"
  engine_version    = "15.7"
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Strictly non-public: isolated inside private subnets
  publicly_accessible = false

  # Ensure clean and predictable teardown
  skip_final_snapshot        = true
  deletion_protection        = false
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.app_name}-postgres"
  }
}
