# ==============================================================================
# Elastic Container Registry (ECR)
# ==============================================================================

resource "aws_ecr_repository" "app" {
  name                 = "${var.app_name}-repo"
  image_tag_mutability = "MUTABLE"

  # Allows terraform destroy to cleanly remove the repository even with pushed images
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.app_name}-repo"
  }
}
